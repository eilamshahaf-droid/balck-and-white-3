class_name Breaches
extends Node
## The Fixer at a key building (round C of the model). A key building can't be taken by
## a Rep until the Fixer has filled its bar. The hand sets him down at its door (or the
## wheel sends him), and there the wheel offers that building's own actions
## (data/fixer.tres): each costs paperwork, money and exposure, takes a while, and fills
## part of the bar. Quiet ones are small; loud ones are big and send an inspector to his
## door. Past a certain exposure he starts nothing. Opening is his talent: he goes to any
## key building, next to yours or not (taking it still needs a Rep next door). A full bar opens the building: a Rep
## can take it like any other, and once taken it is an office of yours.

## The Fixer started `action` at `building`.
signal action_started(building: Node3D, action: FixerAction)
## A loud action at `building`: City Hall sends someone to the door.
signal loud(building: Node3D)
## The Fixer finished at `building`: Reps can take it now.
signal opened(building: Node3D)
## What the Fixer is at changed (he arrived, left, finished an action, the bar moved).
signal changed(building: Node3D)

const F: FollowersSettings = preload("res://data/followers.tres")
const SIDEWALK_GAP := 1.5

@export var districts: Districts
@export var population: Population
@export var faith: Faith
@export var hand: GodHand
@export var treasury: Treasury

var settings: FixerSettings = load("res://data/fixer.tres")
## The key building the Fixer is at or on his way to, and the Fixer; null when idle.
var target: Node3D
var fixer: Resident
## The action in hand; null when he waits for the next order.
var doing: FixerAction

var _bar := {}         # building -> share of its bar filled, 0..1
var _left := 0.0       # seconds left of the action in hand
var _timer := 0.0


func _ready() -> void:
	population.fixer_set_down.connect(_on_fixer_set_down)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or target == null:
		return
	_timer = settings.tick
	if not is_instance_valid(fixer.body) or not fixer.body.on_errand:
		_leave()   # the hand lifted him away
		return
	if doing == null:
		return
	_left -= settings.tick * (F.attention if hand.pointed_part == target else 1.0)
	if _left > 0.0:
		return
	_bar[target] = minf(bar_of(target) + settings.progress(doing), 1.0)
	doing = null
	changed.emit(target)
	if bar_of(target) >= 1.0:
		var building := target
		districts.open_key(districts.index_of(building))
		fixer.body.end_errand()
		_leave()
		opened.emit(building)


## How much of key building `building`'s bar the Fixer has filled, 0..1.
func bar_of(building: Node3D) -> float:
	return _bar.get(building, 0.0)


## How far the action in hand is, 0..1.
func action_progress() -> float:
	return 1.0 - _left / settings.seconds(doing) if doing else 0.0


## The Fixer stands at `building`'s door, ready for orders.
func is_at(building: Node3D) -> bool:
	return target == building and is_instance_valid(fixer.body) and fixer.body.errand_arrived


## The Fixer's actions at key building `building`.
func actions_at(building: Node3D) -> Array[FixerAction]:
	return settings.actions_for(districts.key_name(districts.index_of(building)))


## Why the Fixer can't be sent to `building` now; "" when he can.
func why_not(building: Node3D) -> String:
	var i := districts.index_of(building)
	if i < 0 or not districts.is_key(i):
		return "not a key building"
	if districts.is_key_open(i):
		return "open already: send a Rep"
	if _free_fixer() == null:
		return "train a Fixer at the Office first"
	return ""


## Why the Fixer can't do `action` at `building` now; "" when he can.
func why_not_act(building: Node3D, action: FixerAction) -> String:
	if target != building:
		return "the Fixer isn't here"
	if not is_at(building):
		return "on the way"
	if doing:
		return "busy: %s" % doing.title
	if faith.exposure >= settings.gate_exposure:
		return "exposure %d%%: lie low" % roundi(faith.exposure * 100.0)
	if faith.belief_pool < settings.paperwork(action):
		return "needs %d paperwork" % roundi(settings.paperwork(action))
	if not treasury.can_afford(settings.money(action)):
		return "needs $%d" % roundi(settings.money(action))
	return ""


## "20 paperwork, $20: +15%" for the wheel.
func price_of(action: FixerAction) -> String:
	return "%d paperwork, $%d: +%d%%%s" % [roundi(settings.paperwork(action)),
			roundi(settings.money(action)), roundi(settings.progress(action) * 100.0),
			", loud" if action.loud else ""]


## The Fixer carries out `action` at `building`. True when he started it.
func act(building: Node3D, action: FixerAction) -> bool:
	if why_not_act(building, action) != "" \
			or not faith.spend(settings.paperwork(action), &"fixer_action"):
		return false
	treasury.spend_money(settings.money(action))
	faith.add_exposure(settings.exposure(action))
	doing = action
	_left = settings.seconds(action)
	action_started.emit(building, action)
	changed.emit(building)
	if action.loud:
		loud.emit(building)
	return true


## Send the Fixer to `building`; the same again calls him back.
func send(building: Node3D) -> bool:
	if target == building:
		call_back()
		return true
	if why_not(building) != "":
		return false
	var who := _free_fixer()
	population.bring_out(who)
	if not is_instance_valid(who.body):
		return false
	_assign(who, building)
	return true


## The Fixer leaves his key building and goes back to the Office.
func call_back() -> void:
	if target == null:
		return
	if is_instance_valid(fixer.body):
		fixer.body.end_errand()
	_leave()


## An inspector at the door found no paperwork: the Fixer is sent back and part of the
## bar is lost.
func caught(building: Node3D) -> void:
	if target != building:
		return
	_bar[building] = maxf(bar_of(building) - settings.caught_loss, 0.0)
	call_back()


## The hand set the Fixer down at key building `building`: he goes to work on it.
func _on_fixer_set_down(r: Resident, building: Node3D) -> void:
	var i := districts.index_of(building)
	if i < 0 or not districts.is_key(i) or districts.is_key_open(i) \
			or not is_instance_valid(r.body):
		return
	_assign(r, building)


func _assign(who: Resident, building: Node3D) -> void:
	if target and target != building:
		_leave()
	fixer = who
	target = building
	doing = null
	who.body.send_on_errand(_door_of(building), building.global_position, INF,
			settings.line, settings.line_color)
	changed.emit(building)


func _leave() -> void:
	var building := target
	target = null
	fixer = null
	doing = null   # an action he walked away from is lost, and so is what it cost
	changed.emit(building)


func _free_fixer() -> Resident:
	for r in population.residents:
		if r.rank == Resident.Rank.AGENT and r.alive and r.job == Resident.Job.FREE:
			return r
	return null


## The pavement in front of `building` (its street side is local -z, see PlanBuilder).
func _door_of(building: Node3D) -> Vector3:
	var half := BuildingBox.size_of(building) / 2.0
	var spot := building.global_transform * Vector3(0.0, -half.y, -half.z - SIDEWALK_GAP)
	spot.y = 0.0
	return spot
