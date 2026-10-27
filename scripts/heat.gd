class_name Heat
extends Node
## The police's hidden criteria. Each building quietly collects heat from what
## the cult does there (sit-ins, crowds, broken building rules, accidents),
## and loses it slowly. When a building's heat passes its threshold, which is
## higher in a hard district, the police step in: nothing is random, so the
## player can learn what draws attention. The player never sees the numbers.

## The police should step in at `building`; `reason` raised it over the line last.
signal police_called(building: Node3D, reason: Reason)

enum Reason { SIT_IN, CROWD, CODE_BREACH, ACCIDENT }

const S: HeatSettings = preload("res://data/heat.tres")

@export var population: Population

var _heat: Dictionary = {}       # building -> heat
var _last: Dictionary = {}       # building -> the Reason that raised it last
var _cooldown: Dictionary = {}   # building -> seconds before it can call again
var _hardness: Dictionary = {}   # building -> 0..1
var _timer := 0.0


func _ready() -> void:
	population.occupant_added.connect(
			func(building: Node3D, _r: Resident) -> void: raise(building, Reason.SIT_IN))


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.tick
	# Untyped: a demolished building's key is a freed object.
	for b in _heat.keys():
		if not is_instance_valid(b):
			_forget(b)
			continue
		_heat[b] = maxf(_heat[b] - S.decay * S.tick, 0.0)
		_cooldown[b] = maxf(_cooldown.get(b, 0.0) - S.tick, 0.0)
		if _heat[b] >= threshold(b) and _cooldown[b] <= 0.0:
			_cooldown[b] = S.cooldown
			police_called.emit(b, _last[b])
		elif _heat[b] <= 0.0:
			_forget(b)


## Something the police may notice happened at `building`, `times` over.
func raise(building: Node3D, reason: Reason, times := 1.0) -> void:
	_heat[building] = _heat.get(building, 0.0) + _amount(reason) * times
	_last[building] = reason


func heat_of(building: Node3D) -> float:
	return _heat.get(building, 0.0)


## How hard `building`'s district is (0 .. 1); the districts system sets it.
func set_hardness(building: Node3D, hardness: float) -> void:
	_hardness[building] = clampf(hardness, 0.0, 1.0)


func threshold(building: Node3D) -> float:
	return S.police_threshold * (1.0 + S.hardness_scale * _hardness.get(building, 0.0))


func _amount(reason: Reason) -> float:
	match reason:
		Reason.CROWD:
			return S.crowd
		Reason.CODE_BREACH:
			return S.code_breach
		Reason.ACCIDENT:
			return S.accident
	return S.sit_in


func _forget(building: Node3D) -> void:
	_heat.erase(building)
	_last.erase(building)
	_cooldown.erase(building)
