class_name DistrictView
extends Node3D
## Shows who holds what, so the takeover reads at a glance. Every building
## shows what the player can do with it (Districts.Reach): a gold roof plate
## when it is yours, red when it is abandoned and can be taken over, green when
## it is next to yours and can be converted, nothing while it is out of reach.
## The claim filling up shows either as gold spreading over the roof (plates)
## or as a glass column over it that fills with gold (beacons). An outline on
## the roads around each district turns gold once the district is yours. All
## of it is MultiMeshes, so hundreds of roofs cost a few draw calls.

enum Style { PLATES, BEACONS }

const S = preload("res://data/districts.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")
const ROOF_LIFT := 1.4      # above the roof modules (Kenney roofs stand about a metre proud of the box)
const ROOF_INSET := 0.8     # plate size as a share of the roof
const FILL_LIFT := 0.1      # the gold fill just above the plate
const RISE_INSET := 0.6     # the gold in a beacon, as a share of the glass
const BORDER_LIFT := 0.03   # just above the asphalt

var style: Style = S.marker_style as Style

var _roofs := MultiMesh.new()
var _fills := MultiMesh.new()
var _tubes := MultiMesh.new()
var _rises := MultiMesh.new()
var _borders := MultiMesh.new()
var _hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)

@onready var districts: Districts = get_node("../Districts")


func _ready() -> void:
	districts.layout_ready.connect(_build)
	districts.building_changed.connect(func(i: int, _yours: bool) -> void: _refresh(i))
	districts.claims_updated.connect(_refresh_all)
	districts.district_controlled.connect(_on_district_controlled)
	get_node("../Decrees").decree_issued.connect(_on_decree_issued)


## Plates or beacons (the debug panel switches to compare them).
func toggle_style() -> void:
	style = Style.BEACONS if style == Style.PLATES else Style.PLATES
	_refresh_all()


func _build() -> void:
	var count := districts.buildings.size()
	var plate := BoxMesh.new()
	plate.size = Vector3(1.0, 0.25, 1.0)
	plate.material = _unshaded(Color.WHITE, true)
	var column := BoxMesh.new()
	column.material = plate.material
	for m: MultiMesh in [_roofs, _fills, _tubes, _rises]:
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_colors = true
		m.mesh = plate if m == _roofs or m == _fills else column
		m.instance_count = count
		_add_instance(m)
	_refresh_all()

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


func _refresh_all() -> void:
	for i in _roofs.instance_count:
		_refresh(i)


func _refresh(i: int) -> void:
	var b: Node3D = districts.buildings[i]
	var reach := districts.reach_of(i) if b else Districts.Reach.LOCKED
	var claiming := reach == Districts.Reach.TAKE or reach == Districts.Reach.CONVERT
	var show_plate := reach == Districts.Reach.YOURS or (claiming and style == Style.PLATES)
	var show_beacon := claiming and style == Style.BEACONS
	if not show_plate:
		_roofs.set_instance_transform(i, _hidden)
		_fills.set_instance_transform(i, _hidden)
	if not show_beacon:
		_tubes.set_instance_transform(i, _hidden)
		_rises.set_instance_transform(i, _hidden)
	if not (show_plate or show_beacon):
		return
	var size := DivineSign.building_size(b)  # live: decrees add floors
	var top := b.global_position + Vector3.UP * (size.y / 2.0 + ROOF_LIFT)
	var roof := Vector3(size.x, 1.0, size.z) * ROOF_INSET
	var claim := districts.claim_of(i)
	var color := S.take_color if reach == Districts.Reach.TAKE else S.convert_color
	if show_plate:
		_roofs.set_instance_color(i, S.roof_color if reach == Districts.Reach.YOURS else color)
		_roofs.set_instance_transform(i, Transform3D(Basis.from_scale(roof), top))
		if claiming and claim > 0.0:
			# Area grows with the claim, so a half-claimed roof looks half gold.
			var fill := roof * Vector3(sqrt(claim), 1.0, sqrt(claim))
			_fills.set_instance_color(i, S.roof_color)
			_fills.set_instance_transform(i, Transform3D(Basis.from_scale(fill), top + Vector3.UP * FILL_LIFT))
		else:
			_fills.set_instance_transform(i, _hidden)
	if show_beacon:
		var w := S.beacon_width
		var h := S.beacon_height
		_tubes.set_instance_color(i, color)
		_tubes.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w, h, w)), top + Vector3.UP * h / 2.0))
		if claim > 0.0:
			var rise := Vector3(w * RISE_INSET, h * claim, w * RISE_INSET)
			_rises.set_instance_color(i, S.roof_color)
			_rises.set_instance_transform(i, Transform3D(Basis.from_scale(rise), top + Vector3.UP * rise.y / 2.0))
		else:
			_rises.set_instance_transform(i, _hidden)


## +3 Floors lifts the roof, so the markers follow it.
func _on_decree_issued(_kind: StringName, building: Node3D) -> void:
	var i: int = districts.buildings.find(building)
	if i >= 0:
		_refresh(i)


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
