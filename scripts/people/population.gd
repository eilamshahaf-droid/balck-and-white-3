class_name Population
extends Node
## The city's people. Once the city is built, every building gets its residents (Census),
## each a `Resident` record with a name and an archetype; about one in residents_per_body
## walks the street as a `Citizen` body (Street), the rest are indoors. They are the crowd:
## followers are numbers now (Followers), not people.
##
## The people who matter one by one are the units the hand lifts: the Secretary
## (`priest`, at the main Office), Reps (`Rank.MISSIONARY`) and, later, the Fixer. A Rep
## is trained at the Office out of one follower of the pool (Staffing), is set down by the
## hand at a building's door (`canvasser_set_down`, which Campaigns answers), and once the
## building is taken stays inside as its Manager (`make_manager`). A change of rank is
## announced with `rank_changed`.

## `resident`'s rank changed (trained, made a Manager's neighbour, lost).
signal rank_changed(resident: Resident, old: Resident.Rank, new: Resident.Rank)
## The game is set up: the Secretary is at the main Office, `building`.
signal cult_founded(building: Node3D)
## The hand set a Rep down at `building`, which is not yours.
signal canvasser_set_down(resident: Resident, building: Node3D)

## Group of buildings with a shop (a Change Use decree).
const SHOPS := &"shops"
const U: UnitSettings = preload("res://data/units.tres")
const F: FollowersSettings = preload("res://data/followers.tres")

@export var districts: Districts
@export var hand: GodHand

## Every person, by id.
var residents: Array[Resident] = []
## The Secretary.
var priest: Resident
## Reps in all, and of them how many are free to be sent; how many are out against the
## cap (free, at a door or in training; Managers don't count); Fixers.
var missionary_count := 0
var free_rep_count := 0
var reps_out := 0
var agent_count := 0
var staffing := Staffing.new(self)

var _by_home: Dictionary = {}     # building -> Array[Resident]
var _footprints: Dictionary = {}  # building -> Rect2 on the ground (x, z)
var _timer := 0.0
var _census: Census
var _street := Street.new()
var _rng := RandomNumberGenerator.new()
# Loaded at run time: a parse-time preload would load the element scripts before
# their class_name is registered and break the typed arrays.
var _people: PeopleSettings = load("res://data/people.tres")
var _archetypes: ArchetypeSettings = load("res://data/archetypes.tres")

@onready var city: City = get_parent()


func _ready() -> void:
	_rng.seed = 7
	add_child(Crowd.new())
	_street.set_down.connect(_on_set_down)
	add_child(_street)
	districts.building_changed.connect(_on_building_changed)
	# The city builds its blocks in its own _ready, which runs after ours.
	city.ready.connect(_populate, CONNECT_ONE_SHOT)


## Training goes on a few times a second; faster while the god's hand is on the Office.
func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _people.presence_refresh
	for r in residents:
		if r.job != Resident.Job.TRAIN:
			continue
		var watched := hand != null and hand.pointed_part == r.post
		staffing.tick_training(r, _people.presence_refresh * (F.attention if watched else 1.0))


## Rep `r` took `building` over: they stay inside and run it, and the people who live
## there are with you (the crowd shows it).
func make_manager(r: Resident, building: Node3D) -> void:
	staffing.post(r, Resident.Job.MANAGER, building)
	put_away(r)
	for resident: Resident in _by_home.get(building, []):
		if resident.rank == Resident.Rank.RESIDENT:
			convert_to(resident, Resident.Rank.BELIEVER)
	_count_ranks()


## Someone living in a building of yours starts training at `building` for `rank`.
func start_training(rank: Resident.Rank, building: Node3D) -> void:
	staffing.train(recruit(building.global_position), rank, building)
	_count_ranks()


## How far the furthest-along trainee for `rank` is, 0..1; 0 when nobody trains for it.
func training_progress(rank: Resident.Rank) -> float:
	var full := U.missionary_time if rank == Resident.Rank.MISSIONARY else U.agent_time
	var best := 0.0
	for r in residents:
		if r.job == Resident.Job.TRAIN and r.training_for == rank:
			best = maxf(best, 1.0 - r.training_left / full)
	return best


## A building that is lost has no Manager any more (the Rep is lost with it), and its
## people are the city's again.
func _on_building_changed(index: int, yours: bool) -> void:
	var building := districts.buildings[index]
	if yours or building == null:
		return
	var manager := manager_of(building)
	if manager:
		staffing.unassign(manager)
		convert_to(manager, Resident.Rank.RESIDENT)
	for resident: Resident in _by_home.get(building, []):
		if resident.rank == Resident.Rank.BELIEVER:
			convert_to(resident, Resident.Rank.RESIDENT)


func _populate() -> void:
	_census = Census.new(_people, _archetypes, _rng, districts.kind_at)
	_census.take(get_tree().get_nodes_in_group("buildings"))
	residents = _census.residents
	_by_home = _census.by_home
	_street.fill(city, _by_home, residents)
	for b: Node3D in _by_home:
		_footprints[b] = _footprint(b)
	found_cult.call_deferred()


## The hand set someone down at a building. A Rep at a building that is
## not yours goes to work on it; nobody else takes orders.
func _on_set_down(c: Citizen) -> void:
	var r := c.resident
	if not r.preaches():
		return
	var building := _place_at(r.body.global_position)
	if building and not districts.owns(building):
		canvasser_set_down.emit(r, building)


## How many people live in `building`.
func residents_in(building: Node3D) -> int:
	return (_by_home.get(building, []) as Array).size()


## The resident whose body stands nearest `p` on the ground, within `radius`; null if none.
func resident_near(p: Vector3, radius: float) -> Resident:
	return _street.resident_near(p, radius)


## The rep who manages `building`, or null.
func manager_of(building: Node3D) -> Resident:
	for r: Resident in staffing.members(building):
		if r.job == Resident.Job.MANAGER:
			return r
	return null


## Take `r` off the street (a Manager goes indoors): their body goes to someone else.
func put_away(r: Resident) -> void:
	if _has_body(r):
		_street.put_away(r)


## Set `r`'s rank (trained, lost) and announce it.
func convert_to(r: Resident, rank: Resident.Rank) -> void:
	var old := r.rank
	if old == rank:
		return
	r.rank = rank
	r.charisma = U.charisma(rank)
	if rank == Resident.Rank.RESIDENT:
		staffing.unassign(r)
	_count_ranks()
	rank_changed.emit(r, old, rank)


## Someone to become the next Rep or Fixer: a person living in a building of yours with
## nothing to do, nearest to `p`; when there is nobody, a new household moves into the
## main Office. (The follower they stand for was already taken out of the pool.)
func recruit(p: Vector3) -> Resident:
	var best: Resident = null
	var best_d := INF
	for r in residents:
		if not r.alive or r.job != Resident.Job.FREE or r.rank > Resident.Rank.BELIEVER \
				or not districts.owns(r.home):
			continue
		var d := _where(r).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = r
	if best == null:
		var office := districts.start_building()
		var before := residents.size()
		_census.add_household(office)
		residents = _census.residents
		best = residents[before]
	return best


func _where(r: Resident) -> Vector3:
	return r.body.global_position if _has_body(r) else r.home.global_position


## The game starts here: one of the main Office's residents is the Secretary.
func found_cult() -> void:
	var start := districts.start_building()
	if start == null:
		return
	var people: Array = _by_home.get(start, [])
	if people.is_empty():
		return
	priest = people[0]
	priest.color = U.color(Resident.Rank.HIGH_PRIEST)
	convert_to(priest, Resident.Rank.HIGH_PRIEST)
	staffing.post(priest, Resident.Job.PRIEST, start)
	cult_founded.emit(start)


func street_bodies() -> Array[Citizen]:
	return _street.bodies


func has_body(r: Resident) -> bool:
	return _has_body(r)


## `r` comes out onto the street (if indoors) and heads for their post or home.
func bring_out(r: Resident) -> void:
	if r.body == null:
		_street.bring_out(r)
	if _has_body(r):
		r.body.move_out()


## A body walking the city; bodies leave the tree before the buildings when the game quits.
func _has_body(r: Resident) -> bool:
	return is_instance_valid(r.body) and r.body.is_inside_tree()


func _set_home(r: Resident, building: Node3D) -> void:
	if r.home:
		(_by_home[r.home] as Array).erase(r)
	r.home = building
	if not _by_home.has(building):
		_by_home[building] = []
	(_by_home[building] as Array).append(r)


## The building `p` stands on, or the nearest one within occupy_reach of its walls (null if none).
func _place_at(p: Vector3) -> Node3D:
	var at := Vector2(p.x, p.z)
	var best: Node3D = null
	var best_d := _people.occupy_reach
	for b: Node3D in _footprints:
		var rect: Rect2 = _footprints[b]
		var d := at.distance_to(at.clamp(rect.position, rect.end))
		if d <= best_d:
			best_d = d
			best = b
	return best


func _footprint(building: Node3D) -> Rect2:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size := (child.shape as BoxShape3D).size
			var c := building.global_position
			return Rect2(c.x - size.x / 2.0, c.z - size.z / 2.0, size.x, size.z)
	return Rect2()


func _count_ranks() -> void:
	missionary_count = 0
	free_rep_count = 0
	reps_out = 0
	agent_count = 0
	for r in residents:
		if r.rank == Resident.Rank.MISSIONARY:
			missionary_count += 1
			if r.job == Resident.Job.FREE:
				free_rep_count += 1
			if r.job != Resident.Job.MANAGER:
				reps_out += 1
		elif r.rank == Resident.Rank.AGENT and r.alive:
			agent_count += 1
		elif r.job == Resident.Job.TRAIN and r.training_for == Resident.Rank.MISSIONARY:
			reps_out += 1
