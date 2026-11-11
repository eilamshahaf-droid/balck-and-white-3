class_name Staffing
extends RefCounted
## Who works where: believers posted to pray in a sermon house or work in a
## shop, priests serving in a sermon house, and believers training there to
## become missionaries and priests. Population owns one; it also works out what
## a building's staff put out.

const U: UnitSettings = preload("res://data/units.tres")

var _population: Population
var _people: PeopleSettings
var _staff: Dictionary = {}   # building -> Array[Resident] with a post there


func _init(population: Population) -> void:
	_population = population
	# Loaded at run time: a parse-time preload would load the element scripts
	# before their class_name is registered and break the typed arrays.
	_people = load("res://data/people.tres")


## Give the free believer `r` a post: PRAY in a sermon house, PRIEST there for
## a priest, SHOP in a shop. False if `r` doesn't believe, the building doesn't
## take that job or has no free place. A new post replaces the old one.
func assign(r: Resident, job: Resident.Job, building: Node3D) -> bool:
	if job == Resident.Job.FREE or job == Resident.Job.TRAIN or not r.is_believer() \
			or building == null or (job == Resident.Job.PRIEST and not r.is_priest()):
		return false
	var group := Population.SHOPS if job == Resident.Job.SHOP else Population.PRAYER_HOUSES
	var is_seminary := job == Resident.Job.PRIEST \
			and _upgrades().count_of(building, BuildingUpgrades.Kind.SEMINARY) > 0
	if not (building.is_in_group(group) or is_seminary) or staff_count(building) >= capacity(building):
		return false
	if job == Resident.Job.PRIEST and staff_count(building, job) >= _priest_slots_of(building):
		return false
	post(r, job, building)
	return true


## Put `r` on `job` in `building` with no checks (the cult's founding, training).
func post(r: Resident, job: Resident.Job, building: Node3D) -> void:
	unassign(r)
	r.job = job
	r.post = building
	if not _staff.has(building):
		_staff[building] = []
	(_staff[building] as Array).append(r)
	_population.bring_out(r)


## `r` goes back to being a free believer.
func unassign(r: Resident) -> void:
	if r.job == Resident.Job.FREE:
		return
	var staff: Array = _staff.get(r.post, [])
	staff.erase(r)
	r.job = Resident.Job.FREE
	r.post = null
	r.training_left = 0.0
	if _population.has_body(r):
		r.body.move_out()


## Start training `r` (free, or praying in `building`) in `building`: a believer into a
## missionary, a missionary into a priest (only where the high priest serves, up to
## max_priests), a believer into a special agent (at a core you hold, up to max_agents).
## False if `r` can't train for `rank` there.
func train(r: Resident, rank: Resident.Rank, building: Node3D) -> bool:
	var praying_here := r.job == Resident.Job.PRAY and r.post == building
	if not can_train(rank, building) or r.rank != trainee_rank(rank) \
			or not (r.job == Resident.Job.FREE or praying_here):
		return false
	post(r, Resident.Job.TRAIN, building)
	r.training_for = rank
	match rank:
		Resident.Rank.MISSIONARY: r.training_left = U.missionary_time
		Resident.Rank.AGENT: r.training_left = U.agent_time
		_: r.training_left = U.priest_time
	return true


## The rank someone trains from to become `rank`.
static func trainee_rank(rank: Resident.Rank) -> Resident.Rank:
	if rank == Resident.Rank.AGENT:
		return Resident.Rank.BELIEVER
	return (rank - 1) as Resident.Rank


## Can `building` train someone for `rank` right now?
func can_train(rank: Resident.Rank, building: Node3D) -> bool:
	if building == null:
		return false
	if rank == Resident.Rank.AGENT:
		return _population.districts.is_base(building) \
				and _population.believer_count >= U.agent_unlock_believers \
				and _population.agent_count + _training_for(Resident.Rank.AGENT) < U.max_agents
	if not building.is_in_group(Population.PRAYER_HOUSES):
		return false
	if staff_count(building) >= capacity(building):
		return false
	match rank:
		Resident.Rank.MISSIONARY:
			return true
		Resident.Rank.PRIEST:
			var priest := _population.priest
			return priest != null and building == priest.post \
					and _population.priest_count + staff_count(building, Resident.Job.TRAIN) \
					< U.max_priests
	return false


## Count down `r`'s training by `dt`; when it is done they take the new rank, and a
## new priest serves where they trained.
func tick_training(r: Resident, dt: float) -> void:
	if r.job != Resident.Job.TRAIN:
		return
	r.training_left -= dt
	if r.training_left > 0.0:
		return
	var house := r.post
	unassign(r)
	_population.convert_to(r, r.training_for)
	if r.is_priest():
		assign(r, Resident.Job.PRIEST, house)


## How many people `building` can staff: by its size (a sermon house has room
## for at least sermon_house_places), plus a few per upgrade or floor bought.
func capacity(building: Node3D) -> int:
	var least := _people.sermon_house_places \
			if building.is_in_group(Population.PRAYER_HOUSES) else 1
	return maxi(least, floori(_volume_of(building) / _people.staff_volume)) \
			+ _upgrades().extra_places(building)


## How many people work in `building` (only those with `job`, unless FREE).
func staff_count(building: Node3D, job := Resident.Job.FREE) -> int:
	var n := 0
	for r: Resident in _staff.get(building, []):
		if job == Resident.Job.FREE or r.job == job:
			n += 1
	return n


## Who could start training for `rank` in `building`: free people of the rank
## below within `radius` of it, and those praying there.
func trainees_for(rank: Resident.Rank, building: Node3D, radius: float) -> Array[Resident]:
	var from := trainee_rank(rank)
	var out := _population.free_believers_near(building.global_position, radius, from)
	for r: Resident in members(building):
		if r.job == Resident.Job.PRAY and r.rank == from:
			out.append(r)
	return out


## Everyone with a post in `building`.
func members(building: Node3D) -> Array:
	return _staff.get(building, [])


## A sermon house makes belief once a priest (or the high priest) serves there.
func is_staffed(building: Node3D) -> bool:
	return staff_count(building, Resident.Job.PRIEST) > 0


## What `building`'s staff put out: each person counts by their needs. No
## staff, no output; nothing while a roadblock stands.
func staffed(building: Node3D) -> float:
	if _population.is_blockaded(building):
		return 0.0
	return _raw(building) * (1.0 + _people.storefront_output
			* _upgrades().count_of(building, BuildingUpgrades.Kind.STOREFRONT))


## Holy warriors a gym trains: its staff output per gym (0 without one); Campaigns uses them.
func fighters_of(building: Node3D) -> float:
	return _raw(building) * _people.gym_fighters \
			* _upgrades().count_of(building, BuildingUpgrades.Kind.GYM)


## What buying a flat costs, as a share of the normal price, for a building with
## real estate offices (1 = no discount).
func buy_price_factor(building: Node3D) -> float:
	var discount := _people.real_estate_discount \
			* _upgrades().count_of(building, BuildingUpgrades.Kind.REAL_ESTATE)
	return maxf(1.0 - discount, _people.buy_discount_floor)


## `building` left the city: its staff lose their posts.
func forget(building: Node3D) -> void:
	for r: Resident in members(building).duplicate():
		unassign(r)
	_staff.erase(building)


func _training_for(rank: Resident.Rank) -> int:
	var n := 0
	for building: Node3D in _staff:
		for r: Resident in _staff[building]:
			if r.job == Resident.Job.TRAIN and r.training_for == rank:
				n += 1
	return n


func _raw(building: Node3D) -> float:
	var total := 0.0
	for r: Resident in members(building):
		total += _population.needs_multiplier(r)
	return total


func _priest_slots_of(building: Node3D) -> int:
	return _people.priest_slots + _upgrades().extra_places(building)


func _upgrades() -> BuildingUpgrades:
	return _population.upgrades


## Footprint times height of the building's collision box, in cubic metres.
func _volume_of(building: Node3D) -> float:
	var size := BuildingBox.size_of(building)
	return size.x * size.y * size.z
