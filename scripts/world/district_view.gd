class_name DistrictView
extends Node3D
## Shows who holds what: a gold plate on the roof of every building of yours, and a
## ring on the ground round each block that warms toward gold as more of the block is
## yours and is solid gold once it is complete (the block bonus).
## All MultiMeshes, so hundreds of roofs cost one draw call. The takeover marks (skull,
## dollar, sky sign) are campaign_marks.gd.

const S: DistrictSettings = preload("res://data/districts.tres")
const ROOF_LIFT := 1.4      # above the roof modules (Kenney roofs stand about a metre proud of the box)
const ROOF_INSET := 0.8     # plate size as a share of the roof
const BORDER_LIFT := 0.08   # just above the asphalt
const NOTE_LIFT := 14.0     # the "block complete" note floats this far up
const PARTLY := 0.7         # how far toward gold a nearly complete block's ring goes

var _roofs := MultiMesh.new()
var _borders := MultiMesh.new()
var _cores := MultiMesh.new()
var _hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
var _first_strip := PackedInt32Array()    # per block: its first ring strip (one more at the end)

@onready var districts: Districts = get_node("../Districts")


func _ready() -> void:
	districts.layout_ready.connect(_build)
	districts.building_changed.connect(_on_building_changed)
	districts.block_changed.connect(_on_block_changed)
	districts.district_controlled.connect(_on_district_controlled)
	districts.core_changed.connect(_place_core)
	get_node("../Decrees").decree_issued.connect(_on_decree_issued)


func _build() -> void:
	var plate := BoxMesh.new()
	plate.size = Vector3(1.0, 0.25, 1.0)
	plate.material = _unshaded(S.roof_color, false)
	_roofs.transform_format = MultiMesh.TRANSFORM_3D
	_roofs.mesh = plate
	_roofs.instance_count = districts.buildings.size()
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
	for block in districts.block_count():
		rings.append(_ring(block))
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
	_colour_block(districts.block_of(index))
	var b: Node3D = districts.buildings[index]
	if not yours or b == null:
		_roofs.set_instance_transform(index, _hidden)
		return
	var size := BuildingBox.size_of(b)  # live: decrees add floors
	var top := b.global_position + Vector3.UP * (size.y / 2.0 + ROOF_LIFT)
	var turn := b.global_basis.orthonormalized() * Basis.from_scale(Vector3(size.x, 1.0, size.z) * ROOF_INSET)
	_roofs.set_instance_transform(index, Transform3D(turn, top))


func _on_block_changed(block: int, complete: bool) -> void:
	_colour_block(block)
	if not complete:
		return
	var middle := Vector3.ZERO
	var members := districts.block_members(block)
	for i in members:
		if districts.buildings[i]:
			middle += districts.buildings[i].global_position / districts.block_size(block)
	FloatingNote.pop(self, middle + Vector3.UP * NOTE_LIFT, S.block_note, S.controlled_border_color)


## +3 Floors lifts the roof, so the plate follows it.
func _on_decree_issued(_kind: StringName, building: Node3D) -> void:
	var i := districts.index_of(building)
	if i >= 0:
		_on_building_changed(i, districts.is_yours(i))


func _on_district_controlled(_d: int) -> void:
	for block in districts.block_count():
		_colour_block(block)


## The ground round `block`: the hull of its buildings' walls, grown by the margin.
func _ring(block: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in districts.block_members(block):
		var piece := districts.buildings[i]
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
	_colour_block(index)


## A block's ring: white, warming toward gold with the share of it that is yours, and
## solid gold once it is complete or its district is yours.
func _colour_block(block: int) -> void:
	var held := float(districts.block_held(block)) / maxi(districts.block_size(block), 1)
	var color := S.border_color.lerp(S.controlled_border_color, held * PARTLY)
	if districts.is_block_complete(block) or districts.is_controlled(_district_of_block(block)):
		color = S.controlled_border_color
	for k in range(_first_strip[block], _first_strip[block + 1]):
		_borders.set_instance_color(k, color)


func _district_of_block(block: int) -> int:
	for i in districts.block_members(block):
		if districts.district_of(i) >= 0:
			return districts.district_of(i)
	return districts.start_district()


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
