class_name Decrees
extends Node
## Divine decrees: the god signs, and a building of his changes overnight.
## Add floors, luxury, facade, change of use, preservation (design doc,
## "Divine decrees"). Only on his own buildings, as Districts counts them.
## Paid in belief (cheaper among believers, like the miracles) and in money
## from the Treasury. Every decree draws a little attention.

## A decree was carried out on `building`.
signal decree_issued(kind: StringName, building: Node3D)
## A decree could not be issued: &"not_yours", &"no_belief", &"no_money" or
## &"done".
signal decree_failed(reason: StringName)

const D: DecreeSettings = preload("res://data/decrees.tres")
const M: MiracleSettings = preload("res://data/miracles.tres")
const DecreeLooks := preload("res://scripts/decree_looks.gd")
const Sfx := preload("res://scripts/sfx.gd")

## Group of preserved buildings: no demolition, no buying them from under you.
const PRESERVED := &"preserved"
## Group of buildings used as a Prayer House: only their believers pray belief
## into the pool (Population.prayer).
const PRAYER_HOUSES := &"prayer_houses"

@export var faith: Node
@export var miracles: Node
@export var districts: Node
@export var treasury: Treasury
@export var population: Population


## The decree slices of the building wheel for `building`, in order.
func wheel_items(building: Node3D) -> Array[Dictionary]:
	var items: Array[Dictionary] = [
		{"id": &"floors", "label": "+%d Floors" % D.floors_per_decree, "color": Color(0.95, 0.7, 0.35)},
		{"id": &"luxury", "label": "Luxury", "color": Color(1.0, 0.88, 0.5)},
		{"id": &"facade", "label": "Facade", "color": Color(0.8, 0.5, 0.95)},
		{"id": &"use", "label": "Change Use", "color": Color(0.6, 0.88, 0.5)},
		{"id": &"preserve", "label": "Preserve", "color": Color(0.8, 0.62, 0.45)},
	]
	var yours := is_yours(building)
	for item in items:
		var kind: StringName = item.id
		if not yours:
			item.note = "not yours"
		elif is_done(kind, building):
			item.note = "done"
		else:
			item.note = _price(kind, building)
			item.effect = _money_effect(building, kind)
		item.enabled = yours and not is_done(kind, building) and can_afford(kind, building)
	return items


## The second wheel of "Change Use": one slice per use.
func use_items(building: Node3D) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var current := use_of(building)
	var price := _price(&"use", building)
	var affordable := can_afford(&"use", building)
	for i in D.uses.size():
		var use_name: String = D.uses[i]
		items.append({"id": StringName(use_name), "label": use_name,
				"color": Color.from_hsv(0.3 + 0.12 * i, 0.45, 0.9),
				"note": "now" if use_name == current else price,
				"effect": _money_effect(building, &"use", use_name),
				"enabled": use_name != current and affordable})
	return items


## What `building` is used for since a Change Use decree ("" if none).
func use_of(building: Node3D) -> String:
	return building.get_meta(&"decree_use", "")


## Is `building` the god's? Districts is the one place that decides.
func is_yours(building: Node3D) -> bool:
	return districts.owns(building)


## Has `kind` gone as far as it can on `building`?
func is_done(kind: StringName, building: Node3D) -> bool:
	match kind:
		&"floors": return building.get_meta(&"decree_floors", 0) >= D.max_floor_decrees
		&"luxury", &"facade", &"preserve": return building.get_meta(&"decree_" + kind, false)
	return false  # a building can change its use again and again


## Are there belief and money enough for `kind` on `building`?
func can_afford(kind: StringName, building: Node3D) -> bool:
	return faith.belief_pool >= cost(kind, building) \
			and treasury.can_afford(money_cost(kind, building))


## The money `kind` costs on `building`: the same everywhere, but every further
## floor decree costs more than the last, until more floors don't pay.
func money_cost(kind: StringName, building: Node3D) -> float:
	match kind:
		&"floors":
			var done: int = building.get_meta(&"decree_floors", 0)
			return D.floors_money * pow(D.floors_money_growth, done)
		&"luxury": return D.luxury_money
		&"facade": return D.facade_money
		&"use": return D.use_money
		&"preserve": return D.preserve_money
	return 0.0


## The belief `kind` costs on `building`: cheaper among believers.
func cost(kind: StringName, building: Node3D) -> float:
	var base := 0.0
	match kind:
		&"floors": base = D.floors_cost
		&"luxury": base = D.luxury_cost
		&"facade": base = D.facade_cost
		&"use": base = D.use_cost
		&"preserve": base = D.preserve_cost
	return base * lerpf(M.weak_cost, M.strong_cost, miracles.power_at(building.global_position))


## Sign decree `kind` for `building`; a Change Use names the new use.
func issue(kind: StringName, building: Node3D, use_name := "") -> void:
	if not is_yours(building):
		decree_failed.emit(&"not_yours")
		return
	if is_done(kind, building):
		decree_failed.emit(&"done")
		return
	var money := money_cost(kind, building)
	if not treasury.can_afford(money):
		decree_failed.emit(&"no_money")
		return
	if not faith.spend(cost(kind, building)):
		decree_failed.emit(&"no_belief")
		return
	treasury.spend_money(money)
	match kind:
		&"floors":
			building.set_meta(&"decree_floors", building.get_meta(&"decree_floors", 0) + 1)
			DecreeLooks.grow(building, D.floors_per_decree)
		&"use":
			building.set_meta(&"decree_use", use_name)
			_set_group(building, PRAYER_HOUSES, use_name == D.prayer_use)
			_set_group(building, Population.SHOPS, use_name == D.shop_use)
		_:
			building.set_meta(&"decree_" + kind, true)
	if kind == &"luxury":
		population.add_comfort(building, D.luxury_comfort)
	if kind == &"preserve":
		building.add_to_group(PRESERVED)
	if kind != &"floors":
		DecreeLooks.redecorate(building)
	faith.exposure = minf(faith.exposure + _exposure(kind), 1.0)
	Sfx.play(get_tree(), building.global_position, &"chime", 0.7)
	decree_issued.emit(kind, building)


func _set_group(building: Node3D, group: StringName, member: bool) -> void:
	if member:
		building.add_to_group(group)
	elif building.is_in_group(group):
		building.remove_from_group(group)


func _price(kind: StringName, building: Node3D) -> String:
	return "%d belief + $%d" % [roundi(cost(kind, building)), roundi(money_cost(kind, building))]


## What the decree does to the building's money per second: "$/s +1.5 > -0.8",
## or "" when it changes nothing.
func _money_effect(building: Node3D, kind: StringName, use_name := "") -> String:
	var now := _tidy(treasury.net_of(building))
	var after := _tidy(treasury.net_if(building, kind, use_name))
	return "" if is_equal_approx(now, after) else "$/s %+.1f > %+.1f" % [now, after]


## Rounded to the tenth the wheel shows, so a tiny loss doesn't read "-0.0".
func _tidy(per_second: float) -> float:
	return snappedf(per_second, 0.1) + 0.0 if absf(per_second) >= 0.05 else 0.0


func _exposure(kind: StringName) -> float:
	match kind:
		&"floors": return D.floors_exposure
		&"luxury": return D.luxury_exposure
		&"facade": return D.facade_exposure
		&"use": return D.use_exposure
		&"preserve": return D.preserve_exposure
	return 0.0
