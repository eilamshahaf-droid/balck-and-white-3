class_name DistrictProgress
extends Node
## How far along each open district is toward being yours, as one bar, by the model's
## two ways to win. Control: most of its key buildings (key_win_share). Freedom: a few of
## them (key_part_share) and most of its people (control_share). The bar shows the way
## that is further along; full, the district is won.

## District `district`'s bar moved (1 = won).
signal changed(district: int, value: float)

const S: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts
@export var followers: Followers

var _values := PackedFloat32Array()
var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = S.progress_tick
	if _values.is_empty():
		_values.resize(districts.district_count())
	for d in _values.size():
		if not districts.is_unlocked(d) or districts.is_controlled(d):
			continue
		var now := value(d)
		if not is_equal_approx(now, _values[d]):
			_values[d] = now
			changed.emit(d, now)
		if now >= 1.0:
			districts.win(d)


## District `d`'s bar, 0 to 1: the better of the two ways.
func value(d: int) -> float:
	return maxf(control(d), freedom(d))


## The control way: your share of the key buildings against the share that wins.
func control(d: int) -> float:
	return minf(districts.key_share(d) / S.key_win_share, 1.0)


## The freedom way: half for the few key buildings it needs, half for the people.
func freedom(d: int) -> float:
	return 0.5 * minf(districts.key_share(d) / S.key_part_share, 1.0) \
			+ 0.5 * minf(followers.people_share(d) / S.control_share, 1.0)
