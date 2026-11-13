class_name Inspectors
extends Node3D
## The city's answer (round B of the model). Reps at work and buildings taken raise the
## exposure; inspectors walk out of the nearest key building toward a Rep at a door, and
## past some exposure toward a building of yours. The hand can lift an inspector and set
## him down far away, which buys time; one who arrives demands paperwork. A Rep with no
## papers is sent home; a building that fails its audit is lost. Paperwork also buries
## the file, which lowers the exposure.

## An inspector left `from` (a key building).
signal sent(inspector: Inspector, from: Node3D)
## A Rep at `building` showed papers worth `cost`.
signal papers_shown(building: Node3D, cost: float)
## There was no paperwork: `rep` was sent home from `building`.
signal rep_sent_home(building: Node3D, rep: Resident)
## A building of yours passed its audit for `cost`.
signal audit_passed(building: Node3D, cost: float)
## A building of yours failed its audit and is lost.
signal turned_back(building: Node3D)
## An inspector ran out of patience at `at`.
signal gave_up(at: Vector3)

const I: InspectorSettings = preload("res://data/inspectors.tres")
const SIDEWALK_GAP := 1.5

@export var districts: Districts
@export var campaigns: Campaigns
@export var population: Population
@export var followers: Followers
@export var faith: Faith

## The inspectors out now.
var out: Array[Inspector] = []

var _buried := 0
var _timer := 0.0
var _next := I.first_seconds
var _coat := StandardMaterial3D.new()
var _skin := StandardMaterial3D.new()

@onready var city: City = get_parent()


func _ready() -> void:
	_coat.albedo_color = I.coat_color
	_skin.albedo_color = I.skin_color
	districts.building_changed.connect(_on_building_changed)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = I.tick
	faith.add_exposure(I.work_exposure_per_minute * _reps_at_work() * I.tick / 60.0)
	_next -= I.tick
	if _next <= 0.0 and out.size() < allowed():
		_next = lerpf(I.spawn_seconds, I.spawn_seconds_min, faith.exposure)
		_send()
	for inspector in out.duplicate():
		if inspector.lost or inspector.age > I.patience_seconds:
			gave_up.emit(inspector.global_position)
			_remove(inspector)
		elif inspector.arrived:
			_arrive(inspector)


## How many inspectors may be out at once at the exposure there is now.
func allowed() -> int:
	return I.max_base + floori(faith.exposure * I.max_extra)


## Paperwork a Rep must show an inspector now.
func demand_cost() -> float:
	return I.demand_paperwork * (1.0 + faith.exposure * I.demand_exposure)


## Paperwork an audit of building `index` of yours costs: by its room, less with Security.
func audit_cost(index: int) -> float:
	var security := followers.upgrades.level(districts.buildings[index], BuildingUpgrades.Kind.SECURITY)
	return I.audit_paperwork * maxf(followers.room_of(index) / I.ordinary_room, 1.0) \
			/ (1.0 + I.security_step * security)


## Paperwork burying the file costs now (more each time).
func bury_cost() -> float:
	return I.bury_paperwork * pow(I.bury_growth, _buried)


## Why the file can't be buried now; "" when it can.
func why_not_bury() -> String:
	if faith.exposure <= 0.01:
		return "nothing to bury"
	return "" if faith.belief_pool >= bury_cost() else "needs %d paperwork" % roundi(bury_cost())


## Spend paperwork to lower the exposure.
func bury() -> bool:
	if why_not_bury() != "" or not faith.spend(bury_cost()):
		return false
	_buried += 1
	faith.add_exposure(-I.bury_exposure)
	return true


## Send one inspector to `building` now (to audit it, or to a Rep at its door), from the
## key building nearest to it. Null when there is no key building left to send one.
func send_to(building: Node3D, audit: bool) -> Inspector:
	var from := _nearest_key(building.global_position)
	if from == null:
		return null
	var inspector := Inspector.new()
	inspector.build(_coat, _skin)
	inspector.building = building
	inspector.audit = audit
	add_child(inspector)
	inspector.global_position = _door_of(from)
	inspector.head_for(city, _door_of(building))
	out.append(inspector)
	sent.emit(inspector, from)
	return inspector


func _send() -> void:
	var doors: Array[Node3D] = []
	for b in campaigns.marked():
		if not campaigns.reps_at(b).is_empty() and not _is_target(b):
			doors.append(b)
	var yours: Array[Node3D] = []
	if faith.exposure >= I.audit_from and (doors.is_empty() or randf() < I.audit_chance):
		yours = _open_to_audit()
	if not yours.is_empty():
		send_to(yours[randi() % yours.size()], true)
	elif not doors.is_empty():
		send_to(doors[randi() % doors.size()], false)


## Buildings of yours an inspector may audit: not the Office, not in a complete block,
## and of those the ones with the least Security.
func _open_to_audit() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var least := 1 << 30
	for i in districts.buildings.size():
		var b := districts.buildings[i]
		if b == null or not districts.is_yours(i) or districts.is_base(b) \
				or districts.in_complete_block(i) or _is_target(b):
			continue
		var security := followers.upgrades.level(b, BuildingUpgrades.Kind.SECURITY)
		if security < least:
			least = security
			found.clear()
		if security == least:
			found.append(b)
	return found


func _arrive(inspector: Inspector) -> void:
	var b := inspector.building
	var i := districts.index_of(b)
	if inspector.audit:
		if i >= 0 and districts.is_yours(i):
			var cost := audit_cost(i)
			if faith.spend(cost):
				audit_passed.emit(b, cost)
			else:
				districts.lose(i)
				faith.add_exposure(-I.satisfied_exposure)
				turned_back.emit(b)
	else:
		var reps := campaigns.reps_at(b)
		if not reps.is_empty():
			var cost := demand_cost()
			if faith.spend(cost):
				papers_shown.emit(b, cost)
			else:
				var rep := reps[0]
				campaigns.dismiss(rep)
				# The Secretary can't be sent home for good: he walks back to the Office.
				if rep != population.priest:
					population.convert_to(rep, Resident.Rank.RESIDENT)
				faith.add_exposure(-I.satisfied_exposure)
				rep_sent_home.emit(b, rep)
	_remove(inspector)


func _remove(inspector: Inspector) -> void:
	out.erase(inspector)
	inspector.queue_free()


func _on_building_changed(index: int, yours: bool) -> void:
	if yours and index != districts.headquarters:
		faith.add_exposure(I.take_exposure)


func _reps_at_work() -> int:
	var n := 0
	for b in campaigns.marked():
		n += campaigns.reps_at(b).size()
	return n


func _is_target(building: Node3D) -> bool:
	for inspector in out:
		if inspector.building == building:
			return true
	return false


func _nearest_key(p: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for k in districts.keys:
		var b := districts.buildings[k]
		if b == null or districts.is_yours(k):
			continue
		var d := b.global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = b
	return best


## The pavement in front of `building` (its street side is local -z, see PlanBuilder).
func _door_of(building: Node3D) -> Vector3:
	var half := BuildingBox.size_of(building) / 2.0
	var spot := building.global_transform * Vector3(0.0, -half.y, -half.z - SIDEWALK_GAP)
	spot.y = 0.0
	return spot
