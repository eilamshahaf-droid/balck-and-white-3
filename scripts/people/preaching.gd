class_name Preaching
extends Node
## How buildings are won over: a rep at the door fills the building's takeover meter at
## `pace` (Campaigns does the sending), and buildings of yours pull up their neighbours'
## meters inside a block. Nobody is converted on the street. A child Population makes;
## it asks Population who is who.

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


## Nobody is won over on the street. Every building has a takeover meter (Districts):
## a building of yours pulls up the meters of its neighbours in its own block, slowly,
## the more inviting it is (the Office hardest of all), until they want you and only need
## a rep to manage them. A meter nothing holds up sinks back, slowly.
func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = U.spread_tick
	var districts := _population.districts
	var minutes := U.spread_tick / 60.0
	for j in districts.buildings.size():
		var target := districts.buildings[j]
		if target == null or districts.is_yours(j):
			continue
		var pull := 0.0
		for i in districts.borders_of(j):
			var b := districts.buildings[i]
			if b == null or not districts.is_yours(i) \
					or districts.block_of(i) != districts.block_of(j):
				continue
			var one := U.spread_per_minute \
					* lerpf(U.spread_low, U.spread_high, _population.inviting(b))
			pull += one * U.office_spread if districts.is_base(b) else one
		if pull > 0.0:
			districts.add_meter(j, pull * minutes * receptive(target))
		elif districts.meter_of(j) > 0.0:
			districts.add_meter(j, -U.meter_sink_per_minute * minutes)


## Everyone who talks people round (canvassers and the Secretary, not while training)
## and has a body; they hold the street meetings.
func preachers() -> Array[Resident]:
	var out: Array[Resident] = []
	for c in _population.street_bodies():
		if c.resident.preaches() and c.resident.job != Resident.Job.TRAIN:
			out.append(c.resident)
	return out


## How readily the people of `building` come over, against an ordinary Slums household
## (1): the average of what each resident's own character makes of an approach, less for
## a core building and for an aware district (`drift_chance`).
func receptive(building: Node3D) -> float:
	var sum := 0.0
	var n := 0
	for r: Resident in _population.occupants_at_home(building):
		sum += drift_chance(r)
		n += 1
	return sum / n / U.ordinary_chance if n > 0 else 1.0


## How fast `preacher` fills `building`'s meter at its door, as a share of the plain rate:
## the residents' readiness, the preacher's charisma and willingness, and their branch's
## upgrades and any miracle proof on the spot.
func pace(building: Node3D, preacher: Resident) -> float:
	var at := preacher.body.global_position if _population.has_body(preacher) \
			else building.global_position
	return receptive(building) * (1.0 + U.charisma_weight * preacher.charisma) \
			* boost(preacher) * _population.effort_of(preacher) \
			* maxf(1.0 + _population.miracles.proof_at(at), 0.0)


## What `target`'s own character makes of one approach: base x curiosity x
## (1 - skepticism) x (1 - anxiety_weight x anxiety), divided by core_difficulty for
## someone who lives in a district's core building, times the district's awareness and
## any martyr near their home (Awareness.factor_for).
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
