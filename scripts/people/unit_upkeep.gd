class_name UnitUpkeep
extends Node
## What the Committee's people cost in paperwork (Eilam via the Designer, 0.26.0): every
## Rep and the Fixer cost paperwork a second while they exist, a Manager a share of a
## Rep's. Clerks make it, so you can't keep Reps without desks. With the paperwork at 0,
## every revert_seconds one Rep who isn't a Manager (a free one first) goes back to being
## a plain follower, then the Fixer; nothing else is lost.

## `who` gave the work up for want of paperwork and is a follower again.
signal reverted(who: Resident)

const F: FollowersSettings = preload("res://data/followers.tres")
const TICK := 1.0

@export var population: Population
@export var followers: Followers
@export var faith: Faith

var _timer := 0.0
var _dry := 0.0   # seconds the paperwork has been short


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	var cost := rate() * TICK
	if cost <= 0.0:
		_dry = 0.0
		return
	if faith.spend(cost, &"upkeep"):
		_dry = 0.0
		return
	if faith.belief_pool > 0.0:
		faith.spend(faith.belief_pool, &"upkeep")
	_dry += TICK
	if _dry >= F.revert_seconds:
		_dry = 0.0
		_revert_one()


## Paperwork a second the Reps, Managers and the Fixer cost now.
func rate() -> float:
	var reps := 0
	var managers := 0
	for r in population.residents:
		if r.rank != Resident.Rank.MISSIONARY:
			continue
		if r.job == Resident.Job.MANAGER:
			managers += 1
		else:
			reps += 1
	return F.rep_upkeep * (reps + managers * F.manager_upkeep_share) \
			+ F.fixer_upkeep * population.agent_count


## One Rep who isn't a Manager goes back to being a follower, a free one before one at a
## door; with none, the Fixer.
func _revert_one() -> void:
	var pick: Resident = null
	for r in population.residents:
		if r.rank != Resident.Rank.MISSIONARY or r.job == Resident.Job.MANAGER:
			continue
		var busy := is_instance_valid(r.body) and r.body.on_errand
		if pick == null or not busy:
			pick = r
			if not busy:
				break
	if pick == null:
		for r in population.residents:
			if r.rank == Resident.Rank.AGENT and r.alive:
				pick = r
				break
	if pick == null:
		return
	if is_instance_valid(pick.body) and pick.body.on_errand:
		pick.body.end_errand()
	population.staffing.unassign(pick)
	population.convert_to(pick, Resident.Rank.BELIEVER)
	followers.give_back()
	reverted.emit(pick)
