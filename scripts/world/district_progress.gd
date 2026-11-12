class_name DistrictProgress
extends Node
## How far along each open district is toward being yours: one bar with two sources
## (Eilam's rule). A wide following fills it: the share of the district's buildings that
## are yours, worth more the better your believers live. Key places fill it too: the
## district's core once it is yours, and every landmark that carries a mark. Either alone
## is hard (most of the district, or every key place and a fair area besides); together
## they give the player room to choose. When the bar is full the district is won.

## District `district`'s bar moved (1 = won).
signal changed(district: int, value: float)

const S: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts
@export var landmarks: Landmarks
@export var population: Population

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
		var now := following(d) + key_places(d)
		if not is_equal_approx(now, _values[d]):
			_values[d] = now
			changed.emit(d, now)
		if now >= 1.0:
			districts.win(d)


## District `d`'s bar, 0 to 1 and past it.
func value(d: int) -> float:
	return following(d) + key_places(d)


## What the following gives: the share of the buildings that are yours against the share
## that wins the district alone, times how well your believers live.
func following(d: int) -> float:
	return districts.share(d) / S.control_share \
			* lerpf(S.welfare_low, S.welfare_high, population.welfare)


## What the key places give: the core, and each marked landmark.
func key_places(d: int) -> float:
	var core := districts.core_of(d)
	var held := S.core_points if core >= 0 and districts.is_yours(core) else 0.0
	return held + S.landmark_points * landmarks.marks_in(d)
