class_name CampaignMarks
extends Node3D
## The takeover marks over the buildings: a skull (force), a dollar (buy) or a
## sky sign (missionaries) floating above the roof, with how many residents
## believe so far underneath ("3 / 7 believe"). Only marked buildings have one,
## so a Sprite3D and a Label3D each are cheap. They shrink as the camera comes
## in, so a close-up isn't covered by a 12 m dollar sign.

const S: CampaignSettings = preload("res://data/campaigns.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")
const ICONS: Array[Texture2D] = [
	preload("res://assets/icons/mark_force.png"),
	preload("res://assets/icons/mark_buy.png"),
	preload("res://assets/icons/mark_preach.png"),
]
const LIFT := 14.0          # metres above the roof
const ICON_PIXEL := 0.05    # metres per icon pixel (256 px = 12.8 m)

@export var campaigns: Campaigns
@export var districts: Districts

var _marks := {}            # building -> Label3D under its icon


func _ready() -> void:
	set_process(false)
	campaigns.campaign_started.connect(_on_started)
	campaigns.campaign_ended.connect(_on_ended)
	districts.counted.connect(_refresh)


func _on_started(building: Node3D, route: Campaigns.Route) -> void:
	var icon := Sprite3D.new()
	icon.texture = ICONS[route]
	icon.pixel_size = ICON_PIXEL
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.no_depth_test = true  # a mark stays readable behind a tower
	icon.render_priority = 99
	icon.add_to_group(&"no_toon")
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 96
	label.outline_size = 24
	label.pixel_size = 0.04
	label.no_depth_test = true
	label.render_priority = 100
	label.position = Vector3.DOWN * 9.5
	icon.add_child(label)
	add_child(icon)
	_marks[building] = label
	_place(building)
	set_process(true)


func _on_ended(building: Node3D, _route: Campaigns.Route, _won: bool) -> void:
	var label: Label3D = _marks.get(building)
	if label:
		label.get_parent().queue_free()
		_marks.erase(building)
	set_process(not _marks.is_empty())


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for building: Node3D in _marks:
		var icon: Node3D = _marks[building].get_parent()
		var distance := camera.global_position.distance_to(icon.global_position)
		var size := clampf(distance / S.mark_far_distance, S.mark_min_scale, 1.0)
		icon.scale = Vector3.ONE * size


func _refresh() -> void:
	for building: Node3D in _marks:
		_place(building)


## Follows the roof (+3 Floors) and updates the count under the icon.
func _place(building: Node3D) -> void:
	var label: Label3D = _marks[building]
	var top := building.global_position.y + DivineSign.building_size(building).y / 2.0
	label.get_parent().global_position = Vector3(building.global_position.x, top + LIFT, building.global_position.z)
	var i := districts.index_of(building)
	var people := districts.residents_in(i)
	var text := "%d / %d believe" % [districts.believers_at(i), people] if people > 0 else "empty"
	var stalled := campaigns.stalled_on(building)
	if stalled != "":
		text += "\n" + stalled
	if label.text != text:
		label.text = text
