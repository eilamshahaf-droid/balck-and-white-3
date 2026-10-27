class_name Street
extends Node
## The residents who are out on the street: one body for about every
## residents_per_body residents, and at least one from every lived-in home.
## Out of the god's view, a skeptic now and then goes home and a housemate
## comes out in the same body, so everyone gets their turn outside and each
## building keeps its people on its corner. Believers stay out.

## A body the hand let go of is back on its feet.
signal set_down(c: Citizen)
## A body stopped sitting in on a building.
signal stopped_occupying(c: Citizen)

const B: Balance = preload("res://data/balance.tres")

var bodies: Array[Citizen] = []

# Loaded at run time: a parse-time preload would load social_group.gd before
# its class_name is registered and break the typed groups array.
var _people: PeopleSettings = load("res://data/people.tres")
var _city: Node3D
var _by_home: Dictionary = {}   # building -> Array[Resident], shared with Population
var _swap_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _physics_process(delta: float) -> void:
	_swap_timer -= delta
	if _swap_timer > 0.0:
		return
	_swap_timer = _people.swap_interval
	_swap_someone()


## Put the first bodies on the street: one from every lived-in home, then a
## random sample up to the ratio.
func fill(city: Node3D, by_home: Dictionary, residents: Array[Resident]) -> void:
	_city = city
	_by_home = by_home
	for home: Node3D in _by_home:
		var people: Array = _by_home[home]
		if not people.is_empty():
			_spawn(people[_rng.randi() % people.size()])
	var wanted := ceili(float(residents.size()) / _people.residents_per_body)
	var order := residents.duplicate()
	order.shuffle()
	for r: Resident in order:
		if bodies.size() >= wanted:
			break
		if r.body == null:
			_spawn(r)


## Bring `r` out onto the street now, in a skeptic's body: a housemate's if
## one is out, else anyone's.
func bring_out(r: Resident) -> void:
	for c in bodies:
		if c.resident.home == r.home and c.can_answer() and c.belief <= B.believer_threshold:
			_give_body(r, c)
			return
	for _attempt in 32:
		var c := bodies[_rng.randi() % bodies.size()]
		if c.can_answer() and c.belief <= B.believer_threshold:
			_give_body(r, c)
			return


## The resident whose body stands nearest `p` on the ground, within `radius`; null if none.
func resident_near(p: Vector3, radius: float) -> Resident:
	var best: Resident = null
	var best_d := radius
	for c in bodies:
		var d := Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length()
		if d < best_d:
			best_d = d
			best = c.resident
	return best


## Zealots on the street within `radius` of `p`: the ones who might overdo it.
func zealots_near(p: Vector3, radius: float) -> Array[Citizen]:
	var out: Array[Citizen] = []
	for c in bodies:
		if c.resident.stage() == Resident.Stage.ZEALOT and c.global_position.distance_to(p) < radius:
			out.append(c)
	return out


func _spawn(r: Resident) -> void:
	var c := Citizen.new()
	c.city = _city
	c.resident = r
	c.collision_layer = _city.LAYER_CITIZENS
	c.collision_mask = _city.LAYER_WORLD
	r.body = c
	bodies.append(c)
	_city.add_child(c)
	c.set_down.connect(func() -> void: set_down.emit(c))
	c.stopped_occupying.connect(func() -> void: stopped_occupying.emit(c))
	c.tree_exiting.connect(func() -> void: bodies.erase(c), CONNECT_ONE_SHOT)


func _swap_someone() -> void:
	if bodies.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	for _attempt in 8:
		var c := bodies[_rng.randi() % bodies.size()]
		if not c.can_answer() or c.belief > B.believer_threshold or _seen_by(camera, c.global_position):
			continue
		var home := c.resident.home
		if _seen_by(camera, _city.intersection(_city.nearest_grid(home.global_position))):
			continue
		var r := _indoors_at(home)
		if r:
			_give_body(r, c)
			return


## A random resident of `home` who is indoors, or null.
func _indoors_at(home: Node3D) -> Resident:
	var people: Array = _by_home.get(home, [])
	if people.is_empty():
		return null
	var start := _rng.randi() % people.size()
	for k in people.size():
		var r: Resident = people[(start + k) % people.size()]
		if r.body == null:
			return r
	return null


func _give_body(r: Resident, c: Citizen) -> void:
	c.resident.body = null
	r.body = c
	c.become(r)


func _seen_by(camera: Camera3D, p: Vector3) -> bool:
	return camera != null and camera.is_position_in_frustum(p)
