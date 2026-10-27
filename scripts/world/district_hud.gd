extends Label
## Bottom left: the district in the middle of the screen, how much of it is
## yours, how many residents of the building nearest the middle believe, a key
## to the takeover marks, and what City Hall is up to.

const S = preload("res://data/districts.tres")
const REFRESH := 0.25   # seconds; the text doesn't need to change every frame
const POOR := 0.6       # district wealth below this reads "poor", above RICH "rich"
const RICH := 1.4

var _timer := 0.0

@onready var districts: Districts = get_node("../../Districts")
@onready var government: Node = get_node("../../Government")
@onready var treasury: Treasury = get_node("../../Treasury")
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
	var people := districts.residents_in(i)
	var place := ""
	if districts.is_yours(i):
		var net := treasury.net_of(districts.buildings[i])
		place = "yours, %s $%.1f/s" % ["earns" if net >= 0.0 else "costs", absf(net)]
	else:
		if people == 0:
			place = "empty: move a believer in (dollar or skull mark) and it is yours"
		else:
			place = "%d of %d residents believe (more than half makes it yours)" % [districts.believers_at(i), people]
	var wealth := districts.wealth_of(d)
	var standing := " (poor)" if wealth < POOR else (" (rich)" if wealth > RICH else "")
	var line := "Marks: skull = take by force, dollar = buy, sky sign = send missionaries\nDistrict: %s%s, %s\nBuilding: %s\nCity Hall: %s" % [districts.district_name(d), standing, hold, place, government.status_text()]
	if text != line:
		text = line
