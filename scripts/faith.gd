extends Node
## Belief, witnesses and exposure for the whole city.
##
## The hand reports what it is doing that people could see (a person lifted,
## a taxi floating, a tree torn out, someone flung through the air). A few
## times a second, everyone with a clear view of it reacts once per event,
## through the belief formula in balance.gd. People with phones film it, and
## every video raises exposure: how convinced the world is that you exist.
##
## The hand's power at a spot comes from the believers around it, as with the
## influence ring of the original games.

const B = preload("res://data/balance.tres")
const LAYER_WORLD := 1

## 0..1, shown to the player.
var exposure := 0.0
var believers := 0
## The belief pool: believers' prayers fill it, miracles and overloaded lifts spend it.
var belief_pool := B.belief_start

var _events := {}        # subject -> {kind, intensity, situation, time_left, id}
var _next_id := 0
var _timer := 0.0
var _prayer := 0.0       # belief per second, from everyone praying right now


## Something visible is happening to `subject`. Call it again to keep the
## event alive; a new kind starts a new event that everyone may react to again,
## unless `replace` is false (then whatever is already going on carries on).
func report(subject: Node3D, kind: StringName, intensity: float, situation: float, duration := 0.5, replace := true) -> void:
	var e: Dictionary = _events.get(subject, {})
	if e.is_empty() or (replace and e.kind != kind):
		_next_id += 1
		e = {"kind": kind, "intensity": intensity, "situation": situation, "id": _next_id}
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


## How much mass the hand can lift at `p`.
func strength_at(p: Vector3) -> float:
	var s: float = B.base_strength
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.belief <= B.believer_threshold:
			continue
		var d: float = c.global_position.distance_to(p)
		if d < B.influence_radius:
			s += B.strength_per_believer * c.belief * (1.0 - d / B.influence_radius)
	return minf(s, B.max_strength)


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
	believers = 0
	_prayer = 0.0
	for c in people:
		if c.belief > B.believer_threshold:
			believers += 1
			_prayer += B.prayer_rate * c.belief
	for subject in _events:
		_witness(subject, _events[subject], people)


func _witness(subject: Node3D, e: Dictionary, people: Array) -> void:
	var at: Vector3 = subject.aim_point() if subject.has_method("aim_point") else subject.global_position
	var space := get_viewport().world_3d.direct_space_state
	for c in people:
		if c == subject or c.has_seen_event(e.id):
			continue
		var eye: Vector3 = c.global_position + Vector3.UP * 1.6
		if eye.distance_to(at) > B.witness_radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, at, LAYER_WORLD)
		if space.intersect_ray(query):
			continue  # a building is in the way
		var filmed: bool = c.witness(e.id, e.kind, e.intensity, e.situation, at, _friends_belief(c, people))
		if filmed:
			exposure = minf(exposure + B.exposure_per_video * e.intensity, 1.0)


func _friends_belief(person: Node3D, people: Array) -> float:
	var total := 0.0
	var n := 0
	for c in people:
		if c != person and c.global_position.distance_to(person.global_position) < B.friends_radius:
			total += c.belief
			n += 1
	return total / n if n > 0 else 0.0
