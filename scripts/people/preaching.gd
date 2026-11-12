class_name Preaching
extends Node
## How people are won over: at a door the player chose (the sky-sign campaigns call
## `attempt`), and by themselves next to a building of yours in the same block
## (`drift_chance`). Nobody is converted on the street. A child Population makes; it
## asks Population who is who and converts through it.

## A preacher tried to win someone over (`converted` if it worked).
signal preached(preacher: Resident, target: Resident, converted: bool)

const U: UnitSettings = preload("res://data/units.tres")

var _population: Population
var _check_timer := 0.0
var _rng := RandomNumberGenerator.new()
# Loaded at run time: a parse-time preload would load the element scripts before
# their class_name is registered and break the typed arrays.
var _people: PeopleSettings = load("res://data/people.tres")


func setup(population: Population) -> void:
	_population = population
	_rng.seed = 5


## Nobody is won over on the street. A building of yours wins over its neighbours in
## its own block, slowly, the more inviting it is (and the Office hardest of all); the
## rest is canvassers at a door the player chose (Campaigns).
func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = U.spread_tick
	var districts := _population.districts
	for i in districts.buildings.size():
		var b := districts.buildings[i]
		if b == null or not districts.is_yours(i):
			continue
		var tries := U.spread_per_minute * U.spread_tick / 60.0 \
				* lerpf(U.spread_low, U.spread_high, _population.inviting(b))
		if districts.is_base(b):
			tries *= U.office_spread
		for j in districts.borders_of(i):
			if districts.buildings[j] == null or districts.is_yours(j) \
					or districts.block_of(j) != districts.block_of(i) \
					or _rng.randf() >= tries:
				continue
			var target := _population.doubter_in(districts.buildings[j])
			if target and _rng.randf() < drift_chance(target):
				_population.convert_to(target, Resident.Rank.BELIEVER)


## Everyone who talks people round (canvassers and the Secretary, not while training)
## and has a body; they hold the street meetings.
func preachers() -> Array[Resident]:
	var out: Array[Resident] = []
	for c in _population.street_bodies():
		if c.resident.preaches() and c.resident.job != Resident.Job.TRAIN:
			out.append(c.resident)
	return out


## The chance that `preacher` wins `target` over in one attempt at `p`:
## base x curiosity x (1 - skepticism) x (1 - anxiety_weight x anxiety)
## x (1 + charisma_weight x charisma), times how willing the preacher is (an unwilling one
## the hand ordered about does worse), times the preacher's sermon house upgrades
## and 1 + the miracle proof at `p`, divided by core_difficulty for someone who lives in
## a district's core building, and times the district's awareness and any martyr near
## their home (Awareness.factor_for). Miracles never convert on their own.
func chance(target: Resident, preacher: Resident, p: Vector3) -> float:
	var c := U.conversion_base * target.curiosity * (1.0 - target.skepticism) \
			* (1.0 - U.anxiety_weight * target.anxiety) \
			* (1.0 + U.charisma_weight * preacher.charisma) * boost(preacher) \
			* _population.effort_of(preacher)
	if _population.districts.is_core(target.home):
		c /= U.core_difficulty
	if _population.awareness:
		c *= _population.awareness.factor_for(target.home)
	return clampf(c * maxf(1.0 + _population.miracles.proof_at(p), 0.0), 0.0, 1.0)


## `preacher` tries once to win `target` over. True if `target` became a believer.
func attempt(target: Resident, preacher: Resident) -> bool:
	if target.is_believer() or not target.alive:
		return false
	var at := preacher.body.global_position if _population.has_body(preacher) \
			else target.home.global_position
	var won := _rng.randf() < chance(target, preacher, at)
	if won:
		_population.convert_to(target, Resident.Rank.BELIEVER)
	preached.emit(preacher, target, won)
	return won


## The chance that `target` comes over by themselves in one round of a neighbour's
## influence: the same person, district and core as in `chance`, with nobody talking.
func drift_chance(target: Resident) -> float:
	var c := U.conversion_base * target.curiosity * (1.0 - target.skepticism) \
			* (1.0 - U.anxiety_weight * target.anxiety)
	if _population.districts.is_core(target.home):
		c /= U.core_difficulty
	if _population.awareness:
		c *= _population.awareness.factor_for(target.home)
	return clampf(c, 0.0, 1.0)


## How far a street meeting reaches: the loudspeakers of the holder's branch (the
## Secretary's for a canvasser on the street) widen it.
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
