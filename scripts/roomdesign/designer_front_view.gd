class_name DesignerFrontView
extends Control
## The room designer's front view: the room cut open, its places lit in the room's colour
## and the rest of its box greyed, the furniture drawn from the side. Click a lit place
## with a model picked (or drag one in from the palette) to put it there; click an item
## to pick it, drag to move it.

## An edit is about to begin (for undo).
signal edit_started
## The design changed.
signal edited
## The player picked `item` (null: nothing).
signal picked(item: RoomDesign.Item)
## The player put down a new item.
signal placed(item: RoomDesign.Item)

const MARGIN := 30.0
const MAX_SCALE := 90.0
const FLOOR_LINE := 5.0
const HATCH := 14.0
const LABEL_SIZE := 11

var settings: RoomDesignerSettings
var catalog: FurnitureCatalog
var kind: RoomKind
var level := 1
var design: RoomDesign
var selected: RoomDesign.Item
## The model to put down on the next click ("" for none).
var armed: StringName = &""

var _scale := 60.0
var _origin := Vector2.ZERO
var _hover := Vector2(-1, -1)
var _moving: RoomDesign.Item
var _grab_dx := 0.0
var _moved := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func columns() -> int:
	var n := 0
	for c in kind.cells:
		n = maxi(n, c.x + 1)
	return n


func rows() -> int:
	var n := 0
	for c in kind.cells:
		n = maxi(n, c.y + 1)
	return n


func in_shape(col: int, row: int) -> bool:
	return kind.cells.has(Vector2i(col, row))


## Put a new `model` where the screen point `at` is, if that is a lit place.
func place_at(model: StringName, at: Vector2) -> RoomDesign.Item:
	var world := _to_world(at)
	var cell := _cell_at(world)
	if cell.x < 0 or model == &"":
		return null
	edit_started.emit()
	var bay := settings.bay_width
	var x := clampf(world.x, cell.x * bay + 0.1, (cell.x + 1) * bay - 0.1)
	var o := catalog.new_item(model, cell.y, x, 0.0, design.items)
	design.items.append(o)
	placed.emit(o)
	edited.emit()
	return o


func _draw() -> void:
	if kind == null:
		return
	_layout()
	var bay := settings.bay_width * _scale
	var floor_h := settings.floor_height * _scale
	var fill := settings.color_of(kind.id, level)
	for r in rows():
		for c in columns():
			var rect := Rect2(_origin.x + c * bay, _floor_y(r + 1), bay, floor_h)
			if in_shape(c, r):
				draw_rect(rect, fill)
				draw_rect(Rect2(rect.position, Vector2(bay, floor_h * 0.78)), Color(1, 1, 1, 0.35))
			else:
				draw_rect(rect, Color(0.47, 0.47, 0.47, 0.12))
				_hatch(rect)
	var wall := Color("5a554b")
	for c in kind.cells:
		var x := _origin.x + c.x * bay
		var y := _floor_y(c.y + 1)
		if not in_shape(c.x - 1, c.y):
			draw_line(Vector2(x, y), Vector2(x, y + floor_h), wall, 2.0)
		if not in_shape(c.x + 1, c.y):
			draw_line(Vector2(x + bay, y), Vector2(x + bay, y + floor_h), wall, 2.0)
		else:
			draw_dashed_line(Vector2(x + bay, y), Vector2(x + bay, y + floor_h),
					Color(0, 0, 0, 0.15), 1.0, 4.0)
		if not in_shape(c.x, c.y + 1):
			draw_line(Vector2(x, y), Vector2(x + bay, y), wall, 2.0)
		draw_line(Vector2(x, y + floor_h), Vector2(x + bay, y + floor_h), wall, FLOOR_LINE)
	var order := design.items.duplicate()
	order.sort_custom(func(a: RoomDesign.Item, b: RoomDesign.Item) -> bool:
		return a.z < b.z or (a.z == b.z and a.y < b.y))
	var font := get_theme_default_font()
	for o: RoomDesign.Item in order:
		var box := _box(o)
		var tex := catalog.icon(o.model)
		if tex:
			# The icon is the side seen from the front; turned round it is mirrored.
			draw_texture_rect(tex, box if o.rot < 2 else Rect2(box.position + Vector2(box.size.x, 0),
					Vector2(-box.size.x, box.size.y)), false)
		else:
			draw_rect(box, Color(0.6, 0.6, 0.6))
		var slot := RoomDesign.depth_slot(o.z, settings.depth_band)
		if slot != 1:
			draw_string(font, box.position + Vector2(2, box.size.y + 11), "back" if slot == 0 else "front",
					HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(0, 0, 0, 0.5))
		if o == selected:
			draw_rect(box.grow(2.0), Color("d9534f"), false, 2.0)
	if armed != &"" and _hover.x >= 0.0:
		var tex := catalog.icon(armed)
		var s := catalog.info(armed).size * _scale
		if tex:
			draw_texture_rect(tex, Rect2(_hover - Vector2(s.x / 2.0, s.y), Vector2(s.x, s.y)), false,
					Color(1, 1, 1, 0.55))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = (event as InputEventMouseMotion).position
		if _moving:
			_drag_to(_hover)
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_press(mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _moving and _moved:
				edited.emit()
			_moving = null
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			armed = &""
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2(-1, -1)
		queue_redraw()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("model")


func _drop_data(at: Vector2, data: Variant) -> void:
	place_at(StringName(str((data as Dictionary)["model"])), at)


func _press(at: Vector2) -> void:
	if armed != &"":
		place_at(armed, at)
		return
	var hit: RoomDesign.Item = null
	var order := design.items.duplicate()
	order.reverse()
	for o: RoomDesign.Item in order:
		if _box(o).has_point(at):
			hit = o
			break
	picked.emit(hit)
	if hit:
		_moving = hit
		_moved = false
		_grab_dx = _to_world(at).x - hit.x


func _drag_to(at: Vector2) -> void:
	if not _moved:
		edit_started.emit()
		_moved = true
	var o := _moving
	var world := _to_world(at)
	var bay := settings.bay_width
	var cell := _cell_at(world)
	if cell.x >= 0:
		o.row = cell.y
		o.x = clampf(world.x - _grab_dx, cell.x * bay + 0.05, (cell.x + 1) * bay - 0.05)
	else:
		o.x = clampf(world.x - _grab_dx, 0.1, columns() * bay - 0.1)
	if not o.manual:
		o.y = catalog.rest_height(o, design.items)
	picked.emit(o)


func _layout() -> void:
	var w := settings.bay_width * columns()
	var h := settings.floor_height * rows()
	_scale = minf(minf((size.x - MARGIN * 2.0) / w, (size.y - MARGIN * 2.0) / h), MAX_SCALE)
	_origin = Vector2((size.x - w * _scale) / 2.0, (size.y - h * _scale) / 2.0)


## The screen y of the floor of row `r` (row `rows()` is the top of the box).
func _floor_y(r: int) -> float:
	return _origin.y + (rows() - r) * settings.floor_height * _scale


## Metres across from the room's left edge, and up from its lowest floor.
func _to_world(at: Vector2) -> Vector2:
	return Vector2((at.x - _origin.x) / _scale, (_floor_y(0) - at.y) / _scale)


func _cell_at(world: Vector2) -> Vector2i:
	var c := floori(world.x / settings.bay_width)
	var r := floori(world.y / settings.floor_height)
	return Vector2i(c, r) if in_shape(c, r) else Vector2i(-1, -1)


func _box(o: RoomDesign.Item) -> Rect2:
	var s := catalog.size_of(o) * _scale
	var bottom := _floor_y(o.row) - o.y * _scale
	return Rect2(_origin.x + o.x * _scale - s.x / 2.0, bottom - s.y, s.x, s.y)


func _hatch(rect: Rect2) -> void:
	var k := -rect.size.y
	while k < rect.size.x:
		var a := rect.position + Vector2(maxf(k, 0.0), maxf(-k, 0.0))
		var b := rect.position + Vector2(minf(k + rect.size.y, rect.size.x),
				minf(rect.size.y, rect.size.x - k))
		draw_line(a, b, Color(0.47, 0.47, 0.47, 0.35), 1.0)
		k += HATCH
