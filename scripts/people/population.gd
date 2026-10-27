class_name Population
extends Node
## The city's residents. Once the city is built, gives every person a name, a
## group, a home in a real building (at least a few in each), a workplace,
## family and close friends. Other systems ask Population about people (who
## lives where, who believes) instead of scanning the scene tree.
##
## Most residents are indoors at any moment: about one in residents_per_body
## has a body walking the city, and every lived-in home has at least one out.
## Out of the god's view, a body now and then goes in and a housemate comes
## out, so everyone gets their turn on the street.
##
## Belief for the pool comes only from prayer houses (buildings in the
## prayer_houses group): the believers living or sitting in one pray. The
## starting congregation's home is the first, and its head priest prays and
## preaches on his own.
##
## Every resident also has hidden wealth, comfort and fear: the priest only
## reaches the comfortable and unafraid, force works on the frightened, and
## too much fear makes people move away.
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
## `kind` was bought for `building` (see upgrades_of).
signal upgraded(building: Node3D, kind: Upgrade)
## The player let every believer go from `building` (it can be settled again).
signal believers_dismissed(building: Node3D, count: int)
## A priest preached to `reached` people on the street.
signal priest_preached(priest: Resident, reached: int)

# Loaded at run time: a parse-time preload would load social_group.gd before
# its class_name is registered and break the typed groups array.
var _people: PeopleSettings = load("res://data/people.tres")
const B: Balance = preload("res://data/balance.tres")
## Buildings whose use is prayer; whoever sets a building's use keeps this group.
const PRAYER_HOUSES := &"prayer_houses"
## The housing upgrades on the menu.
enum Upgrade { ELEVATOR, ROOF_GARDEN, CAMERAS, GATE }
## Buildings that take shop staff; whoever sets a building's use keeps this group.
const SHOPS := &"shops"

## Where a miracle left proof, a priest's preaching is stronger.
@export var miracles: Miracles

var residents: Array[Resident] = []
## The cult's head priest (a Resident with a body), once the congregation is founded.
var priest: Resident
## Refreshed with the presence: how many residents believe, and the belief per
## second their prayers add to the pool.
var believer_count := 0
var prayer := 0.0
## How many priests the cult has (the head priest, and whoever is ordained).
var priest_count := 0

var _homes: Array[Node3D] = []
var _offices: Array[Node3D] = []
var _by_home: Dictionary = {}   # building -> Array[Resident]
var _occupants: Dictionary = {}   # building -> Array[Resident]
var _presence: Dictionary = {}    # building -> summed belief of its believers, refreshed on a timer
var _footprints: Dictionary = {}  # building -> Rect2 on the ground (x, z)
var _presence_timer := 0.0
var _census: Census
var _street := Street.new()
var _stages: Dictionary = {}       # resident -> the stage last announced
var _priest_timer := 0.0
var _bought: Dictionary = {}          # building -> Array[Upgrade] bought for it
var _purchases: Dictionary = {}      # building -> upgrades and floors bought so far
var _staff: Dictionary = {}          # building -> Array[Resident] with a post there
var _home_comfort: Dictionary = {}   # building -> the comfort its residents drift toward
var _rng := RandomNumberGenerator.new()

@onready var city: Node3D = get_parent()


func _ready() -> void:
	_rng.seed = 7
	add_child(Crowd.new())
	_street.set_down.connect(_on_set_down)
	_street.stopped_occupying.connect(_on_stopped_occupying)
	add_child(_street)
	# The city builds its blocks in its own _ready, which runs after ours.
	city.ready.connect(_populate, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_priest_timer -= delta
	if _priest_timer <= 0.0:
		_priest_timer = _people.priest_interval
		_preach()
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


## How many people live in `building`, and how many of them believe: the
## "X of Y" of its tooltip.
func residents_in(building: Node3D) -> int:
	return (_by_home.get(building, []) as Array).size()


func believers_in(building: Node3D) -> int:
	var n := 0
	for r: Resident in _by_home.get(building, []):
		if r.belief > B.believer_threshold:
			n += 1
	return n


## What `building` yields now: belief per second for a prayer house, the staff
## output for a shop, 0 for anything else. Meant for tooltips, not for every frame.
func yield_of(building: Node3D) -> float:
	if building.is_in_group(SHOPS):
		return staffed(building)
	if not building.is_in_group(PRAYER_HOUSES):
		return 0.0
	var seen := {}
	var total := 0.0
	var people: Array = []
	people.append_array(_staff.get(building, []))
	people.append_array(occupants(building))
	people.append_array(_by_home.get(building, []))
	for r: Resident in people:
		if seen.has(r) or r.belief <= B.believer_threshold:
			continue
		seen[r] = true
		# Someone posted elsewhere prays there, not here.
		if r.post == null or r.post == building:
			total += B.prayer_rate * r.belief * _output_of(r)
	return total


## The resident whose body stands nearest `p` on the ground, within `radius`; null if none.
func resident_near(p: Vector3, radius: float) -> Resident:
	return _street.resident_near(p, radius)


## Zealots on the street within `radius` of `p`: the ones who might overdo it.
func zealots_near(p: Vector3, radius: float) -> Array[Citizen]:
	return _street.zealots_near(p, radius)


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


## Reset `building`: every believer living or sitting in there is let go. The
## sitters go home, the residents move to the nearest other home, and the staff
## lose their posts. Unlike evacuate, the building stays a home for others.
func dismiss_believers(building: Node3D) -> void:
	_release_occupants(building)
	for r: Resident in (_staff.get(building, []) as Array).duplicate():
		unassign(r)
	_homes.erase(building)
	var new_home := home_near(building.global_position)
	_homes.append(building)
	var count := 0
	for r: Resident in (_by_home.get(building, []) as Array).duplicate():
		if r.belief <= B.believer_threshold:
			continue
		count += 1
		if new_home:
			_set_home(r, new_home)
			if _has_body(r):
				r.body.move_out()
	believers_dismissed.emit(building, count)


## Someone preaches to `r` (missionaries at the door): belief rises by
## `strength`, less the more skeptical the person is.
func preach_to(r: Resident, strength: float) -> void:
	persuade(r, SocialGroup.Route.PREACH, strength)


## Push `r` toward belief by `route` (preaching, money, force): less for
## skeptics, weighted by how their group answers that route, and at most one
## stage at a time. Preaching only reaches the comfortable and unafraid; force
## works on the frightened, money on the poor.
func persuade(r: Resident, route: SocialGroup.Route, strength: float) -> void:
	match route:
		SocialGroup.Route.PREACH:
			if r.comfort < _people.preach_min_comfort or r.fear > _people.preach_max_fear:
				return
		SocialGroup.Route.FORCE:
			strength *= lerpf(_people.force_without_fear, 1.0, r.fear)
		SocialGroup.Route.MONEY:
			strength *= lerpf(1.0, _people.money_on_rich, r.wealth)
	r.persuade(route, strength * (1.0 - r.skepticism))


## Preach to everyone on the street within `radius` of `p`. A miracle seen
## there is proof: it multiplies the strength by 1 + the proof, and a botched
## one (negative proof) can make it nothing.
## Returns how many people were reached.
func persuade_near(p: Vector3, radius: float, strength: float) -> int:
	var boosted := strength * maxf(1.0 + miracles.proof_at(p), 0.0)
	if boosted <= 0.0:
		return 0
	var reached := 0
	for c in _street.bodies:
		if c.resident.job != Resident.Job.PRIEST and c.global_position.distance_to(p) < radius:
			persuade(c.resident, SocialGroup.Route.PREACH, boosted)
			reached += 1
	return reached


## Believers on the street within `radius` of `p` who have no post yet.
func free_believers_near(p: Vector3, radius: float) -> Array[Resident]:
	var out: Array[Resident] = []
	for c in _street.bodies:
		var r := c.resident
		if r.job == Resident.Job.FREE and r.belief > B.believer_threshold \
				and c.global_position.distance_to(p) < radius:
			out.append(r)
	return out


## Give the free believer `r` a post: PRAY or PRIEST in a prayer house, SHOP in
## a shop. False if `r` doesn't believe, the building doesn't take that job or
## has no free place. A new post replaces the old one.
func assign(r: Resident, job: Resident.Job, building: Node3D) -> bool:
	if job == Resident.Job.FREE or r.belief <= B.believer_threshold or building == null:
		return false
	var group := SHOPS if job == Resident.Job.SHOP else PRAYER_HOUSES
	if not building.is_in_group(group) or staff_count(building, job) >= _slots_of(job, building):
		return false
	unassign(r)
	r.job = job
	r.post = building
	if not _staff.has(building):
		_staff[building] = []
	(_staff[building] as Array).append(r)
	if job == Resident.Job.PRIEST:
		priest_count += 1
	if r.body == null:
		_street.bring_out(r)
	if _has_body(r):
		r.body.move_out()
	return true


## `r` goes back to being a free believer.
func unassign(r: Resident) -> void:
	if r.job == Resident.Job.FREE:
		return
	if r.job == Resident.Job.PRIEST:
		priest_count -= 1
	var staff: Array = _staff.get(r.post, [])
	staff.erase(r)
	r.job = Resident.Job.FREE
	r.post = null
	if _has_body(r):
		r.body.move_out()


## How many people work in `building` (only those with `job`, unless FREE).
func staff_count(building: Node3D, job := Resident.Job.FREE) -> int:
	var n := 0
	for r: Resident in _staff.get(building, []):
		if job == Resident.Job.FREE or r.job == job:
			n += 1
	return n


## What `building`'s staff put out: each person counts for more the more
## comfortable they are. No staff, no output.
func staffed(building: Node3D) -> float:
	var total := 0.0
	for r: Resident in _staff.get(building, []):
		total += _output_of(r)
	return total


## What the next upgrade or added floor for `building` costs; it rises with each purchase.
func upgrade_cost(building: Node3D) -> float:
	return _people.upgrade_base_cost * pow(_people.upgrade_cost_growth, _purchases.get(building, 0))


## Buy `kind` for `building` (the caller has taken the money): well-being for
## an elevator or roof garden, fear for cameras or a gate. Adds places for staff.
func upgrade(building: Node3D, kind: Upgrade) -> void:
	match kind:
		Upgrade.ELEVATOR, Upgrade.ROOF_GARDEN:
			add_comfort(building, _people.upgrade_comfort)
		_:
			scare(building, _people.upgrade_fear)
	note_floor(building)
	if not _bought.has(building):
		var list: Array[Upgrade] = []
		_bought[building] = list
	(_bought[building] as Array[Upgrade]).append(kind)
	upgraded.emit(building, kind)


## The upgrades bought for `building`, in order (repeats allowed).
func upgrades_of(building: Node3D) -> Array[Upgrade]:
	var out: Array[Upgrade] = []
	out.append_array(_bought.get(building, []))
	return out


## A floor was added to `building` (decrees): counts toward the rising cost and adds staff places.
func note_floor(building: Node3D) -> void:
	_purchases[building] = _purchases.get(building, 0) + 1


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


func stage(r: Resident) -> Resident.Stage:
	return r.stage()


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
## small congregation of believers. The nearest home is the headquarters (the
## first prayer house), and its most devoted believer the head priest.
func found_congregation() -> void:
	var corner: Vector3 = city.intersection(_people.congregation_corner)
	var near := _homes.duplicate()
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(corner) < b.global_position.distance_squared_to(corner))
	near[0].add_to_group(PRAYER_HOUSES)
	var converted := 0
	for home: Node3D in near:
		if converted >= _people.congregation_size:
			break
		for r: Resident in _by_home.get(home, []):
			if converted >= _people.congregation_size:
				break
			r.belief = _rng.randf_range(_people.congregation_belief_min, _people.congregation_belief_max)
			r.baseline = r.belief
			r.skepticism = _rng.randf_range(0.0, _people.congregation_skepticism_max)
			_stages[r] = r.stage()
			if r.body == null:
				_street.bring_out(r)
			converted += 1
	_ordain_priest(near[0])


func _preach() -> void:
	for staff: Array in _staff.values():
		for r: Resident in staff:
			if r.job == Resident.Job.PRIEST and _has_body(r):
				var reached := persuade_near(
						r.body.global_position, _people.priest_reach, _people.priest_strength)
				priest_preached.emit(r, reached)


func _slots_of(job: Resident.Job, building: Node3D) -> int:
	var extra: int = _people.slots_per_purchase * _purchases.get(building, 0)
	match job:
		Resident.Job.SHOP:
			return _people.shop_slots + extra
		Resident.Job.PRIEST:
			return _people.priest_slots + extra
	return _people.prayer_slots + extra


func _output_of(r: Resident) -> float:
	return 1.0 + _people.comfort_output_bonus * r.comfort


func _believer_fear(building: Node3D) -> float:
	var total := 0.0
	var n := 0
	for r: Resident in _by_home.get(building, []):
		if r.belief > B.believer_threshold:
			total += r.fear
			n += 1
	return total / n if n > 0 else 0.0


func _populate() -> void:
	_census = Census.new(_people, _rng)
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
	for r in residents:
		_stages[r] = r.stage()
	_street.fill(city, _by_home, residents)
	for b in _homes + _offices:
		_footprints[b] = _footprint(b)
		_presence[b] = 0.0
		b.tree_exiting.connect(_forget_building.bind(b), CONNECT_ONE_SHOT)
	_refresh_presence()


func _ordain_priest(headquarters: Node3D) -> void:
	var best: Resident = null
	for r: Resident in _by_home.get(headquarters, []):
		if best == null or r.belief > best.belief:
			best = r
	if best == null:
		return
	priest = best
	priest.belief = 1.0
	priest.baseline = 1.0
	priest.comfort = 1.0
	priest.color = _people.priest_color
	_stages[priest] = priest.stage()
	priest.job = Resident.Job.PRIEST
	priest.post = headquarters
	_staff[headquarters] = [priest]
	priest_count += 1
	if priest.body == null:
		_street.bring_out(priest)


## A believer set down on a building, or right at its walls, sits in there.
func _on_set_down(c: Citizen) -> void:
	var r := c.resident
	if r.belief <= B.believer_threshold or r.occupying:
		return
	var p := r.body.global_position
	var building := _place_at(p)
	if building == null:
		return
	# Set down in a prayer house or shop: the believer starts working there.
	if r.job == Resident.Job.FREE:
		var job := Resident.Job.FREE
		if building.is_in_group(SHOPS):
			job = Resident.Job.SHOP
		elif building.is_in_group(PRAYER_HOUSES):
			job = Resident.Job.PRAY
		if assign(r, job, building):
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
	for r: Resident in (_staff.get(building, []) as Array).duplicate():
		unassign(r)
	_staff.erase(building)
	_purchases.erase(building)
	_bought.erase(building)
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
		_presence[r.home] += r.belief
		if r.occupying and r.occupying != r.home:
			_presence[r.occupying] += r.belief
		# Only prayer-house staff and seats taken in one make belief.
		var at := r.occupying if r.occupying else r.home
		if r.job == Resident.Job.PRAY or at.is_in_group(PRAYER_HOUSES):
			prayer += B.prayer_rate * r.belief * _output_of(r)
	if priest:
		prayer += _people.priest_prayer
	var dt := _people.presence_refresh
	for r in residents:
		var total := 0.0
		for id in r.friends:
			total += residents[id].belief
		r.friends_belief = total / r.friends.size() if not r.friends.is_empty() else 0.0
		_drift(r, dt)
		_feel(r, dt)
		if r.job != Resident.Job.FREE and r.belief <= B.believer_threshold:
			unassign(r)
		var now := r.stage()
		var before: int = _stages[r]
		if now != before:
			_stages[r] = now
			stage_changed.emit(r, before, now)


## Comfort follows the home; fear fades, and too much of it moves people out.
func _feel(r: Resident, dt: float) -> void:
	r.comfort = move_toward(r.comfort, _home_comfort.get(r.home, r.wealth), _people.comfort_rate * dt)
	r.fear = maxf(r.fear - _people.fear_decay * dt, 0.0)
	if r.fear > _people.flee_fear and r != priest:
		r.fear *= 0.5
		evict(r)


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
