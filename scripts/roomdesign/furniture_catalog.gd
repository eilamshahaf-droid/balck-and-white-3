class_name FurnitureCatalog
extends RefCounted
## The furniture the room designer offers: each model's scene, side-view icon and size
## (read once from its meshes), which group it is in, and how it is placed (`Place`): on
## the floor taking grid squares, small on a floor or a surface, or on the wall. A model
## may have a sidecar file beside it, `<model>.place.json` (type, scale, footprint, front,
## surface, slots, wall_height), which wins; without one the lists in the settings decide.

## A model's size in metres, unturned: x across, y up, z deep; and the offset that puts
## the middle of its footprint, at its lowest point, on its holder's origin (an item's
## x and z are its middle, as the file says).
class Info:
	var size := Vector3.ONE
	var offset := Vector3.ZERO

## How a model is placed. `footprint` is its floor size in metres as drawn, unturned (x
## across, y deep); `scale` how many times its model size it is drawn.
class Place:
	enum Type { FLOOR, SMALL, WALL }
	var type := Type.FLOOR
	var scale := 1.0
	var footprint := Vector2.ONE
	## Quarter turns from the model's +z to the side it is used from (kept for the game).
	var front := 0
	var surface := false
	var wall_height := -1.0
	## Places on its top for small things, read from the sidecar for a later round.
	var slots: Array = []

var settings: RoomDesignerSettings

var _scenes := {}     # model -> PackedScene
var _icons := {}      # model -> Texture2D
var _info := {}       # model -> Info
var _places := {}     # model -> Place
var _groups := {}     # group name -> RegEx
var _surface := RegEx.new()
var _surface_not := RegEx.new()
var _small := RegEx.new()
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
	_small.compile(s.small)
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


## How `model` is placed: its sidecar file, or else what the settings' lists say.
func place_of(model: StringName) -> Place:
	if not _places.has(model):
		var p := Place.new()
		var path := _folder_of(model) + String(model) + ".place.json"
		var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) \
				if FileAccess.file_exists(path) else null
		_derive(p, model)
		if side is Dictionary:
			_read_sidecar(p, side as Dictionary)
		_places[model] = p
	return _places[model]


## How many times its model size `model` is drawn.
func scale_of(model: StringName) -> float:
	return place_of(model).scale


## A turned, scaled item's size as drawn: across, up, deep.
func size_of(o: RoomDesign.Item) -> Vector3:
	var s := info(o.model).size * o.scale * scale_of(o.model)
	return Vector3(s.z, s.y, s.x) if o.rot % 2 == 1 else s


func is_surface(model: StringName) -> bool:
	return place_of(model).surface


## Metres above the floor that `model` hangs on the back wall, or -1 when it stands.
func wall_height(model: StringName) -> float:
	var p := place_of(model)
	return p.wall_height if p.type == Place.Type.WALL else -1.0


## A new item of `model` at `x` across and `z` deep on `row`: hung on the back wall if it
## hangs, on the floor if it takes squares, a small thing on a surface among `others`.
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
	elif place_of(model).type == Place.Type.SMALL:
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


## What the settings' lists say about `model`, for a model with no sidecar.
func _derive(p: Place, model: StringName) -> void:
	p.scale = settings.furniture_scale
	var drawn := info(model).size * p.scale
	p.footprint = Vector2(drawn.x, drawn.z)
	p.surface = _surface.search(model) != null and _surface_not.search(model) == null \
			and info(model).size.y < settings.surface_max_height
	for i in _walls.size():
		if _walls[i].search(model):
			p.type = Place.Type.WALL
			p.wall_height = _wall_heights[i]
			return
	var small := _small.search(model) != null or maxf(drawn.x, drawn.z) <= settings.small_max
	p.type = Place.Type.SMALL if small else Place.Type.FLOOR


func _read_sidecar(p: Place, d: Dictionary) -> void:
	if d.has("scale"):
		var old := p.scale
		p.scale = float(d["scale"])
		p.footprint *= p.scale / old
	match str(d.get("type", "")):
		"floor":
			p.type = Place.Type.FLOOR
		"small", "surface":
			p.type = Place.Type.SMALL
		"wall":
			p.type = Place.Type.WALL
	if d.get("footprint") is Array and (d["footprint"] as Array).size() == 2:
		p.footprint = Vector2(float(d["footprint"][0]), float(d["footprint"][1]))
	p.front = int(d.get("front", p.front))
	p.wall_height = float(d.get("wall_height", p.wall_height))
	if p.type == Place.Type.WALL and p.wall_height < 0.0:
		p.wall_height = settings.default_wall_height
	if d.get("slots") is Array:
		p.slots = d["slots"]
	p.surface = bool(d.get("surface", p.surface or not p.slots.is_empty()))


## The Kenney kit's folder, or the Artist's for a piece of theirs.
func _folder_of(model: StringName) -> String:
	return settings.artist_folder if settings.artist_models.has(model) else settings.model_folder
