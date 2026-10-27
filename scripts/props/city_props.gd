class_name CityProps
extends Node3D
## Dresses the city once it is built, with the Meshy models in
## assets/models/meshy/: air conditioners under windows, water tanks and
## cooling units on roofs (both drawn as MultiMeshes, a chunk of town each),
## and trash cans, bags, hydrants and benches on the sidewalks that the hand
## can pick up. Roof props follow a building that grows new floors and make
## way for a penthouse, and go with a building that is torn down.

const SETTINGS_PATH := "res://data/city_props.tres"
const D: DecreeSettings = preload("res://data/decrees.tres")
const DecreeLooks := preload("res://scripts/decree_looks.gd")
const DivineSign := preload("res://scripts/divine_sign.gd")
const BuildingVisual := preload("res://scripts/building_visual.gd")
const LAYER_WORLD := 1
const LAYER_PROPS := 4
const BLOCKER_CELL := 4.0      # metres per cell of the door-and-tree lookup
const DOOR_CLEARANCE := 1.6    # keep the doorway free
const TREE_CLEARANCE := 0.9    # trunk radius plus a little air
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

## The city to dress. Props are placed when it is ready.
@export var city: Node3D
## Decrees reshape buildings; roof props follow.
@export var decrees: Decrees

var _s: CityPropsSettings
var _rng := RandomNumberGenerator.new()
var _placements: Array[Placement] = []
var _roofs := {}        # building (Node3D) -> Array[Placement] on its roof
var _on_building := {}  # building (Node3D) -> Array[Placement] on its facades and roof
var _blockers := {}     # Vector2i cell -> PackedVector4Array (x, y, z, clearance)


## One facade or roof prop: where it goes and, once drawn, where it lives.
class Placement:
	var building: Node3D
	var kind: PropKind
	var transform: Transform3D
	var on_facade: bool
	var local := Transform3D()   # roof props: relative to the roof's centre
	var multimesh: MultiMesh
	var index := -1


func _ready() -> void:
	_s = load(SETTINGS_PATH)
	_rng.seed = 11
	if decrees:
		decrees.decree_issued.connect(_on_decree_issued)
	await city.ready
	_dress()


func _dress() -> void:
	_collect_blockers()
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Node3D
		var size := DivineSign.building_size(building)
		_dress_facades(building, size)
		_dress_roof(building, size)
		_line_sidewalk(building, size)
		building.tree_exiting.connect(_on_building_gone.bind(building))
	_draw_placements()


# --- Facades ---

func _dress_facades(building: Node3D, size: Vector3) -> void:
	if size.y > _s.facade_max_height or _s.facade_kinds.is_empty():
		return
	# The same window grid as building_visual.gd, so units sit under real windows.
	var cols := maxi(1, roundi(size.x / BuildingVisual.BAY))
	var floors := maxi(1, roundi(size.y / DecreeLooks.FLOOR_HEIGHT))
	var bay := size.x / cols
	var storey := size.y / floors
	var base := building.global_position - Vector3.UP * size.y / 2.0
	for side: float in [-1.0, 1.0]:
		var facing := Basis(Vector3.UP, 0.0 if side > 0.0 else PI)
		for f in range(1, floors):   # the ground floor is shopfronts
			for c in cols:
				if _rng.randf() >= _s.facade_chance:
					continue
				var kind := _pick(_s.facade_kinds)
				var x := -size.x / 2.0 + (c + 0.5) * bay
				var at := base + Vector3(x, f * storey + _s.sill_height, side * size.z / 2.0)
				var p := Placement.new()
				p.building = building
				p.kind = kind
				p.on_facade = true
				p.transform = Transform3D(facing, at) * PropModel.of(kind).against_wall()
				_placements.append(p)


# --- Roofs ---

func _dress_roof(building: Node3D, size: Vector3) -> void:
	if _s.roof_kinds.is_empty() or _rng.randf() >= _s.roof_chance:
		return
	var free := Vector2(size.x, size.z) - Vector2.ONE * _s.roof_margin * 2.0
	var kind := _pick(_s.roof_kinds)
	var model := PropModel.of(kind)
	var turn := _rng.randi_range(0, 3) * PI / 2.0
	var footprint := Vector2(model.size.x, model.size.z)
	if is_equal_approx(fmod(turn, PI), PI / 2.0):
		footprint = Vector2(footprint.y, footprint.x)
	if footprint.x > free.x or footprint.y > free.y:
		return
	var room := (free - footprint) / 2.0
	var spot := Vector3(_rng.randf_range(-room.x, room.x), 0.0, _rng.randf_range(-room.y, room.y))
	var p := Placement.new()
	p.building = building
	p.kind = kind
	p.local = Transform3D(Basis(Vector3.UP, turn), spot) * model.offset
	p.transform = _roof_frame(building, size) * p.local
	_placements.append(p)
	_roofs[building] = [p]


func _roof_frame(building: Node3D, size: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, building.global_position + Vector3.UP * size.y / 2.0)


func _on_decree_issued(kind: StringName, building: Node3D) -> void:
	if not _roofs.has(building) or not (kind == &"floors" or kind == &"luxury"):
		return
	if kind == &"floors":
		# Move up once the new floors have risen out of the old roof.
		await get_tree().create_timer(D.grow_time).timeout
	if not is_instance_valid(building):
		return
	var size := DivineSign.building_size(building)
	var penthouse: bool = building.get_meta(&"decree_luxury", false)
	for p: Placement in _roofs[building]:
		var t := HIDDEN if penthouse else _roof_frame(building, size) * p.local
		p.multimesh.set_instance_transform(p.index, t)


func _on_building_gone(building: Node3D) -> void:
	for p: Placement in _on_building.get(building, []):
		p.multimesh.set_instance_transform(p.index, HIDDEN)
	_on_building.erase(building)
	_roofs.erase(building)


# --- Sidewalks ---

func _line_sidewalk(building: Node3D, size: Vector3) -> void:
	if _s.street_kinds.is_empty():
		return
	var centre := building.global_position
	var ground := centre.y - size.y / 2.0
	for side: float in [-1.0, 1.0]:
		var wall := centre.z + side * size.z / 2.0
		var x := centre.x - size.x / 2.0 + _rng.randf_range(0.5, _s.street_spacing.x)
		while x < centre.x + size.x / 2.0 - 1.0:
			var kind := _pick(_s.street_kinds)
			var model := PropModel.of(kind)
			for n in _rng.randi_range(kind.cluster.x, kind.cluster.y):
				var out := wall + side * (_s.wall_gap + model.size.z / 2.0)
				var at := Vector3(x + model.size.x / 2.0, ground + model.size.y / 2.0, out)
				if _is_clear(at, model.size.x / 2.0):
					_spawn(kind, at, side)
				x += model.size.x + 0.15
			x += _rng.randf_range(_s.street_spacing.x, _s.street_spacing.y)


func _spawn(kind: PropKind, at: Vector3, side: float) -> void:
	var prop := StreetProp.new()
	prop.build(kind, _s, LAYER_PROPS, LAYER_WORLD | LAYER_PROPS)
	prop.position = at
	# Facing the street, a little crooked, the way things get left.
	prop.rotation.y = (0.0 if side > 0.0 else PI) + _rng.randf_range(-0.25, 0.25)
	add_child(prop)
	prop.sleeping = true


func _collect_blockers() -> void:
	for door: Node3D in get_tree().get_nodes_in_group("doors"):
		_add_blocker(door.global_position, DOOR_CLEARANCE)
	for node in get_tree().get_nodes_in_group("wind_reactive"):
		if node is SwayingTree:
			_add_blocker((node as Node3D).global_position, TREE_CLEARANCE)


func _add_blocker(p: Vector3, clearance: float) -> void:
	var cell := Vector2i(floori(p.x / BLOCKER_CELL), floori(p.z / BLOCKER_CELL))
	if not _blockers.has(cell):
		_blockers[cell] = PackedVector4Array()
	(_blockers[cell] as PackedVector4Array).append(Vector4(p.x, p.y, p.z, clearance))


func _is_clear(p: Vector3, half_width: float) -> bool:
	var cell := Vector2i(floori(p.x / BLOCKER_CELL), floori(p.z / BLOCKER_CELL))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for b: Vector4 in _blockers.get(cell + Vector2i(dx, dz), PackedVector4Array()):
				if Vector2(b.x - p.x, b.z - p.z).length() < b.w + half_width:
					return false
	return true


# --- Drawing ---

## One MultiMesh per kind and chunk of town, so whole chunks off screen are skipped.
func _draw_placements() -> void:
	var groups := {}   # [kind, chunk] -> Array[Placement]
	for p in _placements:
		var o := p.transform.origin
		var key := [p.kind, Vector2i(floori(o.x / _s.chunk_size), floori(o.z / _s.chunk_size))]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(p)
	for key: Array in groups:
		var members: Array = groups[key]
		var kind: PropKind = key[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = PropModel.of(kind).mesh
		mm.instance_count = members.size()
		for i in members.size():
			var p: Placement = members[i]
			mm.set_instance_transform(i, p.transform)
			p.multimesh = mm
			p.index = i
			if not _on_building.has(p.building):
				_on_building[p.building] = []
			(_on_building[p.building] as Array).append(p)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = PropModel.of(kind).material
		mmi.visibility_range_end = _s.visible_distance
		# Small units under windows: their shadows would be a few pixels, not worth a pass.
		if (members[0] as Placement).on_facade:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_placements.clear()


func _pick(kinds: Array[PropKind]) -> PropKind:
	var total := 0.0
	for k in kinds:
		total += k.weight
	var roll := _rng.randf() * total
	for k in kinds:
		roll -= k.weight
		if roll <= 0.0:
			return k
	return kinds[kinds.size() - 1]
