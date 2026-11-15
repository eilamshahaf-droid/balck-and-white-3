class_name Staffing
extends RefCounted
## Where the units are posted: the Secretary at the main Office, people in training
## there to become a Rep or a Fixer, and Managers in the buildings they took over.
## Population owns one.

const U: UnitSettings = preload("res://data/units.tres")

var _population: Population
var _staff: Dictionary = {}   # building -> Array[Resident] with a post there


func _init(population: Population) -> void:
	_population = population


## Put `r` on `job` in `building`.
func post(r: Resident, job: Resident.Job, building: Node3D) -> void:
	unassign(r)
	r.job = job
	r.post = building
	if not _staff.has(building):
		_staff[building] = []
	(_staff[building] as Array).append(r)
	_population.bring_out(r)


## `r` has no post any more.
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


## `r` starts training in `building` to become a Rep (MISSIONARY) or a Fixer (AGENT).
func train(r: Resident, rank: Resident.Rank, building: Node3D) -> void:
	post(r, Resident.Job.TRAIN, building)
	r.training_for = rank
	r.training_left = U.missionary_time if rank == Resident.Rank.MISSIONARY else U.agent_time


## Count down `r`'s training by `dt`; when it is done they take the new rank.
func tick_training(r: Resident, dt: float) -> void:
	if r.job != Resident.Job.TRAIN:
		return
	r.training_left -= dt
	if r.training_left > 0.0:
		return
	unassign(r)
	_population.convert_to(r, r.training_for)


## How many are training for `rank` now.
func training_for(rank: Resident.Rank) -> int:
	var n := 0
	for building: Node3D in _staff:
		for r: Resident in _staff[building]:
			if r.job == Resident.Job.TRAIN and r.training_for == rank:
				n += 1
	return n


## Everyone with a post in `building`.
func members(building: Node3D) -> Array:
	return _staff.get(building, [])
