class_name Campaigns
extends Node
## The three ways the player takes a building, by marking it (design doc,
## Eilam's round of 2026-10-27). Skull, force: fighters from a Combat Training
## building scare the non-believers out and move in. Dollar, buy: the cult buys
## out non-believers one by one and believers move in. Sky sign, missionaries:
## believers preach at the door until the residents believe. The building is
## yours, by Districts' rule, once most of its residents believe; then the
## campaign ends. Marks come from the building wheel.

signal campaign_started(building: Node3D, route: Route)
signal campaign_ended(building: Node3D, route: Route, won: bool)

enum Route { FORCE, BUY, PREACH }

const S: CampaignSettings = preload("res://data/campaigns.tres")
const B: Balance = preload("res://data/balance.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")
const NONE := -1
const SIDEWALK_GAP := 1.5   # metres out from the wall

@export var districts: Districts
@export var population: Node
@export var faith: Node
@export var treasury: Treasury
@export var decrees: Decrees

var _campaigns: Array[Campaign] = []
var _timer := 0.0


class Campaign:
	var building: Node3D
	var route: Route
	var agents: Array[Citizen] = []
	var wait := 0.0
	## Seconds the police still block the street in front of it.
	var blocked := 0.0
	## What holds it up, for the HUD ("" while it runs).
	var stalled := ""


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.tick
	for c in _campaigns.duplicate():
		_step(c)


## Marks `building` for `route`; the same mark again takes it down.
## Returns false when the mark can't go there (see why_not()).
func mark(building: Node3D, route: Route) -> bool:
	var c := _campaign_on(building)
	if c:
		var same := c.route == route
		_end(c, false)
		if same:
			return true
	if why_not(building, route) != "":
		return false
	c = Campaign.new()
	c.building = building
	c.route = route
	_campaigns.append(c)
	campaign_started.emit(building, route)
	return true


func clear(building: Node3D) -> void:
	var c := _campaign_on(building)
	if c:
		_end(c, false)


## The route marked on `building`, or NONE.
func route_of(building: Node3D) -> int:
	var c := _campaign_on(building)
	return c.route if c else NONE


## Why `route` can't be marked on `building` right now; "" when it can.
func why_not(building: Node3D, route: Route) -> String:
	var i := districts.index_of(building)
	if i < 0:
		return "not a building"
	if districts.is_yours(i):
		return "already yours"
	match route:
		Route.FORCE:
			if _training() == null:
				return "needs a %s building" % S.training_use
		Route.BUY:
			if not treasury.can_afford(price_in(building)):
				return "needs $%d" % roundi(price_in(building))
		Route.PREACH:
			if districts.residents_in(i) == 0:
				return "nobody lives there"
			if faith.belief_pool < S.preach_cost:
				return "needs %d belief" % roundi(S.preach_cost)
	return ""


## What buying one resident out of `building` costs: dearer in rich districts.
func price_in(building: Node3D) -> float:
	var i := districts.index_of(building)
	return S.apartment_price * (districts.wealth_at(i) if i >= 0 else 1.0)


## Every marked building.
func marked() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in _campaigns:
		out.append(c.building)
	return out


## How many of the crew stand at `building` now.
func crew_at(building: Node3D) -> int:
	var c := _campaign_on(building)
	if c == null:
		return 0
	return c.agents.filter(func(a: Citizen) -> bool: return is_instance_valid(a) and a.errand_arrived).size()


## The police close the street in front of `building` for `seconds`: the crew
## goes home and the campaign waits.
func block(building: Node3D, seconds: float) -> void:
	var c := _campaign_on(building)
	if c == null:
		return
	c.blocked = seconds
	for a in c.agents:
		if is_instance_valid(a):
			a.end_errand()
	c.agents.clear()


## A place on the pavement in front of `building`, on the side facing the
## nearest street corner, so the walk there doesn't run into a wall.
func spot_outside(building: Node3D) -> Vector3:
	return _spot_outside(building, true)


## What holds the campaign on `building` up, or "" while it runs.
func stalled_on(building: Node3D) -> String:
	var c := _campaign_on(building)
	return c.stalled if c else ""


func _step(c: Campaign) -> void:
	if not is_instance_valid(c.building) or districts.owns(c.building):
		_end(c, is_instance_valid(c.building))
		return
	if c.blocked > 0.0:
		c.blocked -= S.tick
		c.stalled = "police roadblock"
		return
	_top_up(c)
	c.wait -= S.tick
	if c.wait > 0.0:
		return
	if not c.agents.any(func(a: Citizen) -> bool: return is_instance_valid(a) and a.errand_arrived):
		c.stalled = "on the way" if not c.agents.is_empty() else "no free believers"
		return
	match c.route:
		Route.FORCE:
			c.stalled = "" if _drive_out(c) else "nobody left to scare"
			# A luxurious training building trains faster.
			var training := _training()
			c.wait = S.force_interval / (treasury.speed_of(training) if training else 1.0)
		Route.BUY:
			if not treasury.can_afford(price_in(c.building)):
				c.stalled = "needs $%d" % roundi(price_in(c.building))
				return
			if _buy_out(c):
				c.stalled = ""
			c.wait = S.buy_interval
		Route.PREACH:
			if faith.belief_pool < S.preach_cost:
				c.stalled = "needs %d belief" % roundi(S.preach_cost)
				return
			var r := _doubter_in(c.building)
			if r and faith.spend(S.preach_cost):
				population.persuade(r, SocialGroup.Route.PREACH, S.preach_strength)
				c.stalled = ""
			c.wait = S.preach_interval


## A non-believer flees and a believer moves in.
func _drive_out(c: Campaign) -> bool:
	var r := _doubter_in(c.building)
	if r:
		population.evict(r)
		faith.exposure = minf(faith.exposure + S.force_exposure, 1.0)
	var mover := _mover_for(c.building)
	if mover:
		population.move_home(mover, c.building)
	return r != null or mover != null


func _buy_out(c: Campaign) -> bool:
	var r := _doubter_in(c.building)
	var mover := _mover_for(c.building)
	if r == null and mover == null:
		return false
	treasury.spend_money(price_in(c.building))
	if r:
		population.evict(r)
	if mover:
		population.move_home(mover, c.building)
	return true


## Sends believers until the campaign has its crew: fighters start from the
## training building, the others from wherever they are.
func _top_up(c: Campaign) -> void:
	c.agents = c.agents.filter(func(a: Citizen) -> bool: return is_instance_valid(a) and a.on_errand)
	var wanted: int = [S.fighters, S.buyers, S.missionaries][c.route]
	if c.agents.size() >= wanted:
		return
	var from := c.building.global_position
	if c.route == Route.FORCE:
		var training := _training()
		if training == null:
			c.stalled = "needs a %s building" % S.training_use
			return
		from = training.global_position
	var free: Array[Citizen] = []
	for r: Resident in population.residents:
		if r.belief > B.believer_threshold and is_instance_valid(r.body) and r.body.can_answer():
			free.append(r.body)
	free.sort_custom(func(a: Citizen, b: Citizen) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	var line: String = [S.fighter_line, S.buyer_line, S.missionary_line][c.route]
	var center := c.building.global_position
	for a in free.slice(0, wanted - c.agents.size()):
		a.send_on_errand(_spot_outside(c.building, false), center, INF, line, S.line_color)
		c.agents.append(a)


## The pavement in front of `building` facing the nearest corner; `middle`
## gives its centre, otherwise somewhere along the wall.
func _spot_outside(building: Node3D, middle: bool) -> Vector3:
	var center := building.global_position
	var half := DivineSign.building_size(building) / 2.0
	var corner: Vector3 = districts.city.intersection(districts.city.nearest_grid(center))
	var to := corner - center
	var spot := center
	if absf(to.x) / half.x > absf(to.z) / half.z:
		spot.x += signf(to.x) * (half.x + SIDEWALK_GAP)
		spot.z += 0.0 if middle else randf_range(-half.z, half.z) * 0.8
	else:
		spot.z += signf(to.z) * (half.z + SIDEWALK_GAP)
		spot.x += 0.0 if middle else randf_range(-half.x, half.x) * 0.8
	spot.y = corner.y
	return spot


## A resident of `building` who doesn't believe, or null.
func _doubter_in(building: Node3D) -> Resident:
	for r: Resident in population.residents:
		if r.home == building and r.belief <= B.believer_threshold:
			return r
	return null


## The nearest believer who can move into `building` without losing the
## building they live in now.
func _mover_for(building: Node3D) -> Resident:
	var best: Resident = null
	var best_d := INF
	for r: Resident in population.residents:
		if r.home == building or r.belief <= B.believer_threshold or r.home == null:
			continue
		var i := districts.index_of(r.home)
		if i >= 0 and districts.is_yours(i) and not _spare(i):
			continue
		var d := r.home.global_position.distance_squared_to(building.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


## Would building `i` stay yours with one believer fewer?
func _spare(i: int) -> bool:
	var people := districts.residents_in(i) - 1
	return people <= 0 or float(districts.believers_at(i) - 1) / people > districts.S.capture_share


## A building of yours with the Combat Training use, or null.
func _training() -> Node3D:
	for b in districts.converted_buildings():
		if decrees.use_of(b) == S.training_use:
			return b
	return null


func _campaign_on(building: Node3D) -> Campaign:
	for c in _campaigns:
		if c.building == building:
			return c
	return null


func _end(c: Campaign, won: bool) -> void:
	_campaigns.erase(c)
	for a in c.agents:
		if is_instance_valid(a):
			a.end_errand()
	campaign_ended.emit(c.building, c.route, won)
