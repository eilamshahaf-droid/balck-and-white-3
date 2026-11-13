extends Label
## Bottom left, three short lines: the district in the middle of the screen and how full
## its bar is, its key places, and the block under the middle of the screen.

const S = preload("res://data/districts.tres")
const REFRESH := 0.25   # seconds; the text doesn't need to change every frame
const POOR := 0.6       # district wealth below this reads "poor", above RICH "rich"
const RICH := 1.4

@export var progress: DistrictProgress

var _timer := 0.0

@onready var districts: Districts = get_node("../../Districts")
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
	var wealth := districts.wealth_of(d)
	var standing := " (poor)" if wealth < POOR else (" (rich)" if wealth > RICH else "")
	var block := districts.block_of(i)
	var whole := "complete: safe, and its people make x%.2f" % S.block_output_bonus \
			if districts.is_block_complete(block) \
			else "%d of %d buildings yours" % [districts.block_held(block), districts.block_size(block)]
	var line := "District: %s%s, %s\nKey places: core %s, %d of %d landmarks marked\nBlock here: %s" % [
			districts.district_name(d), standing, hold,
			"yours" if districts.is_yours(districts.core_of(d)) else "not yours",
			landmarks.marks_in(d), landmarks.buildings.size(), whole]
	if text != line:
		text = line
