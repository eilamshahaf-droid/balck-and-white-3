class_name Decrees
extends Node
## Divine decrees: the god signs, and a building of his changes overnight.
## Add floors, luxury, facade, change of use, preservation (design doc,
## "Divine decrees"). Only on his own buildings, as Districts counts them.
## Paid in belief for now, cheaper among believers like the miracles; money
## and influence come later. Every decree draws a little attention.

## A decree was carried out on `building`.
signal decree_issued(kind: StringName, building: Node3D)
## A decree could not be issued: &"not_yours", &"no_belief" or &"done".
signal decree_failed(reason: StringName)

const D: DecreeSettings = preload("res://data/decrees.tres")
const M: MiracleSettings = preload("res://data/miracles.tres")
const DecreeLooks := preload("res://scripts/decree_looks.gd")
const Sfx := preload("res://scripts/sfx.gd")

## Group of preserved buildings: no demolition, no buying them from under you.
const PRESERVED := &"preserved"

@export var faith: Node
@export var miracles: Node
@export var districts: Node


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
			item.note = "%d belief" % roundi(cost(kind, building))
		item.enabled = yours and not is_done(kind, building) and faith.belief_pool >= cost(kind, building)
	return items


## The second wheel of "Change Use": one slice per use.
func use_items(building: Node3D) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var current := use_of(building)
	var price := cost(&"use", building)
	for i in D.uses.size():
		var use_name: String = D.uses[i]
		items.append({"id": StringName(use_name), "label": use_name,
				"color": Color.from_hsv(0.3 + 0.12 * i, 0.45, 0.9),
				"note": "now" if use_name == current else "%d belief" % roundi(price),
				"enabled": use_name != current and faith.belief_pool >= price})
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


## What `kind` costs on `building`: cheaper among believers.
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
	if not faith.spend(cost(kind, building)):
		decree_failed.emit(&"no_belief")
		return
	match kind:
		&"floors":
			building.set_meta(&"decree_floors", building.get_meta(&"decree_floors", 0) + 1)
			DecreeLooks.grow(building, D.floors_per_decree)
		&"use":
			building.set_meta(&"decree_use", use_name)
		_:
			building.set_meta(&"decree_" + kind, true)
	if kind == &"preserve":
		building.add_to_group(PRESERVED)
	if kind != &"floors":
		DecreeLooks.redecorate(building)
	faith.exposure = minf(faith.exposure + _exposure(kind), 1.0)
	Sfx.play(get_tree(), building.global_position, &"chime", 0.7)
	decree_issued.emit(kind, building)


func _exposure(kind: StringName) -> float:
	match kind:
		&"floors": return D.floors_exposure
		&"luxury": return D.luxury_exposure
		&"facade": return D.facade_exposure
		&"use": return D.use_exposure
		&"preserve": return D.preserve_exposure
	return 0.0
