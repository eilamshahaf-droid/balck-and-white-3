class_name Treasury
extends Node
## The cult's money: the collection box (every believer gives a little) and
## the shops believers open in your buildings with the Facade decree. Decrees,
## miracles and buying buildings spend it.

signal money_changed(money: float)

const S: TreasurySettings = preload("res://data/treasury.tres")

@export var faith: Node
@export var districts: Districts
@export var population: Node

var money := S.start_money
## Money per second right now, for the HUD.
var income := 0.0

var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.tick
	income = faith.believers * S.tithe_per_believer + _shop_income()
	add_money(income * S.tick)


func can_afford(amount: float) -> bool:
	return money >= amount


func spend_money(amount: float) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func add_money(amount: float) -> void:
	if amount == 0.0:
		return
	money += amount
	money_changed.emit(money)


## Shops in every building of yours that has the Facade decree.
func _shop_income() -> float:
	var total := 0.0
	for b in districts.converted_buildings():
		if b.get_meta(&"decree_facade", false):
			total += S.shop_income + S.shop_income_per_believer * districts.believers_in(b)
	return total
