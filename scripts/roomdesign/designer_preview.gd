class_name DesignerPreview
extends SubViewportContainer
## The room designer's view, in 3D: with a model picked, click a floor to put it there (or
## drag one in from the palette); click an item and drag it across its floor (left and
## right, back and front). Floor furniture takes whole squares of the grid drawn on the
## floors and never overlaps (FurnitureSpots); pictures slide along the back wall; small things
## snap finer. Drag empty space to orbit, the wheel zooms.

signal edit_started
signal edited
signal picked(item: RoomDesign.Item)
signal placed(item: RoomDesign.Item)

const Sfx := preload("res://scripts/sfx.gd")

const FLOOR_THICK := 0.15
const WALL_THICK := 0.12
const ORBIT_SPEED := 0.01
const ZOOM_STEP := 0.08
const MIN_DIST := 6.0
const MAX_DIST := 60.0
const MIN_PITCH := -0.1
const MAX_PITCH := 1.3
const FOV := 35.0
## How much room to leave around the room when the view frames it.
const FIT_MARGIN := 1.35
const BACKGROUND := Color("ddd6c6")
const SIDE_WALL := Color("555048")
const HIGHLIGHT := Color("d9534f")

var settings: RoomDesignerSettings
var catalog: FurnitureCatalog
var kind: RoomKind
var level := 1
var design: RoomDesign
var selected: RoomDesign.Item
var armed: StringName = &""

var _viewport := SubViewport.new()
var _camera := Camera3D.new()
var _room := Node3D.new()
var _nodes := {}   # item -> its Node3D
var _outline := MeshInstance3D.new()
var _yaw := 0.5
var _pitch := 0.5
var _dist := 22.0
var _orbiting := false
var _moving: RoomDesign.Item
var _move_y := 0.0
var _grab := Vector2.ZERO
var _moved := false


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BACKGROUND
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.82, 0.78)
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.45, 0.0)
	sun.light_energy = 0.8
	_viewport.add_child(sun)
	_camera.fov = FOV
	_viewport.add_child(_camera)
	_viewport.add_child(_room)
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HIGHLIGHT
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.25
	box.material = mat
	_outline.mesh = box
	_outline.visible = false
	_viewport.add_child(_outline)
	resized.connect(_frame)


## Build the room and its furniture again from the design.
func rebuild() -> void:
	for child in _room.get_children():
		child.queue_free()
	_nodes.clear()
	if kind == null:
		return
	var bay := settings.bay_width
	var fh := settings.floor_height
	var w := _width()
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = settings.color_of(kind.id, level)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = floor_mat.albedo_color.lerp(Color.WHITE, 0.35)
	var side_mat := StandardMaterial3D.new()
	side_mat.albedo_color = SIDE_WALL
	for c in kind.cells:
		var mid := c.x * bay + bay / 2.0 - w / 2.0
		_block(Vector3(bay, FLOOR_THICK, settings.depth), Vector3(mid, c.y * fh - FLOOR_THICK / 2.0, 0), floor_mat)
		_block(Vector3(bay, fh, WALL_THICK), Vector3(mid, c.y * fh + fh / 2.0, -settings.depth / 2.0), wall_mat)
		_grid(c, w)
		if not kind.cells.has(c + Vector2i.LEFT):
			_block(Vector3(WALL_THICK, fh, settings.depth), Vector3(c.x * bay - w / 2.0, c.y * fh + fh / 2.0, 0), side_mat)
		if not kind.cells.has(c + Vector2i.RIGHT):
			_block(Vector3(WALL_THICK, fh, settings.depth), Vector3((c.x + 1) * bay - w / 2.0, c.y * fh + fh / 2.0, 0), side_mat)
	for o in design.items:
		var packed := catalog.scene(o.model)
		if packed == null:
			continue
		var holder := Node3D.new()
		var model := packed.instantiate() as Node3D
		model.position = catalog.info(o.model).offset
		holder.add_child(model)
		_room.add_child(holder)
		_nodes[o] = holder
		_place(o)
	_frame()
	_update_camera()
	refresh_selection()


## Move item `o`'s model to where the design says.
func _place(o: RoomDesign.Item) -> void:
	var holder: Node3D = _nodes.get(o)
	if holder == null:
		return
	holder.position = Vector3(o.x - _width() / 2.0, o.row * settings.floor_height + o.y, o.z)
	holder.rotation.y = -o.rot * PI / 2.0
	holder.scale = Vector3.ONE * o.scale * catalog.scale_of(o.model)


func refresh_selection() -> void:
	if selected == null or not _nodes.has(selected):
		_outline.visible = false
		return
	_place(selected)
	var box := _item_box(selected)
	if FurnitureSpots.type_of(selected, catalog) == FurnitureCatalog.Place.Type.FLOOR:
		# Show the squares it takes, which may be a little more than its box.
		var r := FurnitureSpots.area(selected, catalog)
		box.position.x = r.position.x - _width() / 2.0
		box.position.z = r.position.y
		box.size.x = r.size.x
		box.size.z = r.size.y
	_outline.visible = true
	_outline.position = box.get_center()
	_outline.scale = box.size + Vector3.ONE * 0.04


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var step := -ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_STEP
			_dist = clampf(_dist * (1.0 + step), MIN_DIST, MAX_DIST)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_press(mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if _moving and _moved:
				edited.emit()
			_moving = null
			_orbiting = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			armed = &""
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _moving:
			_drag_to(mm.position)
		elif _orbiting:
			_yaw -= mm.relative.x * ORBIT_SPEED
			_pitch = clampf(_pitch + mm.relative.y * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
			_update_camera()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("model")


func _drop_data(at: Vector2, data: Variant) -> void:
	_put(StringName(str((data as Dictionary)["model"])), at)


func _press(at: Vector2) -> void:
	if armed != &"" and _put(armed, at):
		return
	var ray := _ray(at)
	var hit := _item_hit(ray[0], ray[1])
	if hit:
		picked.emit(hit)
		_moving = hit
		_moved = false
		_move_y = hit.row * settings.floor_height + hit.y
		var p: Variant = _on_plane(ray[0], ray[1], _move_y)
		_grab = (p as Vector2) - Vector2(hit.x, hit.z) if p != null else Vector2.ZERO
		return
	if _floor_hit(ray[0], ray[1]).x >= 0.0:
		picked.emit(null)
	_orbiting = true


## Put a new `model` on the floor under screen point `at`; null when there is none or
## a floor piece has no room there.
func _put(model: StringName, at: Vector2) -> RoomDesign.Item:
	var ray := _ray(at)
	var spot := _floor_hit(ray[0], ray[1])
	if spot.x < 0.0:
		return null
	var reach := settings.depth / 2.0 - settings.wall_margin
	var o := catalog.new_item(model, int(spot.z), spot.x, spot.y, design.items)
	match FurnitureSpots.type_of(o, catalog):
		FurnitureCatalog.Place.Type.FLOOR:
			if not FurnitureSpots.settle(o, catalog, kind, design.items):
				Sfx.ui(get_tree(), &"error")
				return null
		FurnitureCatalog.Place.Type.WALL:
			FurnitureSpots.hang(o, spot.x, catalog, kind)
		_:
			var bay := settings.bay_width
			var col := floori(spot.x / bay)
			o.x = clampf(_snap(spot.x), col * bay + 0.1, (col + 1) * bay - 0.1)
			o.z = clampf(_snap(spot.y), -reach, reach)
			o.y = catalog.rest_height(o, design.items)
	edit_started.emit()
	design.items.append(o)
	placed.emit(o)
	edited.emit()
	return o


func _drag_to(at: Vector2) -> void:
	var ray := _ray(at)
	var p: Variant = _on_plane(ray[0], ray[1], _move_y)
	if p == null:
		return
	if not _moved:
		edit_started.emit()
		_moved = true
	var o := _moving
	var to := (p as Vector2) - _grab
	match FurnitureSpots.type_of(o, catalog):
		FurnitureCatalog.Place.Type.FLOOR:
			FurnitureSpots.move_to(o, to.x, to.y, catalog, kind, design.items)
		FurnitureCatalog.Place.Type.WALL:
			FurnitureSpots.hang(o, to.x, catalog, kind)
		_:
			var span := FurnitureSpots.row_span(o.row, catalog, kind)
			var reach := settings.depth / 2.0 - settings.wall_margin
			o.x = clampf(_snap(to.x), span.x + 0.1, span.y - 0.1)
			o.z = clampf(_snap(to.y), -reach, reach)
			if not o.manual:
				o.y = catalog.rest_height(o, design.items)
				_move_y = o.row * settings.floor_height + o.y
	picked.emit(o)


## `v` metres on the small things' grid.
func _snap(v: float) -> float:
	return v if settings.snap <= 0.0 else snappedf(v, settings.snap)


## Grid lines on the floor of place `c` (the room `w` wide, centred on x = 0).
func _grid(c: Vector2i, w: float) -> void:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = settings.grid_color
	var y := c.y * settings.floor_height + 0.01
	var left := c.x * settings.bay_width - w / 2.0
	var half := settings.depth / 2.0
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var x := 0.0
	while x <= settings.bay_width + 0.001:
		mesh.surface_add_vertex(Vector3(left + x, y, -half))
		mesh.surface_add_vertex(Vector3(left + x, y, half))
		x += settings.grid_step
	var z := -half
	while z <= half + 0.001:
		mesh.surface_add_vertex(Vector3(left, y, z))
		mesh.surface_add_vertex(Vector3(left + settings.bay_width, y, z))
		z += settings.grid_step
	mesh.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = mesh
	_room.add_child(lines)


## The camera ray through screen point `at`, in room coordinates (x from the left edge).
func _ray(at: Vector2) -> Array[Vector3]:
	var px := at * Vector2(_viewport.size) / size
	var from := _camera.project_ray_origin(px) + Vector3(_width() / 2.0, 0, 0)
	return [from, _camera.project_ray_normal(px)]


## Where the ray meets the plane at height `y`, as (x, z); null when it doesn't.
func _on_plane(from: Vector3, dir: Vector3, y: float) -> Variant:
	if absf(dir.y) < 0.0001:
		return null
	var t := (y - from.y) / dir.y
	if t < 0.0:
		return null
	var p := from + dir * t
	return Vector2(p.x, p.z)


## The lit floor the ray meets first: (x, z, row), or x < 0 for none.
func _floor_hit(from: Vector3, dir: Vector3) -> Vector3:
	var best := Vector3(-1, 0, 0)
	var best_t := INF
	var half := settings.depth / 2.0
	for c in kind.cells:
		var y := c.y * settings.floor_height
		if absf(dir.y) < 0.0001:
			continue
		var t := (y - from.y) / dir.y
		var p := from + dir * t
		if t > 0.0 and t < best_t and p.x >= c.x * settings.bay_width \
				and p.x < (c.x + 1) * settings.bay_width and absf(p.z) <= half:
			best_t = t
			best = Vector3(p.x, p.z, c.y)
	return best


func _item_hit(from: Vector3, dir: Vector3) -> RoomDesign.Item:
	var best: RoomDesign.Item = null
	var best_d := INF
	for o in design.items:
		var box := _item_box(o)
		box.position.x += _width() / 2.0
		var p: Variant = box.intersects_ray(from, dir)
		if p != null and from.distance_to(p) < best_d:
			best_d = from.distance_to(p)
			best = o
	return best


## The item's box in the viewport's coordinates (room centred on x = 0).
func _item_box(o: RoomDesign.Item) -> AABB:
	var s := catalog.size_of(o)
	var base := Vector3(o.x - _width() / 2.0, o.row * settings.floor_height + o.y, o.z)
	return AABB(base - Vector3(s.x / 2.0, 0, s.z / 2.0), s)


## Far enough to see the whole room, across and up, at this view's shape.
func _frame() -> void:
	if kind == null:
		return
	var aspect := size.x / size.y if size.x > 0.0 and size.y > 0.0 else 1.0
	var fit := maxf(_width() / aspect, _rows() * settings.floor_height) \
			/ (2.0 * tan(deg_to_rad(FOV) / 2.0))
	_dist = clampf(fit * FIT_MARGIN, MIN_DIST, MAX_DIST)
	_update_camera()


func _update_camera() -> void:
	var eye_y := _rows() * settings.floor_height / 2.0
	_camera.position = Vector3(sin(_yaw) * cos(_pitch) * _dist, eye_y + sin(_pitch) * _dist,
			cos(_yaw) * cos(_pitch) * _dist)
	_camera.look_at(Vector3(0, eye_y, 0))


func _block(s: Vector3, at: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = s
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	_room.add_child(mesh)


func _width() -> float:
	var n := 0
	for c in kind.cells:
		n = maxi(n, c.x + 1)
	return n * settings.bay_width


func _rows() -> int:
	var n := 0
	for c in kind.cells:
		n = maxi(n, c.y + 1)
	return n
