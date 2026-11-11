class_name Condemnation
extends Node3D
## Neighbours complain about a building of yours that gets loud: more than noise_at
## believers living there draw complaints, each of which makes the district more
## aware. At condemn_at complaints City Hall condemns it: a notice goes up (a warning),
## then the building is closed and emptied for close_minutes and reopens by itself.
## The hand can tear the notice off for belief and reopen it at once. One notice at a
## time. In the Slums this replaces the inspector and the bulldozer.

## A notice went up on building `index`.
signal condemned(index: int)
## Building `index` was closed and emptied.
signal closed(index: int)
## Building `index` opened again (`torn`: the hand tore the notice off).
signal reopened(index: int, torn: bool)

const A: AwarenessSettings = preload("res://data/awareness.tres")

@export var districts: Districts
@export var population: Population
@export var awareness: Awareness
@export var faith: Faith

## Complaints so far, by building index.
var complaints: Dictionary = {}
## How long the warning and the closure last (copies of the settings a test can shorten).
var warning_seconds := A.warning_seconds
var close_seconds := A.close_minutes * 60.0
var _index := -1                    # the building with the notice, -1 with none
var _left := 0.0                    # seconds of warning, then of closure
var _closed := false
var _people: Array[Resident] = []   # who lived there, to move back in
var _notice: CondemnationNotice
var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = A.tick
	_complain(A.tick / 60.0)
	if _index >= 0:
		_tend(A.tick)


## The building under a notice now, or -1.
func current() -> int:
	return _index


## Is building `index` closed by a notice?
func is_closed(index: int) -> bool:
	return _closed and index == _index


## Put a notice on building `index` now.
func condemn(index: int) -> void:
	if _index >= 0:
		return
	_index = index
	_left = warning_seconds
	_closed = false
	complaints.erase(index)
	_notice = CondemnationNotice.new()
	_notice.build(A.notice_color)
	add_child(_notice)
	_notice.global_position = _front_of(index)
	_notice.grabbed.connect(_on_torn)
	condemned.emit(index)


func _complain(minutes: float) -> void:
	for i in districts.buildings.size():
		if not districts.is_yours(i) or i == districts.headquarters or i == _index:
			continue
		var loud := districts.believers_at(i) - A.noise_at
		if loud <= 0:
			continue
		var before: float = complaints.get(i, 0.0)
		var after := before + A.complaint_rate * loud * minutes
		complaints[i] = after
		var new_ones := floori(after) - floori(before)
		if new_ones > 0:
			awareness.add(districts.district_of(i), A.complaint_awareness * new_ones)
		if after >= A.condemn_at and _index < 0:
			condemn(i)


func _tend(step: float) -> void:
	_left -= step
	if is_instance_valid(_notice) and not _notice.torn:
		_notice.set_grabbable(faith.belief_pool >= A.tear_cost)
		if _closed:
			_notice.show_line("CLOSED BY ORDER\nDept. of Buildings · %d:%02d" \
					% [int(ceili(_left) / 60.0), ceili(_left) % 60])
		else:
			_notice.show_line("NOTICE OF CONDEMNATION\nCloses in %d" % ceili(_left))
	if _left > 0.0:
		return
	if not _closed:
		_closed = true
		_left = close_seconds
		_people = population.close_building(districts.buildings[_index])
		closed.emit(_index)
	else:
		_reopen(false)


func _on_torn() -> void:
	if not faith.spend(A.tear_cost):
		return
	FloatingNote.pop(self, _front_of(_index) + Vector3.UP * 4.0,
			A.quip(randi()), Color(1.0, 0.95, 0.7))
	_reopen(true)


func _reopen(torn: bool) -> void:
	var index := _index
	if _closed and districts.buildings[index]:
		population.reopen_building(districts.buildings[index], _people)
	if is_instance_valid(_notice) and not _notice.torn:
		_notice.queue_free()
	_notice = null
	_people.clear()
	_index = -1
	_closed = false
	reopened.emit(index, torn)


## Where the notice hangs: on the building's street side, at head height of a giant.
func _front_of(index: int) -> Vector3:
	var b := districts.buildings[index]
	var size := districts.sizes[index]
	return b.global_position + Vector3(0.0, 4.0 - size.y / 2.0, size.z / 2.0 + 0.2)
