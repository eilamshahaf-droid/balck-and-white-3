class_name Breaches
extends Node
## The Fixer at a key building (round C of the model). A key building can't be taken by
## a Rep until the Fixer has opened it: he stands at its door and carries out a few
## actions one after the other. Each costs paperwork to start, takes time and raises the
## exposure, and as long as he is there he costs paperwork to keep. With no paperwork he
## waits. When the last action is done the building is open: a Rep can take it like any
## other, and once taken it is an office of yours.

## The Fixer started action number `step` (from 0) at `building`.
signal action_started(building: Node3D, step: int)
## The Fixer finished at `building`: Reps can take it now.
signal opened(building: Node3D)
## What the Fixer is at changed (he arrived, left, ran out of paperwork).
signal changed(building: Node3D)

const S: DistrictSettings = preload("res://data/districts.tres")
const F: FollowersSettings = preload("res://data/followers.tres")
const SIDEWALK_GAP := 1.5

@export var districts: Districts
@export var population: Population
@export var faith: Faith
@export var hand: GodHand

## The key building the Fixer is at or on his way to, and the Fixer; null when idle.
var target: Node3D
var fixer: Resident
## What holds him up, "" while he works.
var stalled := ""

var _done := {}        # building -> actions finished there
var _left := 0.0       # seconds left of the action in hand; 0 when none is
var _timer := 0.0


func _ready() -> void:
	population.fixer_set_down.connect(_on_fixer_set_down)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or target == null:
		return
	_timer = S.breach_tick
	if not is_instance_valid(fixer.body) or not fixer.body.on_errand:
		_leave()   # the hand lifted him away
		return
	if not fixer.body.errand_arrived:
		_stall("on the way")
		return
	if not faith.spend(S.breach_presence_paperwork * S.breach_tick / 60.0):
		_stall("no paperwork: the Fixer waits")
		return
	if _left <= 0.0:
		if not faith.spend(S.breach_action_paperwork):
			_stall("needs %d paperwork" % roundi(S.breach_action_paperwork))
			return
		_left = S.breach_action_seconds
		faith.add_exposure(S.breach_action_exposure)
		action_started.emit(target, actions_done(target))
	_stall("")
	_left -= S.breach_tick * (F.attention if hand.pointed_part == target else 1.0)
	if _left > 0.0:
		return
	_done[target] = actions_done(target) + 1
	changed.emit(target)
	if actions_done(target) >= S.breach_actions:
		var building := target
		districts.open_key(districts.index_of(building))
		fixer.body.end_errand()
		_leave()
		opened.emit(building)


## Actions finished at key building `building` so far.
func actions_done(building: Node3D) -> int:
	return _done.get(building, 0)


## How far the action in hand is, 0..1.
func action_progress() -> float:
	return 1.0 - _left / S.breach_action_seconds if _left > 0.0 else 0.0


## Why the Fixer can't be sent to `building` now; "" when he can.
func why_not(building: Node3D) -> String:
	var i := districts.index_of(building)
	if i < 0 or not districts.is_key(i):
		return "not a key building"
	if districts.is_key_open(i):
		return "open already: send a Rep"
	if not districts.borders_yours(i):
		return "must border a building of yours"
	if _free_fixer() == null:
		return "train a Fixer at the Office first"
	return ""


## Send the Fixer to `building`; the same again calls him back.
func send(building: Node3D) -> bool:
	if target == building:
		fixer.body.end_errand()
		_leave()
		return true
	if why_not(building) != "":
		return false
	var who := _free_fixer()
	population.bring_out(who)
	if not is_instance_valid(who.body):
		return false
	_assign(who, building)
	who.body.send_on_errand(_door_of(building), building.global_position, INF,
			S.breach_line, S.breach_line_color)
	return true


## The hand set the Fixer down at key building `building`: he goes to work on it.
func _on_fixer_set_down(r: Resident, building: Node3D) -> void:
	var i := districts.index_of(building)
	if i < 0 or not districts.is_key(i) or districts.is_key_open(i) \
			or not districts.borders_yours(i) or not is_instance_valid(r.body):
		return
	_assign(r, building)
	r.body.send_on_errand(_door_of(building), building.global_position, INF,
			S.breach_line, S.breach_line_color)


func _assign(who: Resident, building: Node3D) -> void:
	if target and target != building:
		_leave()
	fixer = who
	target = building
	_left = 0.0
	changed.emit(building)


func _leave() -> void:
	var building := target
	target = null
	fixer = null
	_left = 0.0   # an action he walked away from is started again
	stalled = ""
	changed.emit(building)


func _stall(why: String) -> void:
	if stalled != why:
		stalled = why
		changed.emit(target)


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
