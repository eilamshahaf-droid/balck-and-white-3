class_name DistrictView
extends Node3D
## Shows who holds what: a gold plate on the roof of every building of yours,
## and an outline on the roads around each district that turns gold once the
## district is yours. Both are MultiMeshes, so hundreds of roofs cost one draw
## call. The takeover marks (skull, dollar, sky sign) are campaign_marks.gd.

const S: DistrictSettings = preload("res://data/districts.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")
const ROOF_LIFT := 1.4      # above the roof modules (Kenney roofs stand about a metre proud of the box)
const ROOF_INSET := 0.8     # plate size as a share of the roof
const BORDER_LIFT := 0.03   # just above the asphalt

var _roofs := MultiMesh.new()
var _borders := MultiMesh.new()
var _hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)

@onready var districts: Districts = get_node("../Districts")


func _ready() -> void:
	districts.layout_ready.connect(_build)
	districts.building_changed.connect(_on_building_changed)
	districts.district_controlled.connect(_on_district_controlled)
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
	_borders.instance_count = districts.district_count() * 4
	for d in districts.district_count():
		_outline(d)
	_add_instance(_borders)


func _on_building_changed(index: int, yours: bool) -> void:
	var b: Node3D = districts.buildings[index]
	if b == null or not yours:
		_roofs.set_instance_transform(index, _hidden)
		return
	var size := DivineSign.building_size(b)  # live: decrees add floors
	var top := b.global_position + Vector3.UP * (size.y / 2.0 + ROOF_LIFT)
	_roofs.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(size.x, 1.0, size.z) * ROOF_INSET), top))


## +3 Floors lifts the roof, so the plate follows it.
func _on_decree_issued(_kind: StringName, building: Node3D) -> void:
	var i := districts.index_of(building)
	if i >= 0:
		_on_building_changed(i, districts.is_yours(i))


func _on_district_controlled(d: int) -> void:
	for side in 4:
		_borders.set_instance_color(d * 4 + side, S.controlled_border_color)


## Four strips just inside the district's edge, so two neighbours' outlines
## run side by side down the middle of the road between them.
func _outline(d: int) -> void:
	var r: Rect2 = districts.district_rect(d)
	var w := S.border_width
	var inset := w * 1.5
	var long := Vector3(r.size.x - inset * 2.0, 1.0, w)
	var tall := Vector3(w, 1.0, r.size.y - inset * 2.0)
	var mid := r.get_center()
	var strips: Array[Transform3D] = [
		Transform3D(Basis.from_scale(long), Vector3(mid.x, BORDER_LIFT, r.position.y + inset)),
		Transform3D(Basis.from_scale(long), Vector3(mid.x, BORDER_LIFT, r.end.y - inset)),
		Transform3D(Basis.from_scale(tall), Vector3(r.position.x + inset, BORDER_LIFT, mid.y)),
		Transform3D(Basis.from_scale(tall), Vector3(r.end.x - inset, BORDER_LIFT, mid.y)),
	]
	for side in 4:
		_borders.set_instance_transform(d * 4 + side, strips[side])
		_borders.set_instance_color(d * 4 + side, S.border_color)


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
