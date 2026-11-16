class_name FurnitureCatalog
extends RefCounted
## The furniture the room designer offers: each model's scene, side-view icon and size
## (read once from its meshes), which group it is in, what can stand on it and what
## hangs on a wall.

## A model's size in metres, unturned: x across, y up, z deep; and the offset that puts
## the middle of its footprint, at its lowest point, on its holder's origin (an item's
## x and z are its middle, as the file says).
class Info:
	var size := Vector3.ONE
	var offset := Vector3.ZERO

var settings: RoomDesignerSettings

var _scenes := {}     # model -> PackedScene
var _icons := {}      # model -> Texture2D
var _info := {}       # model -> Info
var _groups := {}     # group name -> RegEx
var _surface := RegEx.new()
var _surface_not := RegEx.new()
var _walls: Array[RegEx] = []
var _wall_heights: Array[float] = []


func _init(s: RoomDesignerSettings) -> void:
	settings = s
	for g: String in s.groups:
		var re := RegEx.new()
		re.compile(s.groups[g])
		_groups[g] = re
	_surface.compile(s.surface)
	_surface_not.compile(s.surface_not)
	for pattern: String in s.wall_heights:
		var re := RegEx.new()
		re.compile(pattern)
		_walls.append(re)
		_wall_heights.append(float(s.wall_heights[pattern]))


func group_names() -> Array[String]:
	var out: Array[String] = []
	for g: String in _groups:
		out.append(g)
	return out


## The models in `group` whose name holds `search`.
func models_in(group: String, search: String) -> Array[StringName]:
	var re: RegEx = _groups.get(group, _groups.get("all"))
	var out: Array[StringName] = []
	for m in settings.models + settings.artist_models:
		if re.search(m) and (search == "" or String(m).to_lower().contains(search.to_lower())):
			out.append(m)
	return out


func scene(model: StringName) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(_folder_of(model) + String(model) + ".glb")
	return _scenes[model]


func icon(model: StringName) -> Texture2D:
	if not _icons.has(model):
		_icons[model] = load(_folder_of(model) + "icons/" + String(model) + ".png")
	return _icons[model]


func info(model: StringName) -> Info:
	if not _info.has(model):
		var i := Info.new()
		var packed := scene(model)
		if packed:
			var node := packed.instantiate()
			var box := _bounds(node, Transform3D.IDENTITY)
			node.free()
			if box.size != Vector3.ZERO:
				i.size = box.size
				var mid := box.get_center()
				i.offset = Vector3(-mid.x, -box.position.y, -mid.z)
		_info[model] = i
	return _info[model]


## A turned, scaled item's size as drawn (RoomDesignerSettings.furniture_scale): across,
## up, deep.
func size_of(o: RoomDesign.Item) -> Vector3:
	var s := info(o.model).size * o.scale * settings.furniture_scale
	return Vector3(s.z, s.y, s.x) if o.rot % 2 == 1 else s


func is_surface(model: StringName) -> bool:
	return _surface.search(model) != null and _surface_not.search(model) == null \
			and info(model).size.y < settings.surface_max_height


## Metres above the floor that `model` hangs on the back wall, or -1 when it stands.
func wall_height(model: StringName) -> float:
	for i in _walls.size():
		if _walls[i].search(model):
			return _wall_heights[i]
	return -1.0


## A new item of `model` at `x` across and `z` deep on `row`: hung on the back wall if it
## hangs, else resting on the floor or on a surface among `others`.
func new_item(model: StringName, row: int, x: float, z: float,
		others: Array[RoomDesign.Item]) -> RoomDesign.Item:
	var o := RoomDesign.Item.new()
	o.model = model
	o.row = row
	o.x = x
	o.z = z
	var hang := wall_height(model)
	if hang >= 0.0:
		o.y = hang
		o.manual = true
		o.z = -(settings.depth / 2.0 - settings.wall_margin)
	else:
		o.y = rest_height(o, others)
	return o


## Where `o` comes to rest: on the floor, or on top of the highest surface under it at
## about the same depth.
func rest_height(o: RoomDesign.Item, others: Array[RoomDesign.Item]) -> float:
	var y := 0.0
	for b in others:
		if b == o or b.row != o.row or not is_surface(b.model):
			continue
		var bs := size_of(b)
		var top := b.y + bs.y
		if absf(b.z - o.z) < settings.depth_band and absf(b.x - o.x) < bs.x / 2.0 \
				and top > y and top < settings.floor_height - settings.ceiling_gap:
			y = top
	return y


func _bounds(node: Node, xf: Transform3D) -> AABB:
	var here := xf
	if node is Node3D:
		here = xf * (node as Node3D).transform
	var box := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = here * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for child in node.get_children():
		var b := _bounds(child, here)
		if b.size == Vector3.ZERO:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


## The Kenney kit's folder, or the Artist's for a piece of theirs.
func _folder_of(model: StringName) -> String:
	return settings.artist_folder if settings.artist_models.has(model) else settings.model_folder
