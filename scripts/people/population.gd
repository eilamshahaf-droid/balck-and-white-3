class_name Population
extends Node
## The city's residents. Once the city is built, gives every person a name, an
## archetype (by their district), a home in a real building (at least a few in
## each), a workplace, family and close friends. Other systems ask Population about people (who
## lives where, who believes) instead of scanning the scene tree.
##
## Most residents are indoors at any moment: about one in residents_per_body
## has a body walking the city, and every lived-in home has at least one out.
## Out of the god's view, a body now and then goes in and a housemate comes
## out, so everyone gets their turn on the street.
##
## The cult starts with one person: the high priest, in the start district's
## core building, its first sermon house (group prayer_houses). Missionaries and
## the high priest win people over one attempt at a time (preaching, a
## Preaching child); a believer makes money by their wealth and, inside a
## staffed sermon house, belief by their faith, both times their needs
## multiplier (Needs). Believers are capped by housing, and one whose livelihood
## is not met may leave. Posts and training are staffing (Staffing), purchases
## for buildings are upgrades (BuildingUpgrades). A change of rank is announced
## with rank_changed.
##
## It also tracks believers the hand sets down on or at a building, who sit in
## there to claim it (the power route of the claim meter, design doc: "how a
## place is taken"), and keeps each building's believing presence cached.

## A believer started sitting in on `building`.
signal occupant_added(building: Node3D, resident: Resident)
## An occupant left `building` (picked up, or went home).
signal occupant_left(building: Node3D, resident: Resident)
## `resident` went from rank `old` to rank `new` (Resident.Rank).
signal rank_changed(resident: Resident, old: Resident.Rank, new: Resident.Rank)
## `count` people died when `building` burned down with them inside.
signal people_died(building: Node3D, count: int)
## The cult was founded in `building`, its first sermon house.
signal cult_founded(building: Node3D)
## The player let every believer go from `building` (it can be settled again).
signal believers_dismissed(building: Node3D, count: int)
## The hand set a special agent (the Vandalist) down near `building`.
signal agent_set_down(agent: Resident, building: Node3D)

## Buildings whose use is prayer (sermon houses); whoever sets a building's use keeps this group.
const PRAYER_HOUSES := &"prayer_houses"
## Buildings that take shop staff; whoever sets a building's use keeps this group.
const SHOPS := &"shops"
const U: UnitSettings = preload("res://data/units.tres")

## Where a miracle left proof, a priest's preaching is stronger.
@export var miracles: Miracles
## Roadblocks stop people from crossing a closed street.
@export var police: Police
## Which district (and so which kind of people) each home is in, and where the cult starts.
@export var districts: Districts
## Makes converting harder where the city has noticed the cult (Preaching asks it).
@export var awareness: Awareness

var residents: Array[Resident] = []
## The cult's high priest (a Resident with a body), once the cult is founded.
var priest: Resident
## Refreshed with the presence: how many residents believe, the belief per second
## the sermon houses add to the pool, and the money per second believers bring in.
var believer_count := 0
var prayer := 0.0
var tithes := 0.0
## How many believers the homes of the city hold; there can be no more believers than this.
var housing_capacity := 0
## How many priests the cult has (the high priest, and whoever is trained).
var priest_count := 0
## How many missionaries the cult has.
var missionary_count := 0
## How many special agents (Vandalists) the cult has, jailed ones included.
var agent_count := 0
## The sermons preachers give; its signals tell the player where one is and whether
## the police step in.
var sermons := Sermons.new()
## Who wins people over and how (a child node).
var preaching := Preaching.new()
## Who works and trains where.
var staffing := Staffing.new(self)
## What has been bought for each building.
var upgrades := BuildingUpgrades.new()
## Extra pleasure for believers living in a building (murals nearby), set by Murals.
var pleasure_bonus: Dictionary = {}   # building -> 0..1

var _homes: Array[Node3D] = []
var _offices: Array[Node3D] = []
var _by_home: Dictionary = {}   # building -> Array[Resident]
var _occupants: Dictionary = {}   # building -> Array[Resident]
var _presence: Dictionary = {}    # building -> believers living or sitting there, refreshed on a timer
var _footprints: Dictionary = {}  # building -> Rect2 on the ground (x, z)
var _presence_timer := 0.0
var _census: Census
var _street := Street.new()
var _housing: Dictionary = {}         # building -> how many residents it holds comfortably
var _headquarters: Node3D            # the first sermon house, where the high priest serves
var _home_comfort: Dictionary = {}   # building -> the comfort its residents drift toward
var _rng := RandomNumberGenerator.new()
# Loaded at run time: a parse-time preload would load the element scripts before
# their class_name is registered and break the typed arrays.
var _people: PeopleSettings = load("res://data/people.tres")
var _archetypes: ArchetypeSettings = load("res://data/archetypes.tres")

@onready var city: Node3D = get_parent()


func _ready() -> void:
	_rng.seed = 7
	add_child(Crowd.new())
	sermons.setup(self)
	add_child(sermons)
	preaching.setup(self)
	add_child(preaching)
	_street.set_down.connect(_on_set_down)
	_street.stopped_occupying.connect(_on_stopped_occupying)
	add_child(_street)
	# The city builds its blocks in its own _ready, which runs after ours.
	city.ready.connect(_populate, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_presence_timer -= delta
	if _presence_timer > 0.0:
		return
	_presence_timer = _people.presence_refresh
	_refresh_presence()


## How strongly believers hold `building`: how many believers live there or
## sit in on it. Cached, so it is cheap to ask every tick.
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
		if r.is_believer():
			n += 1
	return float(n) / people.size()


## How many people live in `building`, and how many of them believe: the
## "X of Y" of its tooltip.
func residents_in(building: Node3D) -> int:
	return (_by_home.get(building, []) as Array).size()


func believers_in(building: Node3D) -> int:
	var n := 0
	for r: Resident in _by_home.get(building, []):
		if r.is_believer():
			n += 1
	return n


## What `building` yields now: belief per second for a prayer house, the staff
## output for a shop, 0 for anything else. Meant for tooltips, not for every frame.
func yield_of(building: Node3D) -> float:
	if building.is_in_group(SHOPS):
		return staffing.staffed(building)
	if not building.is_in_group(PRAYER_HOUSES) or is_blockaded(building):
		return 0.0
	var seen := {}
	var total := 0.0
	var people: Array = []
	people.append_array(staffing.members(building))
	people.append_array(occupants(building))
	for r: Resident in people:
		if seen.has(r) or not r.is_believer():
			continue
		seen[r] = true
		# Someone posted elsewhere prays there, not here.
		if r.post == null or r.post == building:
			total += belief_rate(r)
	return total if staffing.is_staffed(building) else 0.0


## The resident whose body stands nearest `p` on the ground, within `radius`; null if none.
func resident_near(p: Vector3, radius: float) -> Resident:
	return _street.resident_near(p, radius)


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


## `building` burned down for good (a fire nobody put out): some of the people
## indoors, those living there without a body on the street and those sitting
## in or working there, die; the rest are evacuated as usual.
func burn_down(building: Node3D) -> void:
	var inside: Array = []
	inside.append_array(occupants(building))
	inside.append_array(staffing.members(building))
	for r: Resident in _by_home.get(building, []):
		if r.body == null:
			inside.append(r)
	var dead := {}
	for r: Resident in inside:
		if r.alive and r != priest and _rng.randf() < _people.fire_death_chance:
			dead[r] = true
	# Leave first, so the dead are not moved to another home.
	_release_occupants(building)
	for r: Resident in dead:
		_kill(r)
	evacuate(building)
	if not dead.is_empty():
		people_died.emit(building, dead.size())


## Reset `building`: every believer living or sitting in there is let go. The
## sitters go home, the residents move to the nearest other home, and the staff
## lose their posts. Unlike evacuate, the building stays a home for others.
func dismiss_believers(building: Node3D) -> void:
	_release_occupants(building)
	staffing.forget(building)
	_homes.erase(building)
	var new_home := home_near(building.global_position)
	_homes.append(building)
	var count := 0
	for r: Resident in (_by_home.get(building, []) as Array).duplicate():
		if not r.is_believer():
			continue
		count += 1
		if new_home:
			_set_home(r, new_home)
			if _has_body(r):
				r.body.move_out()
	believers_dismissed.emit(building, count)


## `share` of the plain believers who live in `building` stop believing (a thin line
## gave way); anyone sitting in goes home.
func revert_believers(building: Node3D, share: float) -> void:
	_release_occupants(building)
	var plain: Array[Resident] = []
	for r: Resident in _by_home.get(building, []):
		if r.rank == Resident.Rank.BELIEVER:
			plain.append(r)
	plain.shuffle()
	for r in plain.slice(0, ceili(plain.size() * share)):
		staffing.unassign(r)
		convert_to(r, Resident.Rank.RESIDENT)


## Close `building` for a while (a condemnation notice): everyone who lives, sits or
## works there leaves for the nearest other home. Returns who lived there, for reopen.
func close_building(building: Node3D) -> Array[Resident]:
	_release_occupants(building)
	staffing.forget(building)
	_homes.erase(building)
	var out: Array[Resident] = []
	var new_home := home_near(building.global_position)
	if new_home == null:
		return out
	for r: Resident in (_by_home.get(building, []) as Array).duplicate():
		out.append(r)
		_set_home(r, new_home)
		if _has_body(r):
			r.body.move_out()
	return out


## `building` reopens: whoever it held and still lives where they went moves back.
func reopen_building(building: Node3D, people: Array[Resident]) -> void:
	if not _homes.has(building):
		_homes.append(building)
	for r in people:
		if r.alive and r.home != building:
			_set_home(r, building)
			if _has_body(r):
				r.body.move_out()


## Take `r` off the street (arrested): their body goes to someone indoors.
func put_away(r: Resident) -> void:
	if _has_body(r):
		_street.put_away(r)


## Set `r`'s rank (a conversion, a promotion, a believer leaving) and announce it.
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


## People of `rank` on the street within `radius` of `p` who have no post yet.
func free_believers_near(p: Vector3, radius: float,
		rank := Resident.Rank.BELIEVER) -> Array[Resident]:
	var out: Array[Resident] = []
	for c in _street.bodies:
		var r := c.resident
		if r.job == Resident.Job.FREE and r.rank == rank \
				and c.global_position.distance_to(p) < radius:
			out.append(r)
	return out


## A police roadblock stops what a building produces while it stands.
func is_blockaded(building: Node3D) -> bool:
	return police != null and police.is_blockaded(building)


## What `r` makes for the cult per second while it counts: belief by their
## faith (in a staffed sermon house) and money by their wealth, times their needs.
func belief_rate(r: Resident) -> float:
	return U.belief_per_minute / 60.0 * r.faith * needs_multiplier(r)


func money_rate(r: Resident) -> float:
	return U.money_per_minute / 60.0 * r.wealth * needs_multiplier(r)


func needs_multiplier(r: Resident) -> float:
	return Needs.multiplier(r, _archetypes, U)


## The archetype numbers (levels to values), for the debug card.
func archetypes() -> ArchetypeSettings:
	return _archetypes


## Buy `kind` for `building` (the caller has taken the money): well-being for
## an elevator or roof garden, fear for cameras or a gate. Adds places for staff.
func upgrade(building: Node3D, kind: BuildingUpgrades.Kind) -> void:
	match kind:
		BuildingUpgrades.Kind.ELEVATOR, BuildingUpgrades.Kind.ROOF_GARDEN, \
				BuildingUpgrades.Kind.RESTAURANT:
			add_comfort(building, _people.upgrade_comfort)
		BuildingUpgrades.Kind.CAMERAS, BuildingUpgrades.Kind.GATE:
			scare(building, _people.upgrade_fear)
	upgrades.add(building, kind)


## How much harder the believers living in `building` fight a takeover by
## force (1 = no extra): the more afraid they are, the more.
func force_power_of(building: Node3D) -> float:
	return 1.0 + _people.fear_force_bonus * _believer_fear(building)


## How much more heat the police need before they step in at `building`
## (1 = no extra): frightened believers resist.
func defense_of(building: Node3D) -> float:
	return 1.0 + _people.fear_defense_bonus * _believer_fear(building)


## Everyone living in `building` is frightened by `amount` (roaches, a fire).
func scare(building: Node3D, amount: float) -> void:
	for r: Resident in _by_home.get(building, []):
		r.fear = minf(r.fear + amount, 1.0)


## `building` became nicer (or worse) to live in by `amount`; its residents'
## comfort drifts toward the new level.
func add_comfort(building: Node3D, amount: float) -> void:
	_home_comfort[building] = clampf(_home_comfort.get(building, 0.5) + amount, 0.0, 1.0)


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


## The game starts here: the start district's core building becomes the first
## sermon house, and one of its residents the high priest, the cult's only member.
func found_cult() -> void:
	var start := districts.start_building()
	if start == null:
		return
	start.add_to_group(PRAYER_HOUSES)
	_headquarters = start
	var people: Array = _by_home.get(start, [])
	if people.is_empty():
		return
	priest = people[0]
	priest.color = U.color(Resident.Rank.HIGH_PRIEST)
	priest.comfort = 1.0
	priest.fear = 0.0
	convert_to(priest, Resident.Rank.HIGH_PRIEST)
	staffing.post(priest, Resident.Job.PRIEST, start)
	cult_founded.emit(start)


func _kill(r: Resident) -> void:
	staffing.unassign(r)
	r.alive = false
	r.rank = Resident.Rank.RESIDENT
	if r.home:
		(_by_home[r.home] as Array).erase(r)
	if _has_body(r):
		_street.bodies.erase(r.body)
		r.body.queue_free()
		r.body = null


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


func _believer_fear(building: Node3D) -> float:
	var total := 0.0
	var n := 0
	for r: Resident in _by_home.get(building, []):
		if r.is_believer():
			total += r.fear
			n += 1
	return total / n if n > 0 else 0.0


func _populate() -> void:
	_census = Census.new(_people, _archetypes, _rng, districts.kind_at)
	_census.take(get_tree().get_nodes_in_group("buildings"))
	residents = _census.residents
	_by_home = _census.by_home
	_homes = _census.homes
	_offices = _census.offices
	for home: Node3D in _by_home:
		var total := 0.0
		for r: Resident in _by_home[home]:
			total += r.wealth
		_home_comfort[home] = total / maxi((_by_home[home] as Array).size(), 1)
	for home: Node3D in _by_home:
		_housing[home] = ceili((_by_home[home] as Array).size() * _people.housing_slack)
	_street.police = police
	_street.fill(city, _by_home, residents)
	for b in _homes + _offices:
		_footprints[b] = _footprint(b)
		_presence[b] = 0.0
		b.tree_exiting.connect(_forget_building.bind(b), CONNECT_ONE_SHOT)
	_refresh_presence()
	found_cult.call_deferred()


## A believer set down on a building, or right at its walls, sits in there.
func _on_set_down(c: Citizen) -> void:
	var r := c.resident
	if not r.is_believer() or r.occupying:
		return
	var p := r.body.global_position
	var building := _place_at(p)
	if building == null:
		return
	if r.rank == Resident.Rank.AGENT:
		agent_set_down.emit(r, building)
		return
	# Set down in a prayer house or shop: the believer starts working there.
	if r.job == Resident.Job.FREE:
		var job := Resident.Job.FREE
		if building.is_in_group(SHOPS):
			job = Resident.Job.SHOP
		elif building.is_in_group(PRAYER_HOUSES):
			job = Resident.Job.PRAY
		if staffing.assign(r, job, building):
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
	staffing.forget(building)
	upgrades.forget(building)
	if _homes.is_empty():
		return
	for r in residents:
		if r.work == building:
			r.work = _census.pick_work(r.archetype)


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


## Shops and prayer houses have no residents: whoever lives in a building
## that became one moves to the nearest home, which crowds it.
func _vacate_work_buildings() -> void:
	for b: Node3D in _by_home.keys():
		if b == _headquarters or (_by_home[b] as Array).is_empty():
			continue
		if not (b.is_in_group(SHOPS) or b.is_in_group(PRAYER_HOUSES)):
			continue
		_homes.erase(b)
		var new_home := home_near(b.global_position)
		if new_home == null:
			return
		for r: Resident in (_by_home[b] as Array).duplicate():
			_set_home(r, new_home)
			if _has_body(r):
				r.body.move_out()


## 0 for a home with room, up to 1 at twice its capacity.
func _crowding(building: Node3D) -> float:
	var cap := _capacity_of_home(building)
	if cap <= 0:
		return 0.0
	return clampf(float(residents_in(building)) / cap - 1.0, 0.0, 1.0)


func _capacity_of_home(building: Node3D) -> int:
	return _housing.get(building, 0) + upgrades.extra_places(building)


func _refresh_presence() -> void:
	_vacate_work_buildings()
	housing_capacity = 0
	for home: Node3D in _homes:
		housing_capacity += _capacity_of_home(home)
	for b: Node3D in _presence:
		_presence[b] = 0.0
	believer_count = 0
	prayer = 0.0
	tithes = 0.0
	var dt := _people.presence_refresh
	for r in residents:
		if not r.alive:
			continue
		_feel(r, dt)
		if not r.is_believer():
			continue
		Needs.refresh(r, U, pleasure_bonus.get(r.home, 0.0))
		if r != priest and Needs.livelihood_met(r, _archetypes) < U.leave_below \
				and _rng.randf() < U.leave_chance_per_minute * dt / 60.0:
			convert_to(r, Resident.Rank.RESIDENT)
			continue
		staffing.tick_training(r, dt)
		believer_count += 1
		tithes += money_rate(r)
		_presence[r.home] += 1.0
		if r.occupying and r.occupying != r.home:
			_presence[r.occupying] += 1.0
		# Only believers working or sitting in a staffed sermon house make belief;
		# living next to the altar doesn't, so the player has to staff the house.
		var house: Node3D = r.post if r.post else r.occupying
		if house and house.is_in_group(PRAYER_HOUSES) and staffing.is_staffed(house) \
				and not is_blockaded(house):
			prayer += belief_rate(r)


func _count_ranks() -> void:
	priest_count = 0
	missionary_count = 0
	agent_count = 0
	for r in residents:
		if r.is_priest():
			priest_count += 1
		elif r.rank == Resident.Rank.MISSIONARY:
			missionary_count += 1
		elif r.rank == Resident.Rank.AGENT and r.alive:
			agent_count += 1


## Comfort follows the home; fear fades, and too much of it moves people out.
func _feel(r: Resident, dt: float) -> void:
	var target: float = _home_comfort.get(r.home, r.wealth) \
			- _people.crowding_penalty * _crowding(r.home)
	r.comfort = move_toward(r.comfort, maxf(target, 0.0), _people.comfort_rate * dt)
	r.fear = maxf(r.fear - _people.fear_decay * dt, 0.0)
	if r.fear > _people.flee_fear and r != priest:
		r.fear *= 0.5
		evict(r)
