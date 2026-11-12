extends Label
## Bottom left: the district in the middle of the screen, how much of it is
## yours, how many residents of the building nearest the middle believe, a key
## to the takeover marks, and what City Hall is up to.

const S = preload("res://data/districts.tres")
const REFRESH := 0.25   # seconds; the text doesn't need to change every frame
const POOR := 0.6       # district wealth below this reads "poor", above RICH "rich"
const RICH := 1.4

@export var progress: DistrictProgress
@export var population: Population
@export var campaigns: Campaigns

var _timer := 0.0

@onready var districts: Districts = get_node("../../Districts")
@onready var government: Node = get_node("../../Government")
@onready var treasury: Treasury = get_node("../../Treasury")
@onready var police: Police = get_node("../../Police")
@onready var rig: Node3D = get_node("../../CameraRig")
@onready var landmarks: Landmarks = get_node("../../Landmarks")


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = REFRESH
	var d: int = districts.district_at(rig.target_pivot)
	var hold := "yours"
	if not districts.is_controlled(d):
		hold = "%d%% of the way (following %d%% + key places %d%%)" % [
				floori(progress.value(d) * 100.0), floori(progress.following(d) * 100.0),
				floori(progress.key_places(d) * 100.0)]
	var i := districts.building_near(rig.target_pivot)
	var people := districts.residents_in(i)
	var place := ""
	if districts.is_yours(i):
		var net := treasury.net_of(districts.buildings[i])
		place = "yours, %s $%.1f/s" % ["earns" if net >= 0.0 else "costs", absf(net)]
	else:
		if people == 0:
			place = "empty: move a member in (dollar or skull mark) and it is yours"
		else:
			place = "%d of %d residents are with us (more than half makes it yours)" % [districts.believers_at(i), people]
	var wealth := districts.wealth_of(d)
	var standing := " (poor)" if wealth < POOR else (" (rich)" if wealth > RICH else "")
	var core := "yours" if districts.is_yours(districts.core_of(d)) else "not yet yours"
	var marked := "Core: %s    Landmarks marked by the Field Delegate: %d of %d" \
			% [core, landmarks.marks_in(d), landmarks.buildings.size()]
	var block := districts.block_of(i)
	var whole := "complete: safe, and its people make x%.2f" % S.block_output_bonus \
			if districts.is_block_complete(block) \
			else "%d of %d buildings yours" % [districts.block_held(block), districts.block_size(block)]
	var next := S.next_working
	if population.believer_count <= 1:
		next = S.next_alone
	elif population.missionary_count == 0:
		next = S.next_train
	elif campaigns.marked().is_empty():
		next = S.next_canvass
	var line := next + "\n" + "Marks: skull = take by force, dollar = buy, sky sign = send canvassers\nDistrict: %s%s, %s\n%s\nBuilding: %s\nBlock: %s\nCity Hall: %s    Police: %s" % [districts.district_name(d), standing, hold, marked, place, whole, government.status_text(), police.status_text()]
	if text != line:
		text = line
