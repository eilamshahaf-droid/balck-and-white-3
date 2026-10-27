extends Node
## Belief, witnesses and exposure for the whole city.
##
## Miracles report what people could see (a cloud raining from a clear sky).
## A few times a second, everyone with a clear view of it reacts once per
## event, through the belief formula in balance.gd. People with phones film
## it, and every video raises exposure: how convinced the world is that you
## exist. Lifting and throwing with the hand are not reported: belief comes
## only from miracles.

const B = preload("res://data/balance.tres")
const LAYER_WORLD := 1

@export var population: Population

## 0..1, shown to the player.
var exposure := 0.0
var believers := 0
## The belief pool: believers' prayers fill it, miracles spend it.
var belief_pool := B.belief_start

var _events := {}        # subject -> {kind, intensity, situation, time_left, id}
var _next_id := 0
var _timer := 0.0
var _prayer := 0.0       # belief per second, from everyone praying right now


## Something visible is happening to `subject`. Call it again to keep the
## event alive; a new kind starts a new event that everyone may react to again,
## unless `replace` is false (then whatever is already going on carries on).
## deniability: how easy it is to explain without a god (0..1).
## helped: the people this miracle actually helped (they read it most kindly).
## radius: how far away it can be seen (a cloud over a roof carries further than a lifted cab).
func report(subject: Node3D, kind: StringName, intensity: float, situation: float, duration := 0.5,
		replace := true, deniability := 0.15, helped: Array = [], radius := -1.0) -> void:
	var e: Dictionary = _events.get(subject, {})
	if e.is_empty() or (replace and e.kind != kind):
		_next_id += 1
		e = {"kind": kind, "intensity": intensity, "situation": situation, "id": _next_id,
				"deniability": deniability, "helped": helped,
				"radius": radius if radius > 0.0 else B.witness_radius}
		_events[subject] = e
	e.time_left = maxf(e.get("time_left", 0.0), duration)


func end_report(subject: Node3D) -> void:
	_events.erase(subject)


## Take belief from the pool. Returns false (and takes nothing) if there isn't enough.
func spend(amount: float) -> bool:
	if amount > belief_pool:
		return false
	belief_pool -= amount
	return true


func _physics_process(delta: float) -> void:
	exposure = maxf(exposure - B.exposure_decay * delta, 0.0)
	belief_pool += _prayer * delta
	for subject in _events.keys():
		_events[subject].time_left -= delta
		if not is_instance_valid(subject) or _events[subject].time_left <= 0.0:
			_events.erase(subject)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = B.witness_interval
	var people := get_tree().get_nodes_in_group("citizens")
	# Everyone counts and prays, indoors too; only those outside see miracles.
	believers = population.believer_count
	_prayer = population.prayer
	for subject in _events:
		_witness(subject, _events[subject], people)


func _witness(subject: Node3D, e: Dictionary, people: Array) -> void:
	var at: Vector3 = subject.aim_point() if subject.has_method("aim_point") else subject.global_position
	var space := get_viewport().world_3d.direct_space_state
	for c in people:
		if c == subject or c.has_seen_event(e.id):
			continue
		var eye: Vector3 = c.global_position + Vector3.UP * 1.6
		if eye.distance_to(at) > e.radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, at, LAYER_WORLD)
		var see_through = subject.get("see_through")
		if see_through:
			query.exclude = see_through
		if space.intersect_ray(query):
			continue  # a building is in the way
		var filmed: bool = c.witness(e, at, c.resident.friends_belief)
		if filmed:
			exposure = minf(exposure + B.exposure_per_video * e.intensity, 1.0)
