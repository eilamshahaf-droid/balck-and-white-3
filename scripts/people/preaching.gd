class_name Preaching
extends Node
## How the cult wins people over (GDD 6.2): missionaries and the high priest
## each try once every attempt_interval seconds on a non-believer on the street
## near them, and sermons and the sky-sign campaigns call attempt too. A child
## Population makes; it asks Population who is who and converts through it.

## A preacher tried to win someone over (`converted` if it worked).
signal preached(preacher: Resident, target: Resident, converted: bool)

const U: UnitSettings = preload("res://data/units.tres")

var _population: Population
var _timers: Dictionary = {}   # preacher -> seconds until their next attempt
var _check_timer := 0.0
var _rng := RandomNumberGenerator.new()
# Loaded at run time: a parse-time preload would load the element scripts before
# their class_name is registered and break the typed arrays.
var _people: PeopleSettings = load("res://data/people.tres")


func setup(population: Population) -> void:
	_population = population
	_rng.seed = 5


## Gathering the preachers allocates, so it runs every preach_check seconds.
## Plain believers try too, at a small share of a preacher's rate, by chance.
func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = _people.preach_check
	for r in preachers():
		if _population.sermons.is_preaching(r):
			continue
		var left: float = _timers.get(r, U.attempt_interval * _rng.randf()) - _people.preach_check
		if left <= 0.0 and attempt_near(r, r.body.global_position):
			left = U.attempt_interval
		_timers[r] = left
	var odds := _people.preach_check * U.believer_attempt_share / U.attempt_interval
	for c in _population.street_bodies():
		var r := c.resident
		if r.rank == Resident.Rank.BELIEVER and _rng.randf() < odds:
			attempt_near(r, c.global_position)


## Everyone who wins people over on the street (missionaries and the high
## priest, not while training) and has a body; they give sermons too.
func preachers() -> Array[Resident]:
	var out: Array[Resident] = []
	for c in _population.street_bodies():
		if c.resident.preaches() and c.resident.job != Resident.Job.TRAIN:
			out.append(c.resident)
	return out


## The chance that `preacher` wins `target` over in one attempt at `p`:
## base x curiosity x (1 - skepticism) x (1 - anxiety_weight x anxiety)
## x (1 + charisma_weight x charisma), times the preacher's sermon house upgrades
## and 1 + the miracle proof at `p`, divided by core_difficulty for someone who lives in
## a district's core building. Miracles never convert on their own.
func chance(target: Resident, preacher: Resident, p: Vector3) -> float:
	var c := U.conversion_base * target.curiosity * (1.0 - target.skepticism) \
			* (1.0 - U.anxiety_weight * target.anxiety) \
			* (1.0 + U.charisma_weight * preacher.charisma) * boost(preacher)
	if _population.districts.is_core(target.home):
		c /= U.core_difficulty
	return clampf(c * maxf(1.0 + _population.miracles.proof_at(p), 0.0), 0.0, 1.0)


## `preacher` tries once to win `target` over. Nobody converts while every home
## is full. True if `target` became a believer.
func attempt(target: Resident, preacher: Resident) -> bool:
	if target.is_believer() or not target.alive \
			or _population.believer_count >= _population.housing_capacity:
		return false
	var at := preacher.body.global_position if _population.has_body(preacher) \
			else target.home.global_position
	var won := _rng.randf() < chance(target, preacher, at)
	if won:
		_population.convert_to(target, Resident.Rank.BELIEVER)
	preached.emit(preacher, target, won)
	return won


## One attempt by `preacher` on a non-believer on the street within its reach of `p`
## (a random one, so a crowd is worked through) who lives in an open district.
## False if nobody was in reach.
func attempt_near(preacher: Resident, p: Vector3) -> bool:
	var range_ := reach(preacher)
	var picked: Resident = null
	var seen := 0
	for c in _population.street_bodies():
		var r := c.resident
		if r.is_believer() or r.id < 0 or c.global_position.distance_to(p) > range_ \
				or not _population.districts.is_open(r.home):
			continue
		seen += 1
		if _rng.randi() % seen == 0:
			picked = r
	if picked == null:
		return false
	attempt(picked, preacher)
	return true


## How far a preacher reaches on the street: the loudspeakers of their sermon
## house (the high priest's for a missionary on the street) widen it.
func reach(preacher: Resident) -> float:
	var house := _house_of(preacher)
	var out := U.preach_reach
	if house:
		out *= 1.0 + _people.loudspeaker_reach \
				* _population.upgrades.count_of(house, BuildingUpgrades.Kind.LOUDSPEAKER)
	return out


## How much a preacher's sermon house upgrades raise their chance (1 = none):
## lecture halls and banners.
func boost(preacher: Resident) -> float:
	var house := _house_of(preacher)
	if house == null:
		return 1.0
	var u := _population.upgrades
	return 1.0 + _people.lecture_hall_strength * u.count_of(house, BuildingUpgrades.Kind.LECTURE_HALL) \
			+ _people.banner_strength * u.count_of(house, BuildingUpgrades.Kind.BANNERS)


## The sermon house whose upgrades help `preacher`: their own post, or the high priest's.
func _house_of(preacher: Resident) -> Node3D:
	if preacher.post:
		return preacher.post
	var priest := _population.priest
	return priest.post if priest else null
