class_name Decrees
extends Node
## Stamped decrees: the god signs, and a building of his changes overnight. One of them
## today: more floors (more rows for rooms). Only on his own buildings, as Districts
## counts them; paid in paperwork and in money. It also puts up the sign of what a
## building is used for (a shop), which Rooms decides.

## A decree was carried out on `building`: &"floors" or &"use".
signal decree_issued(kind: StringName, building: Node3D)

const D: DecreeSettings = preload("res://data/decrees.tres")
const DecreeLooks := preload("res://scripts/decree_looks.gd")
const Sfx := preload("res://scripts/sfx.gd")

@export var faith: Faith
@export var districts: Districts
@export var treasury: Treasury


## What `building` is used for ("" for plain homes).
func use_of(building: Node3D) -> String:
	return building.get_meta(&"decree_use", "")


## The floors decree can't be signed for `building` again: there is a limit.
func is_done(_kind: StringName, building: Node3D) -> bool:
	return building.get_meta(&"decree_floors", 0) >= D.max_floor_decrees


## Are there paperwork and money enough for `kind` on `building`?
func can_afford(kind: StringName, building: Node3D) -> bool:
	return faith.belief_pool >= cost(kind) and treasury.can_afford(money_cost(kind, building))


## The money more floors cost on `building`: every further decree costs more.
func money_cost(_kind: StringName, building: Node3D) -> float:
	return D.floors_money * pow(D.floors_money_growth, building.get_meta(&"decree_floors", 0))


## The paperwork more floors cost.
func cost(_kind: StringName) -> float:
	return D.floors_cost


func price(kind: StringName, building: Node3D) -> String:
	return "%d paperwork + $%d" % [roundi(cost(kind)), roundi(money_cost(kind, building))]


## Sign the floors decree (`kind` &"floors") for `building`. False when it is not yours,
## is done already, or can't be paid for.
func issue(kind: StringName, building: Node3D) -> bool:
	if not districts.owns(building) or is_done(kind, building) or not can_afford(kind, building):
		return false
	faith.spend(cost(kind))
	treasury.spend_money(money_cost(kind, building))
	building.set_meta(&"decree_floors", building.get_meta(&"decree_floors", 0) + 1)
	DecreeLooks.grow(building, D.floors_per_decree)
	Sfx.play(get_tree(), building.global_position, &"chime", 0.7)
	decree_issued.emit(kind, building)
	return true


## `building` now has a shop in it (or no longer): its sign goes up or comes down.
func show_shop(building: Node3D, on: bool) -> void:
	if on == (use_of(building) == D.shop_use):
		return
	if on:
		building.set_meta(&"decree_use", D.shop_use)
		building.add_to_group(Population.SHOPS)
	else:
		building.remove_meta(&"decree_use")
		building.remove_from_group(Population.SHOPS)
	DecreeLooks.redecorate(building)
	decree_issued.emit(&"use", building)
