class_name Awareness
extends Node
## How much each district has noticed the cult, 0..1. Working one building over and
## over (a thin line) raises it; a broad, well-joined front lets it fade. It makes
## converting harder there, and Fragility and Condemnation feed on it. Near a
## Vandalist's arrest people side with the martyr for a while.

signal changed(district: int, level: float)

const A: AwarenessSettings = preload("res://data/awareness.tres")
const DS: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts
@export var population: Population
@export var landmarks: Landmarks

var _level := PackedFloat32Array()
var _spike_left := PackedFloat32Array()   # seconds of full awareness after a core attempt
var _spiked := PackedByteArray()          # a district's core spike happens once
var _attempts: Dictionary = {}            # building index -> recent attempts (fading)
var _martyrs: Array[Martyr] = []
var _timer := 0.0


class Martyr:
	var near: Dictionary = {}   # building index -> true
	var left := 0.0


func _ready() -> void:
	districts.layout_ready.connect(_on_layout_ready, CONNECT_ONE_SHOT)
	districts.block_changed.connect(_on_block_changed)
	population.preaching.preached.connect(_on_preached)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or _level.is_empty():
		return
	_timer = A.tick
	_fade_attempts()
	for m in _martyrs.duplicate():
		m.left -= A.tick
		if m.left <= 0.0:
			_martyrs.erase(m)
	var most := PackedFloat32Array()
	var total := PackedFloat32Array()
	most.resize(_level.size())
	total.resize(_level.size())
	for i: int in _attempts:
		var d := districts.district_of(i)
		if d < 0:
			continue
		total[d] += _attempts[i]
		most[d] = maxf(most[d], _attempts[i])
	var minutes := A.tick / 60.0
	for d in _level.size():
		_spike_left[d] = maxf(_spike_left[d] - A.tick, 0.0)
		var grow := A.rate * most[d] / total[d] if total[d] > 0.0 else 0.0
		var fade := A.decay * (A.decay_floor + joined_share(d)) * _level[d]
		_set_level(d, _level[d] + (grow - fade) * minutes)


## How aware district `d` is (1 while a core spike lasts).
func level(d: int) -> float:
	if d < 0 or d >= _level.size():
		return 0.0
	return 1.0 if _spike_left[d] > 0.0 else _level[d]


## Something the neighbours notice in district `d` (a mural, a complaint, an arrest).
func add(d: int, amount: float) -> void:
	if d >= 0 and d < _level.size():
		_set_level(d, _level[d] + amount)


## What converting someone who lives in `home` is multiplied by: awareness makes it
## harder (less so at a core your buildings shield), a martyr nearby easier, and at a
## core every landmark mark easier.
func factor_for(home: Node3D) -> float:
	var i := districts.index_of(home)
	if i < 0:
		return 1.0
	var d := districts.district_of(i)
	var hit := A.effect * level(d)
	if districts.is_core(home):
		hit *= 1.0 - A.protection_max * minf(1.0,
				float(held_neighbours(i)) / maxi(A.protection_neighbours, 1))
	var out := maxf(A.effect_min, 1.0 - hit)
	if districts.is_core(home) and landmarks:
		out *= landmarks.core_ease(d)
	for m in _martyrs:
		if m.near.has(i):
			return out * A.martyr_bonus
	return out


## People near `building` side with an arrested martyr for a while.
func add_martyr(building: Node3D) -> void:
	var i := districts.index_of(building)
	if i < 0:
		return
	var m := Martyr.new()
	m.left = A.martyr_minutes * 60.0
	m.near[i] = true
	for j in districts.around(i, A.martyr_steps):
		m.near[j] = true
	_martyrs.append(m)
	add(districts.district_of(i), A.arrest_awareness)


## How many buildings of yours stand next to building `index`.
func held_neighbours(index: int) -> int:
	var n := 0
	for j in districts.borders_of(index):
		if districts.is_yours(j):
			n += 1
	return n


## The share of your buildings in district `d` with at least two of yours next to them.
func joined_share(d: int) -> float:
	var held := 0
	var joined := 0
	for i in districts.buildings.size():
		if districts.district_of(i) == d and districts.is_yours(i):
			held += 1
			if held_neighbours(i) >= 2:
				joined += 1
	return float(joined) / held if held > 0 else 0.0


## A block that is all yours settles the neighbourhood a little.
func _on_block_changed(block: int, complete: bool) -> void:
	if complete:
		var first := districts.block_members(block)[0]
		add(districts.district_of(first), -DS.block_awareness_drop)


func _on_layout_ready() -> void:
	var count := districts.district_count()
	_level.resize(count)
	_spike_left.resize(count)
	_spiked.resize(count)


func _on_preached(_preacher: Resident, target: Resident, _converted: bool) -> void:
	var i := districts.index_of(target.home)
	if i < 0:
		return
	_attempts[i] = _attempts.get(i, 0.0) + 1.0
	var d := districts.district_of(i)
	if districts.is_core(target.home) and not districts.is_yours(i) and _spiked[d] == 0:
		_spiked[d] = 1
		_spike_left[d] = A.core_spike_minutes * 60.0


func _fade_attempts() -> void:
	var keep := exp(-A.tick / A.attempt_window)
	for i: int in _attempts.keys():
		_attempts[i] *= keep
		if _attempts[i] < 0.01:
			_attempts.erase(i)


func _set_level(d: int, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	if is_equal_approx(v, _level[d]):
		_level[d] = v
		return
	_level[d] = v
	changed.emit(d, v)
