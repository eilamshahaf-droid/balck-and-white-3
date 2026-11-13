class_name Treasury
extends Node
## The money. It comes from the sellers in the shops (Followers.money_rate, after their
## pay) and goes on upgrades, floors and shops. One loan at a time: opened with
## paperwork, paid back out of a share of the takings, and any windfall (the money
## miracle's banknotes) goes to it first.

signal money_changed(money: float)

const S: TreasurySettings = preload("res://data/treasury.tres")
const F: FollowersSettings = preload("res://data/followers.tres")

@export var faith: Faith
@export var followers: Followers

var money := S.start_money
## Money per second right now, for the HUD.
var income := 0.0
## What is still owed on the loan (0: no loan).
var owed := 0.0

var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.tick
	income = followers.money_rate
	var gain := income * S.tick
	if owed > 0.0 and gain > 0.0:
		var paid := minf(gain * F.loan_repay_share, owed)
		owed -= paid
		gain -= paid
	money += gain
	money_changed.emit(money)


func can_afford(amount: float) -> bool:
	return money >= amount


func spend_money(amount: float) -> bool:
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money)
	return true


## Money from outside the takings (the money miracle): the loan is paid off first.
func add_money(amount: float) -> void:
	var paid := minf(amount, owed)
	owed -= paid
	money += amount - paid
	money_changed.emit(money)


## A loan can be opened: none is running, and there is the paperwork for it.
func can_borrow() -> bool:
	return owed <= 0.0 and faith.belief_pool >= F.loan_paperwork


func borrow() -> bool:
	if not can_borrow() or not faith.spend(F.loan_paperwork):
		return false
	owed = F.loan_owed
	money += F.loan_money
	money_changed.emit(money)
	return true
