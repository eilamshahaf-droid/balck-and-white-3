class_name DistrictProgress
extends Node
## How far along each open district is toward being yours: one bar. Until round C
## brings the key buildings and the two ways to win, it is the share of the district's
## buildings that are yours against the share that wins it, plus a part for its core.
## When the bar is full the district is won.

## District `district`'s bar moved (1 = won).
signal changed(district: int, value: float)

const S: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts

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


## What your buildings give: their share of the district against the share that wins it.
func following(d: int) -> float:
	return districts.share(d) / S.control_share


## What the key places give: the district's core, once it is yours.
func key_places(d: int) -> float:
	var core := districts.core_of(d)
	return S.core_points if core >= 0 and districts.is_yours(core) else 0.0
