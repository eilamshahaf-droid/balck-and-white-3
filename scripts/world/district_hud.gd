extends Label
## Bottom left: the district in the middle of the screen, how much of it is
## yours, what you can do with the building nearest the middle and how far
## its claim has come, a key to the roof colours, and what City Hall is up to.

const S = preload("res://data/districts.tres")
const REFRESH := 0.25   # seconds; the text doesn't need to change every frame

var _timer := 0.0

@onready var districts: Districts = get_node("../../Districts")
@onready var government: Node = get_node("../../Government")
@onready var rig: Node3D = get_node("../../CameraRig")


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = REFRESH
	var d: int = districts.district_at(rig.target_pivot)
	var hold := "yours"
	if not districts.is_controlled(d):
		hold = "%d%% yours (%d%% takes it)" % [roundi(districts.share(d) * 100.0), roundi(S.control_share * 100.0)]
	var i := districts.building_near(rig.target_pivot)
	var claim := roundi(districts.claim_of(i) * 100.0)
	var place := ""
	match districts.reach_of(i):
		Districts.Reach.YOURS:
			place = "yours"
		Districts.Reach.TAKE:
			place = "abandoned, take it over: %d%% (set believers down on it)" % claim
		Districts.Reach.CONVERT:
			place = "next to yours, convert it: %d%% (believers who live there or sit in)" % claim
		Districts.Reach.LOCKED:
			place = "out of reach (take an abandoned place or a building next to yours first)"
	text = "Roofs: gold = yours, red = abandoned (take it over), green = next to yours (convert it); gold fills as you claim\nDistrict: %s, %s\nBuilding: %s\nCity Hall: %s" % [districts.district_name(d), hold, place, government.status_text()]
