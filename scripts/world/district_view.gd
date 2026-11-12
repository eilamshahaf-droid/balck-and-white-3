class_name DistrictView
extends Node3D
## Shows who holds what: a gold plate on the roof of every building of yours (all the
## buildings of a unit, which change hands together), and a ring on the ground round
## each unit, so the player sees what they take; it turns gold once the unit is yours.
## All MultiMeshes, so hundreds of roofs cost one draw call. The takeover marks (skull,
## dollar, sky sign) are campaign_marks.gd.

const S: DistrictSettings = preload("res://data/districts.tres")
const ROOF_LIFT := 1.4      # above the roof modules (Kenney roofs stand about a metre proud of the box)
const ROOF_INSET := 0.8     # plate size as a share of the roof
const BORDER_LIFT := 0.08   # just above the asphalt

var _roofs := MultiMesh.new()
var _borders := MultiMesh.new()
var _cores := MultiMesh.new()
var _hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
var _first_roof := PackedInt32Array()     # per building: its first roof plate
var _first_strip := PackedInt32Array()    # per building: its first ring strip (one more at the end)

@onready var districts: Districts = get_node("../Districts")


func _ready() -> void:
	districts.layout_ready.connect(_build)
	districts.building_changed.connect(_on_building_changed)
	districts.district_controlled.connect(_on_district_controlled)
	districts.core_changed.connect(_place_core)
	get_node("../Decrees").decree_issued.connect(_on_decree_issued)


func _build() -> void:
	var plate := BoxMesh.new()
	plate.size = Vector3(1.0, 0.25, 1.0)
	plate.material = _unshaded(S.roof_color, false)
	_roofs.transform_format = MultiMesh.TRANSFORM_3D
	_roofs.mesh = plate
	var roofs := 0
	for b in districts.buildings:
		_first_roof.append(roofs)
		roofs += BuildingBox.pieces_of(b).size()
	_roofs.instance_count = roofs
	for i in _roofs.instance_count:
		_roofs.set_instance_transform(i, _hidden)
	_add_instance(_roofs)

	var strip := BoxMesh.new()
	strip.size = Vector3(1.0, 0.05, 1.0)
	strip.material = _unshaded(Color.WHITE, true)
	_borders.transform_format = MultiMesh.TRANSFORM_3D
	_borders.use_colors = true
	_borders.mesh = strip
	var rings: Array[PackedVector2Array] = []
	_first_strip = PackedInt32Array([0])
	for b in districts.buildings:
		rings.append(_ring(b))
		_first_strip.append(_first_strip[-1] + rings[-1].size())
	_borders.instance_count = _first_strip[-1]
	for i in rings.size():
		_outline(i, rings[i])
	_add_instance(_borders)

	var beacon := BoxMesh.new()
	beacon.size = Vector3.ONE
	beacon.material = _unshaded(Color.WHITE, true)
	_cores.transform_format = MultiMesh.TRANSFORM_3D
	_cores.use_colors = true
	_cores.mesh = beacon
	_cores.instance_count = districts.district_count()
	for d in districts.district_count():
		_place_core(d)
	_add_instance(_cores)


## A purple beacon over each district's core building, gold once it is yours.
func _place_core(d: int) -> void:
	var core := districts.core_of(d)
	var b: Node3D = districts.buildings[core] if core >= 0 else null
	if b == null:
		_cores.set_instance_transform(d, _hidden)
		return
	var size := BuildingBox.size_of(b)
	var at := b.global_position + Vector3.UP * (size.y / 2.0 + ROOF_LIFT + S.core_beacon.y / 2.0)
	_cores.set_instance_transform(d, Transform3D(Basis.from_scale(S.core_beacon), at))
	_cores.set_instance_color(d, S.roof_color if districts.is_yours(core) else S.core_color)


func _on_building_changed(index: int, yours: bool) -> void:
	for d in districts.district_count():
		if districts.core_of(d) == index:
			_place_core(d)
	_colour_ring(index, S.controlled_border_color if yours else S.border_color)
	var b: Node3D = districts.buildings[index]
	var pieces: Array[Node3D] = BuildingBox.pieces_of(b) if b else []
	var count := (_first_roof[index + 1] if index + 1 < _first_roof.size() else _roofs.instance_count) \
			- _first_roof[index]
	for k in count:
		var at := _first_roof[index] + k
		if not yours or k >= pieces.size() or not is_instance_valid(pieces[k]):
			_roofs.set_instance_transform(at, _hidden)
			continue
		var piece := pieces[k]
		var size := BuildingBox.size_of(piece)  # live: decrees add floors
		var top := piece.global_position + Vector3.UP * (size.y / 2.0 + ROOF_LIFT)
		var turn := piece.global_basis.orthonormalized() * Basis.from_scale(Vector3(size.x, 1.0, size.z) * ROOF_INSET)
		_roofs.set_instance_transform(at, Transform3D(turn, top))


## +3 Floors lifts the roof, so the plate follows it.
func _on_decree_issued(_kind: StringName, building: Node3D) -> void:
	var i := districts.index_of(building)
	if i >= 0:
		_on_building_changed(i, districts.is_yours(i))


func _on_district_controlled(d: int) -> void:
	for i in districts.buildings.size():
		if districts.district_of(i) == d:
			_colour_ring(i, S.controlled_border_color)


## The ground round building `b` and the rest of its unit: the hull of their walls,
## grown by the margin.
func _ring(b: Node3D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for piece in BuildingBox.pieces_of(b):
		var half := BuildingBox.size_of(piece) / 2.0 + Vector3.ONE * S.unit_ring_margin
		for corner in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z),
				Vector3(half.x, 0, half.z), Vector3(-half.x, 0, half.z)]:
			var p: Vector3 = piece.global_transform * corner
			points.append(Vector2(p.x, p.z))
	var hull := Geometry2D.convex_hull(points)
	hull.resize(hull.size() - 1)   # the hull repeats its first point at the end
	return hull


func _outline(index: int, ring: PackedVector2Array) -> void:
	for k in ring.size():
		var a := ring[k]
		var b := ring[(k + 1) % ring.size()]
		var mid := (a + b) / 2.0
		var turn := Basis(Vector3.UP, -(b - a).angle()) * Basis.from_scale(Vector3(a.distance_to(b), 1.0, S.border_width))
		_borders.set_instance_transform(_first_strip[index] + k, Transform3D(turn, Vector3(mid.x, BORDER_LIFT, mid.y)))
	_colour_ring(index, S.border_color)


func _colour_ring(index: int, color: Color) -> void:
	for k in range(_first_strip[index], _first_strip[index + 1]):
		_borders.set_instance_color(k, color)


func _add_instance(multimesh: MultiMesh) -> void:
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _unshaded(color: Color, from_instances: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if from_instances:
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
