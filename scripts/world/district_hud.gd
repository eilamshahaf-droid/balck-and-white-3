extends Label
## Bottom left, a few short lines: the district in the middle of the screen with your
## followers out of all its people, the block under the middle of the screen, and how far
## Reps reach (the influence radius, and the followers the next ring needs).

const S = preload("res://data/districts.tres")
const F: FollowersSettings = preload("res://data/followers.tres")
const REFRESH := 0.25   # seconds; the text doesn't need to change every frame
const POOR := 0.6       # district wealth below this reads "poor", above RICH "rich"
const RICH := 1.4

var _timer := 0.0

@onready var districts: Districts = get_node("../../Districts")
@onready var followers: Followers = get_node("../../Followers")
@onready var rig: Node3D = get_node("../../CameraRig")


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = REFRESH
	var d: int = districts.district_at(rig.target_pivot)
	var hold := "yours"
	if not districts.is_controlled(d):
		hold = "%d of its %d people follow you (%d%%), %d%% of its key buildings are yours" % [
				followers.followers_in(d), followers.people_in(d),
				floori(followers.people_share(d) * 100.0), floori(districts.key_share(d) * 100.0)]
		hold += "\nTo win: %d%% of the key buildings, or %d%% of them and %d%% of the people" % [
				roundi(S.key_win_share * 100.0), roundi(S.key_part_share * 100.0),
				roundi(S.control_share * 100.0)]
	var i := districts.building_near(rig.target_pivot)
	var wealth := districts.wealth_of(d)
	var standing := " (poor)" if wealth < POOR else (" (rich)" if wealth > RICH else "")
	var block := districts.block_of(i)
	var whole := "complete: followers come faster" if districts.is_block_complete(block) \
			else "%d of %d buildings yours" % [districts.block_held(block), districts.block_size(block)]
	var line := "District: %s%s, %s\nBlock here: %s" % [
			districts.district_name(d), standing, hold, whole]
	if not districts.is_controlled(d):
		var rings := followers.reach()
		line += "\nReps reach %d building%s out (%d at %d followers)" % [rings,
				"" if rings == 1 else "s", rings + 1, ceili(F.reach_followers * rings * rings)]
	if text != line:
		text = line
