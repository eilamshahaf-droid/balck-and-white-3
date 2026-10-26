extends Label
## Bottom left: the district in the middle of the screen, how much of it is
## yours, and what City Hall is up to.

const S = preload("res://data/districts.tres")
const REFRESH := 0.25   # seconds; the text doesn't need to change every frame

var _timer := 0.0

@onready var districts: Node = get_node("../../Districts")
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
	text = "District: %s, %s\nCity Hall: %s" % [districts.district_name(d), hold, government.status_text()]
