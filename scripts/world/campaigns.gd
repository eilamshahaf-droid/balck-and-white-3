class_name Campaigns
extends Node
## Taking a building (Eilam's model of 2026-11-13): Reps at a building's door fill its
## takeover meter (Districts), slower the bigger the building, faster with more Reps and
## while the god's hand is on it; when it is full one of them takes the building over and
## stays as its Manager. A building that already wants you is taken the moment a Rep is
## set down at it. The hand starts the work by setting a Rep down at a door; the wheel's
## "Send a Rep" sends the nearest free one.

## Reps were sent to `building`.
signal campaign_started(building: Node3D)
## The work on `building` ended; `won` when it was taken.
signal campaign_ended(building: Node3D, won: bool)
## A Rep the hand set down at `building` can't work on it, and `why`.
signal mark_refused(building: Node3D, why: String)
## `rep` took `building` over and manages it.
signal taken(building: Node3D, rep: Resident)

const S: CampaignSettings = preload("res://data/campaigns.tres")
const F: FollowersSettings = preload("res://data/followers.tres")
const SIDEWALK_GAP := 1.5   # metres out from the wall
const SECRETARY_LAST := 1.0e9   # added to his distance, so any free Rep is nearer

@export var districts: Districts
@export var population: Population
@export var followers: Followers
@export var hand: GodHand

var _campaigns: Array[Campaign] = []
var _timer := 0.0


class Campaign:
	var building: Node3D
	var agents: Array[Citizen] = []
	## What holds it up, for the HUD ("" while it runs).
	var stalled := ""
	## Sent from the wheel: the nearest free Rep goes. Work the hand started has only
	## the Reps the hand set down.
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


## Send the nearest free Rep to `building`; the same again calls the work off. Returns
## false when it can't be worked on (see why_not()).
func send(building: Node3D) -> bool:
	var c := _campaign_on(building)
	if c:
		_end(c, false)
		return true
	if why_not(building) != "":
		return false
	_start(building).auto = true
	return true


func clear(building: Node3D) -> void:
	var c := _campaign_on(building)
	if c:
		_end(c, false)


func is_sent(building: Node3D) -> bool:
	return _campaign_on(building) != null


## Why `building` can't be worked on right now; "" when it can.
func why_not(building: Node3D) -> String:
	var i := districts.index_of(building)
	if i < 0:
		return "not a building"
	if districts.is_yours(i):
		return "already yours"
	if districts.is_key(i):
		return "a key building: it will take more than a Rep"
	if not districts.is_open(building):
		return "opens in a later stage"
	if not districts.borders_yours(i):
		return "must border a building of yours"
	if not districts.can_claim(i):
		return "take the buildings around it first"
	return ""


## Every building Reps are working on.
func marked() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in _campaigns:
		out.append(c.building)
	return out


## The Reps (or the Secretary) on the way to `building` or at its door.
func reps_at(building: Node3D) -> Array[Resident]:
	var found: Array[Resident] = []
	var c := _campaign_on(building)
	if c:
		for a in c.agents:
			if is_instance_valid(a) and a.on_errand:
				found.append(a.resident)
	return found


## `rep` stops work and walks off (an inspector sent them home).
func dismiss(rep: Resident) -> void:
	if is_instance_valid(rep.body):
		rep.body.end_errand()


## How many Reps stand at `building` now.
func crew_at(building: Node3D) -> int:
	var c := _campaign_on(building)
	if c == null:
		return 0
	return c.agents.filter(func(a: Citizen) -> bool: return is_instance_valid(a) and a.errand_arrived).size()


## What holds the work on `building` up, or "" while it runs.
func stalled_on(building: Node3D) -> String:
	var c := _campaign_on(building)
	return c.stalled if c else ""


## Seconds one Rep takes to fill `building`'s meter: by its room against an ordinary
## building's.
func seconds_for(building: Node3D) -> float:
	var room := followers.room_of(districts.index_of(building))
	return S.rep_seconds * clampf(float(room) / S.ordinary_room, S.size_factor_min, S.size_factor_max)


## The hand set a Rep (or the Secretary) down at `building`. One that already wants you
## is taken on the spot; otherwise they start on its meter, joining whoever is at it.
func _on_canvasser_set_down(r: Resident, building: Node3D) -> void:
	var i := districts.index_of(building)
	if i >= 0 and districts.wants_you(i) and r.rank == Resident.Rank.MISSIONARY \
			and districts.can_claim(i):
		clear(building)
		_take(building, r)
		return
	var c := _campaign_on(building)
	if c == null:
		var why := why_not(building)
		if why != "":
			mark_refused.emit(building, why)
			return
		c = _start(building)
	if is_instance_valid(r.body) and not c.agents.has(r.body):
		r.body.send_on_errand(_spot_outside(building), building.global_position, INF,
				S.missionary_line, S.line_color)
		c.agents.append(r.body)


func _start(building: Node3D) -> Campaign:
	var c := Campaign.new()
	c.building = building
	_campaigns.append(c)
	campaign_started.emit(building)
	return c


## `rep` takes `building` over and stays as its Manager.
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
	var i := districts.index_of(c.building)
	if not districts.can_claim(i):
		c.stalled = "must border a building of yours"
		return
	c.agents = c.agents.filter(func(a: Citizen) -> bool: return is_instance_valid(a) and a.on_errand)
	if c.agents.is_empty() and c.auto:
		_send_nearest(c)
	var working := 0
	var rep: Resident = null
	for a in c.agents:
		if a.errand_arrived:
			working += 1
			if a.resident.rank == Resident.Rank.MISSIONARY:
				rep = a.resident
	if working == 0:
		c.stalled = "on the way" if not c.agents.is_empty() else "needs a Rep"
		return
	c.stalled = ""
	var attention := F.attention if hand.pointed_part == c.building else 1.0
	districts.add_meter(i, working * attention * S.tick / seconds_for(c.building))
	if not districts.wants_you(i):
		return
	# Full: a Rep at the door takes it over. The Secretary has the Office to run, so
	# work he did alone leaves the building wanting you.
	if rep:
		_take(c.building, rep)
	else:
		_end(c, false)


## The nearest free Rep goes to the door; with none trained yet, the Secretary himself.
func _send_nearest(c: Campaign) -> void:
	var best: Citizen = null
	var best_d := INF
	var from := c.building.global_position
	for r: Resident in population.residents:
		var free_rep := r.rank == Resident.Rank.MISSIONARY and r.job == Resident.Job.FREE
		if not (free_rep or r == population.priest) or not is_instance_valid(r.body) \
				or not r.body.can_answer():
			continue
		var d := r.body.global_position.distance_squared_to(from)
		# Any Rep before the Secretary.
		if r == population.priest:
			d += SECRETARY_LAST
		if d < best_d:
			best_d = d
			best = r.body
	if best:
		best.send_on_errand(_spot_outside(c.building), from, INF, S.missionary_line, S.line_color)
		c.agents.append(best)


## The pavement in front of `building`, on its street side (local -z, see PlanBuilder),
## somewhere along the wall.
func _spot_outside(building: Node3D) -> Vector3:
	var half := BuildingBox.size_of(building) / 2.0
	var along := randf_range(-half.x, half.x) * 0.8
	var spot := building.global_transform * Vector3(along, -half.y, -half.z - SIDEWALK_GAP)
	spot.y = 0.0
	return spot


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
	campaign_ended.emit(c.building, won)
