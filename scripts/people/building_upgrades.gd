class_name BuildingUpgrades
extends RefCounted
## What has been bought for each building: a level per kind of upgrade. Attraction and
## Security are for any building of yours; Shop is for a building with a shop; Desks and
## Training are for an office. Every purchase makes the building's next one dearer.
## Followers owns one.

## `kind` was bought for `building`.
signal upgraded(building: Node3D, kind: Kind)

enum Kind { ATTRACTION, SECURITY, SHOP, DESKS, TRAINING }

const F: FollowersSettings = preload("res://data/followers.tres")

var _levels: Dictionary = {}   # building -> PackedInt32Array, one level per Kind


## How many times `kind` was bought for `building`.
func level(building: Node3D, kind: Kind) -> int:
	var levels: PackedInt32Array = _levels.get(building, PackedInt32Array())
	return levels[kind] if kind < levels.size() else 0


## What the next upgrade of any kind costs for `building`.
func cost(building: Node3D) -> float:
	var bought := 0
	for n: int in _levels.get(building, PackedInt32Array()):
		bought += n
	return F.upgrade_cost * pow(F.upgrade_growth, bought)


## Record `kind` as bought for `building` (the caller has taken the money).
func add(building: Node3D, kind: Kind) -> void:
	var levels: PackedInt32Array = _levels.get(building, PackedInt32Array())
	levels.resize(Kind.size())
	levels[kind] += 1
	_levels[building] = levels
	upgraded.emit(building, kind)


func forget(building: Node3D) -> void:
	_levels.erase(building)
