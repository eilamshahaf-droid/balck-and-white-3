class_name BuildingUpgrades
extends RefCounted
## What has been bought for each building: upgrades by kind and added floors.
## Each purchase costs more than the last one there and adds staff places.
## Population owns one and applies an upgrade's effect on people.

## `kind` was bought for `building` (see bought_in).
signal upgraded(building: Node3D, kind: Kind)

enum Kind {
	# Housing
	ELEVATOR, ROOF_GARDEN, CAMERAS, GATE,
	# Sermon house
	LOUDSPEAKER, BANNERS, LECTURE_HALL,
	# Workplace (a building of group shops)
	STOREFRONT, GYM, REAL_ESTATE, SEMINARY, RESTAURANT,
}

var _people: PeopleSettings
var _bought: Dictionary = {}      # building -> Array[Kind] bought for it
var _purchases: Dictionary = {}   # building -> upgrades and floors bought so far


func _init() -> void:
	# Loaded at run time: a parse-time preload would load the element scripts
	# before their class_name is registered and break the typed arrays.
	_people = load("res://data/people.tres")


## What the next upgrade or added floor for `building` costs.
func cost(building: Node3D) -> float:
	return _people.upgrade_base_cost * pow(_people.upgrade_cost_growth, _purchases.get(building, 0))


## Record `kind` as bought for `building` (the caller has taken the money).
func add(building: Node3D, kind: Kind) -> void:
	note_floor(building)
	if not _bought.has(building):
		var list: Array[Kind] = []
		_bought[building] = list
	(_bought[building] as Array[Kind]).append(kind)
	upgraded.emit(building, kind)


## The upgrades `building` can buy, by what it is: a sermon house, a workplace or a home.
func kinds_for(building: Node3D) -> Array[Kind]:
	if building.is_in_group(Population.PRAYER_HOUSES):
		return [Kind.LOUDSPEAKER, Kind.BANNERS, Kind.LECTURE_HALL]
	if building.is_in_group(Population.SHOPS):
		return [Kind.STOREFRONT, Kind.GYM, Kind.REAL_ESTATE, Kind.SEMINARY, Kind.RESTAURANT]
	return [Kind.ELEVATOR, Kind.ROOF_GARDEN, Kind.CAMERAS, Kind.GATE]


## How many times `kind` was bought for `building`.
func count_of(building: Node3D, kind: Kind) -> int:
	return (_bought.get(building, []) as Array).count(kind)


## The upgrades bought for `building`, in order (repeats allowed).
func bought_in(building: Node3D) -> Array[Kind]:
	var out: Array[Kind] = []
	out.append_array(_bought.get(building, []))
	return out


## A floor was added to `building` (decrees): counts toward the rising cost and adds staff places.
func note_floor(building: Node3D) -> void:
	_purchases[building] = _purchases.get(building, 0) + 1


## Staff places all purchases for `building` added.
func extra_places(building: Node3D) -> int:
	return _people.slots_per_purchase * _purchases.get(building, 0)


func forget(building: Node3D) -> void:
	_bought.erase(building)
	_purchases.erase(building)
