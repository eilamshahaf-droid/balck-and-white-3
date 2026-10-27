class_name Population
extends Node
## The city's residents. Once the city is built, gives every person a name, a
## group, a home in a real building (at least a few in each), a workplace,
## family and close friends. Other systems ask Population about people (who
## lives where, who believes) instead of scanning the scene tree.
##
## Most residents are indoors at any moment: only street_people of them have a
## body walking the city. Out of the god's view, a body now and then goes in
## and someone else comes out, so everyone gets their turn on the street.
##
## Belief drifts slowly: back toward what a person believed before the cult,
## unless friends who believe or a building of believers hold it up. A change
## of stage is announced with stage_changed.
##
## It also tracks believers the hand sets down on or at a building, who sit in
## there to claim it (the power route of the claim meter, design doc: "how a
## place is taken"), and keeps each building's believing presence cached.

## A believer started sitting in on `building`.
signal occupant_added(building: Node3D, resident: Resident)
## An occupant left `building` (picked up, or went home).
signal occupant_left(building: Node3D, resident: Resident)
## `resident` moved from stage `old` to stage `new` (Resident.Stage).
signal stage_changed(resident: Resident, old: int, new: int)

# Loaded at run time: a parse-time preload would load social_group.gd before
# its class_name is registered and break the typed groups array.
var _people: PeopleSettings = load("res://data/people.tres")
const B: Balance = preload("res://data/balance.tres")

var residents: Array[Resident] = []
## Refreshed with the presence: how many residents believe, and the belief per
## second their prayers add to the pool.
var believer_count := 0
var prayer := 0.0

var _homes: Array[Node3D] = []
var _offices: Array[Node3D] = []
var _by_home: Dictionary = {}   # building -> Array[Resident]
var _occupants: Dictionary = {}   # building -> Array[Resident]
var _presence: Dictionary = {}    # building -> summed belief of its believers, refreshed on a timer
var _footprints: Dictionary = {}  # building -> Rect2 on the ground (x, z)
var _presence_timer := 0.0
var _census: Census
var _stages: Dictionary = {}       # resident -> the stage last announced
var _bodies: Array[Citizen] = []
var _indoors: Array[Resident] = []
var _swap_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var city: Node3D = get_parent()


func _ready() -> void:
	_rng.seed = 7
	add_child(Crowd.new())
	# The city builds its blocks in its own _ready, which runs after ours.
	city.ready.connect(_populate, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_swap_timer -= delta
	if _swap_timer <= 0.0:
		_swap_timer = _people.swap_interval
		_swap_someone()
	_presence_timer -= delta
	if _presence_timer > 0.0:
		return
	_presence_timer = _people.presence_refresh
	_refresh_presence()


## How strongly believers hold `building`: the summed belief of the believers
## who live there or sit in on it. Cached, so it is cheap to ask every tick.
func power_presence(building: Node3D) -> float:
	return _presence.get(building, 0.0)


func occupants(building: Node3D) -> Array:
	return _occupants.get(building, [])


## Share of the people living in `building` who believe (0 if nobody lives there).
func believer_share(building: Node3D) -> float:
	var people: Array = _by_home.get(building, [])
	if people.is_empty():
		return 0.0
	var n := 0
	for r: Resident in people:
		if r.belief > B.believer_threshold:
			n += 1
	return float(n) / people.size()


## The resident whose body stands nearest `p` on the ground, within `radius`; null if none.
func resident_near(p: Vector3, radius: float) -> Resident:
	var best: Resident = null
	var best_d := radius
	for r in residents:
		if not _has_body(r):
			continue
		var d := Vector2(r.body.global_position.x - p.x, r.body.global_position.z - p.z).length()
		if d < best_d:
			best_d = d
			best = r
	return best


## The building people can live in nearest to `p`.
func home_near(p: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for b in _homes:
		var d := b.global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = b
	return best


func move_home(r: Resident, building: Node3D) -> void:
	_set_home(r, building)
	if _has_body(r):
		r.body.settle_at_home()


## `r` moves out of their home to the nearest other one (bought out, scared off).
func evict(r: Resident) -> void:
	var old := r.home
	_homes.erase(old)
	var new_home := home_near(old.global_position)
	_homes.append(old)
	if new_home == null:
		return
	_set_home(r, new_home)
	if _has_body(r):
		r.body.move_out()


## Someone preaches to `r` (missionaries at the door): belief rises by
## `strength`, less the more skeptical the person is.
func preach_to(r: Resident, strength: float) -> void:
	persuade(r, SocialGroup.Route.PREACH, strength)


## Push `r` toward belief by `route` (a miracle, preaching, money, force):
## less for skeptics, weighted by how their group answers that route, and at
## most one stage at a time.
func persuade(r: Resident, route: SocialGroup.Route, strength: float) -> void:
	r.persuade(route, strength * (1.0 - r.skepticism))


## The god saved `building` (a fire put out): everyone who lives there, indoors
## or out, takes it as a miracle.
func awe(building: Node3D, strength: float) -> void:
	for r: Resident in _by_home.get(building, []):
		persuade(r, SocialGroup.Route.MIRACLE, strength)


func stage(r: Resident) -> Resident.Stage:
	return r.stage()


## Zealots on the street within `radius` of `p`: the ones who might overdo it.
func zealots_near(p: Vector3, radius: float) -> Array[Citizen]:
	var out: Array[Citizen] = []
	for c in _bodies:
		if c.resident.stage() == Resident.Stage.ZEALOT and c.global_position.distance_to(p) < radius:
			out.append(c)
	return out


## Everyone leaves `building` for good (roaches, fire): the people who live
## there move to the nearest other homes and those close by run out into the
## street. Nobody moves in again, so it stays empty.
func evacuate(building: Node3D) -> void:
	_homes.erase(building)
	_release_occupants(building)
	var new_home := home_near(building.global_position)
	if new_home == null:
		return  # the whole city is going away (quitting the game)
	var leaving: Array = _by_home.get(building, []).duplicate()
	for r: Resident in leaving:
		_set_home(r, new_home)
		if not _has_body(r):
			continue
		r.body.move_out()
		if r.body.global_position.distance_to(building.global_position) < _people.flee_reach:
			r.body.flee(building.global_position)
	_by_home.erase(building)


## Skip the story: the families in the homes nearest one corner become a
## small congregation of believers.
func found_congregation() -> void:
	var corner: Vector3 = city.intersection(_people.congregation_corner)
	var near := _homes.duplicate()
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(corner) < b.global_position.distance_squared_to(corner))
	var converted := 0
	for home: Node3D in near:
		for r: Resident in _by_home.get(home, []):
			if converted >= _people.congregation_size:
				return
			r.belief = _rng.randf_range(_people.congregation_belief_min, _people.congregation_belief_max)
			r.baseline = r.belief
			r.skepticism = _rng.randf_range(0.0, _people.congregation_skepticism_max)
			_stages[r] = r.stage()
			if r.body == null:
				_bring_out(r)
			converted += 1


func _populate() -> void:
	_census = Census.new(_people, _rng)
	_census.take(get_tree().get_nodes_in_group("buildings"))
	residents = _census.residents
	_by_home = _census.by_home
	_homes = _census.homes
	_offices = _census.offices
	for r in residents:
		_stages[r] = r.stage()
	# A random sample walks the streets, so they aren't all from one corner.
	var order := residents.duplicate()
	order.shuffle()
	for r: Resident in order:
		if _bodies.size() < _people.street_people:
			_spawn_body(r)
		else:
			_indoors.append(r)
	for b in _homes + _offices:
		_footprints[b] = _footprint(b)
		_presence[b] = 0.0
		b.tree_exiting.connect(_forget_building.bind(b), CONNECT_ONE_SHOT)
	_refresh_presence()


func _spawn_body(r: Resident) -> void:
	var c := Citizen.new()
	c.city = city
	c.resident = r
	c.collision_layer = city.LAYER_CITIZENS
	c.collision_mask = city.LAYER_WORLD
	r.body = c
	_bodies.append(c)
	city.add_child(c)
	c.set_down.connect(_on_set_down.bind(c))
	c.stopped_occupying.connect(_on_stopped_occupying.bind(c))
	c.tree_exiting.connect(func() -> void: _bodies.erase(c), CONNECT_ONE_SHOT)


## Out of the god's view, a skeptic walking the street goes indoors and an
## indoor resident comes out in their body. Believers stay out.
func _swap_someone() -> void:
	if _indoors.is_empty() or _bodies.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	for _attempt in 8:
		var c := _bodies[_rng.randi() % _bodies.size()]
		if not c.can_answer() or c.belief > B.believer_threshold or _seen_by(camera, c.global_position):
			continue
		var i := _rng.randi() % _indoors.size()
		var r := _indoors[i]
		if _seen_by(camera, city.intersection(city.nearest_grid(r.home.global_position))):
			continue
		_indoors[i] = c.resident
		_give_body(r, c)
		return


## Bring `r` out onto the street now, in a skeptic's body.
func _bring_out(r: Resident) -> void:
	for _attempt in 32:
		var c := _bodies[_rng.randi() % _bodies.size()]
		if c.can_answer() and c.belief <= B.believer_threshold:
			_indoors[_indoors.find(r)] = c.resident
			_give_body(r, c)
			return


func _give_body(r: Resident, c: Citizen) -> void:
	c.resident.body = null
	r.body = c
	c.become(r)


func _seen_by(camera: Camera3D, p: Vector3) -> bool:
	return camera != null and camera.is_position_in_frustum(p)


## A believer set down on a building, or right at its walls, sits in there.
func _on_set_down(c: Citizen) -> void:
	var r := c.resident
	if r.belief <= B.believer_threshold or r.occupying:
		return
	var p := r.body.global_position
	var building := _place_at(p)
	if building == null:
		return
	r.occupying = building
	if not _occupants.has(building):
		_occupants[building] = []
	(_occupants[building] as Array).append(r)
	r.body.occupy(building.global_position)
	occupant_added.emit(building, r)


func _on_stopped_occupying(c: Citizen) -> void:
	_end_occupation(c.resident)


func _end_occupation(r: Resident) -> void:
	var building := r.occupying
	if building == null:
		return
	r.occupying = null
	(_occupants[building] as Array).erase(r)
	occupant_left.emit(building, r)


## A building left the city (City Hall's bulldozer): everyone who lived,
## worked or sat in there carries on without it.
func _forget_building(building: Node3D) -> void:
	evacuate(building)
	_offices.erase(building)
	_footprints.erase(building)
	_presence.erase(building)
	_occupants.erase(building)
	if _homes.is_empty():
		return
	for r in residents:
		if r.work == building:
			r.work = _census.pick_work(r.group)


func _release_occupants(building: Node3D) -> void:
	for r: Resident in occupants(building).duplicate():
		if _has_body(r):
			r.body.leave_occupied()
		else:
			_end_occupation(r)


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


func _refresh_presence() -> void:
	for b: Node3D in _presence:
		_presence[b] = 0.0
	believer_count = 0
	prayer = 0.0
	for r in residents:
		if r.belief <= B.believer_threshold:
			continue
		believer_count += 1
		prayer += B.prayer_rate * r.belief
		_presence[r.home] += r.belief
		if r.occupying and r.occupying != r.home:
			_presence[r.occupying] += r.belief
	var dt := _people.presence_refresh
	for r in residents:
		var total := 0.0
		for id in r.friends:
			total += residents[id].belief
		r.friends_belief = total / r.friends.size() if not r.friends.is_empty() else 0.0
		_drift(r, dt)
		var now := r.stage()
		var before: int = _stages[r]
		if now != before:
			_stages[r] = now
			stage_changed.emit(r, before, now)


## Belief slides back toward what a person believed before the cult, unless
## something holds it up: sitting in for the cult, a home most of whose
## residents believe, or friends who believe as much. Friends who believe
## more slowly pull it up.
func _drift(r: Resident, dt: float) -> void:
	if r.belief < r.friends_belief:
		r.belief = minf(r.belief + B.contagion_rate * dt, r.friends_belief)
		return
	var hold := maxf(r.baseline, r.friends_belief)
	if r.belief <= hold or r.occupying or believer_share(r.home) > 0.5:
		return
	r.belief = maxf(r.belief - B.belief_decay * dt, hold)
