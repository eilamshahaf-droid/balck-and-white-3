class_name Treasury
extends Node
## The cult's money. It comes from the believers (each by their wealth and
## needs, Population.tithes) and from the buildings of yours: each one earns or costs money every
## second, by what the decrees made of it (net_of()). Decrees, miracles and
## buying buildings spend it.

signal money_changed(money: float)

const S: TreasurySettings = preload("res://data/treasury.tres")

@export var faith: Node
@export var population: Population
@export var districts: Districts
@export var decrees: Decrees
@export var police: Police

var money := S.start_money
## Money per second right now, for the HUD.
var income := 0.0

var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.tick
	# Only seated believers cost upkeep: the unseated already cost half their output.
	var seated := mini(population.believer_count, population.seats)
	income = population.tithes - seated * S.believer_upkeep / 60.0
	for b in districts.converted_buildings():
		income += net_of(b)
	var was := money
	var change := income * S.tick
	if change < 0.0:
		change = maxf(change, minf(S.debt_floor - money, 0.0))
	add_money(change)
	if was >= 0.0 and money < 0.0:
		var base := districts.start_building()
		if base:
			FloatingNote.pop(self, base.global_position + Vector3.UP * 12.0,
					S.overdrawn_line, S.overdrawn_color)


## While the treasury is overdrawn only what is free can be had (training a canvasser).
func can_afford(amount: float) -> bool:
	return amount <= 0.0 or (money >= 0.0 and money >= amount)


func spend_money(amount: float) -> bool:
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money)
	return true


func add_money(amount: float) -> void:
	if amount == 0.0:
		return
	money += amount
	money_changed.emit(money)


## Money per second `building` earns (positive) or costs (negative) as yours.
func net_of(building: Node3D) -> float:
	return _net(building, decrees.use_of(building), building.get_meta(&"decree_luxury", false),
			building.get_meta(&"decree_floors", 0))


## What net_of() would be after decree `kind` (a Change Use names the use),
## so the wheel can show what a decree does to the money.
func net_if(building: Node3D, kind: StringName, use_name := "") -> float:
	var use := decrees.use_of(building)
	var luxury: bool = building.get_meta(&"decree_luxury", false)
	var levels: int = building.get_meta(&"decree_floors", 0)
	match kind:
		&"use": use = use_name
		&"luxury": luxury = true
		&"floors": levels += 1
	return _net(building, use, luxury, levels)


## How much faster the building does its job: luxury.
func speed_of(building: Node3D) -> float:
	return S.luxury_speed if building.get_meta(&"decree_luxury", false) else 1.0


## How much more the building yields for its floors.
func efficiency_of(building: Node3D) -> float:
	return _efficiency(building.get_meta(&"decree_floors", 0))


func _net(building: Node3D, use: String, luxury: bool, levels: int) -> float:
	var i := districts.index_of(building)
	if i < 0:
		return 0.0
	var gain := 0.0
	var upkeep := S.floor_upkeep * levels * levels
	if use == "":
		gain = S.dues_per_resident * districts.residents_in(i)
	elif use == S.shop_use:
		gain = S.shop_income + S.shop_income_per_believer * districts.believers_at(i)
	else:
		upkeep += S.use_upkeep
	if luxury:
		gain *= S.luxury_speed
		upkeep += S.luxury_upkeep
	if police.is_blockaded(building):
		gain = 0.0
	return gain * _efficiency(levels) * districts.wealth_at(i) - upkeep


func _efficiency(levels: int) -> float:
	return 1.0 + S.floor_gain * (1.0 - pow(S.floor_falloff, levels))
