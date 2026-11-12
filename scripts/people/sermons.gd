class_name Sermons
extends Node
## A preacher (a missionary or the high priest) now and then stops and
## preaches: they stand still, a crowd gathers around them, and while it lasts
## they try to win someone over more often the bigger the crowd. Each sermon has a hidden chance that the police step in, higher on a
## street where few people believe. A raid breaks the sermon up at once (nobody is
## arrested), and the same preacher is left alone for raid_cooldown. The player sees
## the sermon and the raid through the signals.
##
## Only preachers start sermons, and not while the homes are full: there is
## nobody to convert without a home for them. (The `priest` names below mean
## whoever preaches.)

## `priest` began a sermon at `at`, with `risk` the hidden police chance (0..1).
signal sermon_started(priest: Resident, at: Vector3, risk: float)
## The sermon of `priest` is over (it ran out, or the raid was dealt with).
signal sermon_ended(priest: Resident)
## The police broke up the sermon of `priest` at `at`.
signal police_moved_in(priest: Resident, at: Vector3)

class Sermon extends RefCounted:
	var priest: Resident
	var at := Vector3.ZERO
	var time_left := 0.0
	var preach_timer := 0.0
	var crowd := 0

const U: UnitSettings = preload("res://data/units.tres")
const CHECK_INTERVAL := 1.0

var _population: Population
var _active: Array[Sermon] = []
var _rest: Dictionary = {}   # priest -> seconds until their next sermon
var _raided: Dictionary = {}   # priest -> seconds before the police bother them again
var _check_timer := 0.0
var _rng := RandomNumberGenerator.new()
# Loaded at run time: a parse-time preload would load the element scripts before
# their class_name is registered and break the typed arrays.
var _people: PeopleSettings = load("res://data/people.tres")


func setup(population: Population) -> void:
	_population = population
	_rng.seed = 11


func _physics_process(delta: float) -> void:
	for s in _active.duplicate():
		_tick(s, delta)
	# Looking for priests who are due allocates, so it runs about once a second.
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	for priest: Resident in _raided.keys():
		_raided[priest] -= CHECK_INTERVAL
		if _raided[priest] <= 0.0:
			_raided.erase(priest)
	for priest in _population.preaching.preachers():
		if _sermon_of(priest) == null and _population.has_body(priest):
			_rest[priest] = _rest.get(priest, _people.sermon_interval) - CHECK_INTERVAL
			if _rest[priest] <= 0.0:
				_rest[priest] = _people.sermon_interval
				_begin(priest)


## Is `priest` in a sermon right now (so walking preaching leaves him alone)?
func is_preaching(priest: Resident) -> bool:
	return _sermon_of(priest) != null


## The police are done at `priest`'s sermon (cleared away, or dealt with by a miracle).
func end_sermon(priest: Resident) -> void:
	var s := _sermon_of(priest)
	if s:
		_finish(s)


## The hidden chance that the police step in on a sermon at `p`: highest on a
## street where nobody believes, lowest where everyone does.
func risk_at(p: Vector3) -> float:
	var believers := 0
	var all := 0
	for c in _population.street_bodies():
		if c.global_position.distance_to(p) < _people.safety_radius:
			all += 1
			if c.resident.is_believer():
				believers += 1
	var safety := float(believers) / all if all > 0 else 0.0
	return lerpf(_people.raid_chance_unsafe, _people.raid_chance_safe, safety)


func _begin(priest: Resident) -> void:
	var s := Sermon.new()
	s.priest = priest
	s.at = priest.body.global_position
	s.time_left = _people.sermon_time
	_active.append(s)
	# He stands where he is for the whole sermon.
	priest.body.send_on_errand(s.at, s.at, _people.sermon_time, "",
			U.color(priest.rank))
	_gather_crowd(s)
	var risk := 0.0 if _raided.has(priest) else risk_at(s.at)
	sermon_started.emit(priest, s.at, risk)
	if _rng.randf() < risk:
		_raided[priest] = _people.raid_cooldown
		police_moved_in.emit(priest, s.at)
		_finish(s)


func _gather_crowd(s: Sermon) -> void:
	var angle := 0.0
	var step := TAU / maxi(_people.crowd_size, 1)
	for c in _population.street_bodies():
		if s.crowd >= _people.crowd_size:
			break
		if c.resident == s.priest or not c.can_answer() \
				or c.global_position.distance_to(s.at) > _people.crowd_reach:
			continue
		var spot := s.at + Vector3(cos(angle), 0.0, sin(angle)) * _people.crowd_radius
		c.send_on_errand(spot, s.at, _people.sermon_time, _people.sermon_line,
				_people.crowd_line_color)
		angle += step
		s.crowd += 1


func _tick(s: Sermon, delta: float) -> void:
	s.time_left -= delta
	if s.time_left <= 0.0 or not _population.has_body(s.priest):
		_finish(s)
		return
	s.preach_timer -= delta
	if s.preach_timer <= 0.0:
		var crowd_boost := 1.0 + _people.crowd_boost * float(s.crowd) / maxi(_people.crowd_size, 1)
		s.preach_timer = U.attempt_interval / crowd_boost
		_population.preaching.attempt_near(s.priest, s.at)


func _finish(s: Sermon) -> void:
	_active.erase(s)
	if _population.has_body(s.priest):
		s.priest.body.end_errand()
	sermon_ended.emit(s.priest)


func _sermon_of(priest: Resident) -> Sermon:
	for s in _active:
		if s.priest == priest:
			return s
	return null
