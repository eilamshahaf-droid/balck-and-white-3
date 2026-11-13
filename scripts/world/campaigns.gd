class_name Campaigns
extends Node
## How a building's takeover meter (Districts) is filled on purpose, and how a full one
## is taken (Eilam's rule of 2026-11-13). Sky sign: reps at the door fill it, each at
## their own pace, more reps faster; when it is full one of them takes the building over
## and stays as its manager. Skull and dollar fill the same meter by force or by money
## and leave the building wanting you, for a rep to come and manage. The hand starts the
## sky sign by setting a rep down at a door; the wheel sends the nearest free one.

signal campaign_started(building: Node3D, route: Route)
signal campaign_ended(building: Node3D, route: Route, won: bool)
## A canvasser the hand set down at `building` can't work on it, and `why`.
signal mark_refused(building: Node3D, why: String)
## Reps are at work on `building` right now (once a step): the neighbours may notice.
signal worked(building: Node3D)
## `rep` took `building` over and manages it.
signal taken(building: Node3D, rep: Resident)

enum Route { FORCE, BUY, PREACH }

const S: CampaignSettings = preload("res://data/campaigns.tres")
const U: UnitSettings = preload("res://data/units.tres")
const NONE := -1
const SIDEWALK_GAP := 1.5   # metres out from the wall

@export var districts: Districts
@export var population: Population
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
	## Marked from the wheel: the nearest free rep is sent. A campaign the hand started
	## has only the reps the hand set down.
	var auto := false


func _ready() -> void:
	population.canvasser_set_down.connect(_on_canvasser_set_down)


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
	c.auto = true
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
	if not districts.is_open(building):
		return "opens in a later stage"
	if not districts.borders_yours(i):
		return "must border a building of yours"
	if not districts.can_claim(i):
		return "take the buildings around it first"
	match route:
		Route.FORCE:
			if _training() == null:
				return "needs a %s building" % S.training_use
		Route.BUY:
			if not treasury.can_afford(price_in(building)):
				return "needs $%d" % roundi(price_in(building))
	return ""


## What buying one resident out of `building` costs: dearer in rich districts, cheaper
## where real estate offices stand.
func price_in(building: Node3D) -> float:
	var i := districts.index_of(building)
	return (S.apartment_price * (districts.wealth_at(i) if i >= 0 else 1.0)
			* population.staffing.buy_price_factor(building))


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
## A roadblock was wrecked: the crews may go back to work.
func unblock(building: Node3D) -> void:
	var c := _campaign_on(building)
	if c:
		c.blocked = 0.0


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


## The hand set a rep (or the Secretary) down at `building`. One that already wants you
## is taken on the spot; otherwise they start on its meter, joining whoever is at it.
func _on_canvasser_set_down(r: Resident, building: Node3D) -> void:
	var i := districts.index_of(building)
	if i >= 0 and districts.wants_you(i) and r.rank == Resident.Rank.MISSIONARY \
			and districts.can_claim(i):
		clear(building)
		_take(building, r)
		return
	var c := _campaign_on(building)
	if c == null or c.route != Route.PREACH:
		var why := why_not(building, Route.PREACH)
		if why != "":
			mark_refused.emit(building, why)
			return
		clear(building)
		c = Campaign.new()
		c.building = building
		c.route = Route.PREACH
		_campaigns.append(c)
		campaign_started.emit(building, Route.PREACH)
	if is_instance_valid(r.body) and not c.agents.has(r.body):
		r.body.send_on_errand(_spot_outside(building, false), building.global_position, INF,
				S.missionary_line, S.line_color)
		c.agents.append(r.body)


## `rep` takes `building` over and stays as its manager.
func _take(building: Node3D, rep: Resident) -> void:
	if not districts.take(districts.index_of(building)):
		return
	if is_instance_valid(rep.body):
		rep.body.end_errand()
	population.make_manager(rep, building)
	taken.emit(building, rep)


func _step(c: Campaign) -> void:
	if not is_instance_valid(c.building) or districts.owns(c.building):
		_end(c, is_instance_valid(c.building))
		return
	if c.blocked > 0.0:
		c.blocked -= S.tick
		c.stalled = "police roadblock"
		return
	if not districts.can_claim(districts.index_of(c.building)):
		c.stalled = "must border a building of yours"
		return
	_top_up(c)
	c.wait -= S.tick
	if c.wait > 0.0:
		return
	if not c.agents.any(func(a: Citizen) -> bool: return is_instance_valid(a) and a.errand_arrived):
		c.stalled = "on the way" if not c.agents.is_empty() else "nobody free to go"
		return
	var i := districts.index_of(c.building)
	match c.route:
		Route.FORCE:
			districts.add_meter(i, S.force_meter)
			faith.exposure = minf(faith.exposure + S.force_exposure, 1.0)
			# A luxurious training building trains faster.
			var training := _training()
			c.wait = S.force_interval / (treasury.speed_of(training) if training else 1.0)
		Route.BUY:
			if not treasury.spend_money(price_in(c.building)):
				c.stalled = "needs $%d" % roundi(price_in(c.building))
				return
			districts.add_meter(i, S.buy_meter)
			c.wait = S.buy_interval
		Route.PREACH:
			var gain := 0.0
			for a in c.agents:
				if is_instance_valid(a) and a.errand_arrived:
					gain += population.preaching.pace(c.building, a.resident)
			districts.add_meter(i, gain * S.tick / S.rep_seconds)
			worked.emit(c.building)
	c.stalled = ""
	if not districts.wants_you(i):
		return
	# Full: a rep at the door takes it over. Fighters, buyers and the Secretary can't
	# manage a building, so theirs is left wanting you.
	var rep := _arrived_rep(c)
	if rep:
		_take(c.building, rep)
	else:
		_end(c, false)


## Sends believers until the campaign has its crew: fighters start from the
## training building, the others from wherever they are.
func _top_up(c: Campaign) -> void:
	c.agents = c.agents.filter(func(a: Citizen) -> bool: return is_instance_valid(a) and a.on_errand)
	if c.route == Route.PREACH and not (c.auto and c.agents.is_empty()):
		return
	var wanted: int = [S.fighters, S.buyers, 1][c.route]
	var gym := _training() if c.route == Route.FORCE else null
	if gym:
		wanted = mini(wanted + floori(population.staffing.fighters_of(gym)), S.max_fighters)
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
	var rank := Resident.Rank.MISSIONARY if c.route == Route.PREACH else Resident.Rank.BELIEVER
	for r: Resident in population.residents:
		# The Secretary canvasses in person: with nobody trained yet, the Office is what
		# gets the first doors opened.
		var secretary := c.route == Route.PREACH and r.rank == Resident.Rank.HIGH_PRIEST
		if ((r.rank == rank and r.job == Resident.Job.FREE) or secretary) \
				and is_instance_valid(r.body) and r.body.can_answer():
			free.append(r.body)
	free.sort_custom(func(a: Citizen, b: Citizen) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	if free.is_empty() and c.agents.is_empty():
		c.stalled = "needs a free %s" % U.title(rank).to_lower()
		return
	var line: String = [S.fighter_line, S.buyer_line, S.missionary_line][c.route]
	var center := c.building.global_position
	for a in free.slice(0, wanted - c.agents.size()):
		a.send_on_errand(_spot_outside(c.building, false), center, INF, line, S.line_color)
		c.agents.append(a)


## The pavement in front of `building`, on its street side (local -z, see PlanBuilder);
## `middle` gives its centre, otherwise somewhere along the wall.
func _spot_outside(building: Node3D, middle: bool) -> Vector3:
	var half := BuildingBox.size_of(building) / 2.0
	var along := 0.0 if middle else randf_range(-half.x, half.x) * 0.8
	var spot := building.global_transform * Vector3(along, -half.y, -half.z - SIDEWALK_GAP)
	spot.y = 0.0
	return spot


## A rep of `c` standing at the building, or null (the Secretary doesn't count: he has
## the Office to run).
func _arrived_rep(c: Campaign) -> Resident:
	for a in c.agents:
		if is_instance_valid(a) and a.errand_arrived \
				and a.resident.rank == Resident.Rank.MISSIONARY:
			return a.resident
	return null


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
