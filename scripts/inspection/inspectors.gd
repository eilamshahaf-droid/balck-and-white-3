class_name Inspectors
extends Node3D
## The city's answer (the Designer's plan for 0.26.0). A clerk of City Hall on a timer:
## the first walks out at first_seconds, then one every interval_seconds, more at once the
## higher the exposure (Reps at work and buildings taken raise it). Each walks from the
## nearest key building to a building of yours (not the Office; the least secure first)
## and takes the paperwork he demands; with too little he takes what there is and comes
## back to the same building return_seconds later. The hand can lift him and throw him
## far away, which buys time (he lies a shorter while each throw). Paperwork also buries
## the file, which lowers the exposure. A loud action of the Fixer's sends one to his
## door, and with no papers there the Fixer is sent back.

## An inspector left `from` (a key building).
signal sent(inspector: Inspector, from: Node3D)
## Building `building` of yours (or the Fixer at its door) showed papers worth `cost`.
signal papers_shown(building: Node3D, cost: float)
## There was too little paperwork at `building`: he took `taken` and will be back.
signal short_taken(building: Node3D, taken: float)
## There was no paperwork: the Fixer was sent back from key building `building`.
signal fixer_caught(building: Node3D)
## The hand threw an inspector (or set him down somewhere).
signal thrown(inspector: Inspector)
## An inspector ran out of patience at `at`.
signal gave_up(at: Vector3)

const I: InspectorSettings = preload("res://data/inspectors.tres")
const SIDEWALK_GAP := 1.5

@export var districts: Districts
@export var campaigns: Campaigns
@export var followers: Followers
@export var faith: Faith
@export var breaches: Breaches

## The inspectors out now.
var out: Array[Inspector] = []
## Seconds until the next inspectors walk out.
var next_in := I.first_seconds

var _buried := 0
var _returns := {}     # building -> seconds until an inspector comes back to it
var _timer := 0.0
var _coat := StandardMaterial3D.new()
var _skin := StandardMaterial3D.new()

@onready var city: City = get_parent()


func _ready() -> void:
	_coat.albedo_color = I.coat_color
	_skin.albedo_color = I.skin_color
	districts.building_changed.connect(_on_building_changed)
	breaches.loud.connect(func(b: Node3D) -> void: send_to(b))


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = I.tick
	faith.add_exposure(I.work_exposure_per_minute * _reps_at_work() * I.tick / 60.0)
	next_in -= I.tick
	if next_in <= 0.0:
		next_in = I.interval_seconds
		for n in at_once():
			var targets := _targets()
			if targets.is_empty():
				break
			send_to(targets[randi() % targets.size()])
	for b: Node3D in _returns.keys():
		_returns[b] -= I.tick
		if _returns[b] <= 0.0:
			_returns.erase(b)
			if is_instance_valid(b) and districts.owns(b) and not _is_target(b):
				send_to(b)
	for inspector in out.duplicate():
		if inspector.lost or inspector.age > I.patience_seconds:
			gave_up.emit(inspector.global_position)
			_remove(inspector)
		elif inspector.arrived:
			_arrive(inspector)


## How many inspectors walk out together at the exposure there is now.
func at_once() -> int:
	return 1 + floori(faith.exposure * I.per_exposure)


## Paperwork an inspector takes at building `index` of yours (or from the Fixer at a key
## building's door): by how many buildings you hold, less with Security.
func demand_cost(index := -1) -> float:
	var held := districts.converted_buildings().size()
	var security := followers.security_of(index) if index >= 0 and districts.is_yours(index) else 0
	return (I.demand_paperwork + I.demand_per_building * held) / (1.0 + I.security_step * security)


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
	if why_not_bury() != "" or not faith.spend(bury_cost(), &"bury"):
		return false
	_buried += 1
	faith.add_exposure(-I.bury_exposure)
	return true


## Send one inspector to `building` now (a building of yours, or the Fixer at its door),
## from the key building nearest to it other than itself. Null when there is no key
## building left to send one.
func send_to(building: Node3D) -> Inspector:
	var from := _nearest_key(building)
	if from == null:
		return null
	var inspector := Inspector.new()
	inspector.build(_coat, _skin)
	inspector.building = building
	inspector.thrown.connect(func() -> void: thrown.emit(inspector))
	add_child(inspector)
	inspector.global_position = _door_of(from)
	inspector.head_for(city, _door_of(building))
	out.append(inspector)
	sent.emit(inspector, from)
	return inspector


## Buildings of yours an inspector may walk to: not the Office, not one another is after,
## and of those the ones with the least Security.
func _targets() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var least := 1 << 30
	for i in districts.buildings.size():
		var b := districts.buildings[i]
		if b == null or not districts.is_yours(i) or districts.is_base(b) or _is_target(b):
			continue
		var security := followers.security_of(i)
		if security < least:
			least = security
			found.clear()
		if security == least:
			found.append(b)
	return found


func _arrive(inspector: Inspector) -> void:
	var b := inspector.building
	var i := districts.index_of(b)
	if i >= 0 and districts.is_yours(i):
		var cost := demand_cost(i)
		if faith.spend(cost, &"demand"):
			papers_shown.emit(b, cost)
		else:
			var taken := faith.belief_pool
			faith.spend(taken, &"demand")
			_returns[b] = I.return_seconds
			short_taken.emit(b, taken)
	elif breaches.target == b:
		var cost := demand_cost()
		if faith.spend(cost, &"demand"):
			papers_shown.emit(b, cost)
		else:
			breaches.caught(b)
			faith.add_exposure(-I.satisfied_exposure)
			fixer_caught.emit(b)
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


## The key building nearest to `to` that is not yours, and not `to` itself (the Fixer is
## at a key building's door: someone has to walk over from another).
func _nearest_key(to: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for k in districts.keys:
		var b := districts.buildings[k]
		if b == null or b == to or districts.is_yours(k):
			continue
		var d := b.global_position.distance_squared_to(to.global_position)
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
