class_name Fragility
extends Node
## A thin line gives way: a building of yours with hardly any of yours next to it
## may be lost, more often the more aware its district is and the hotter it runs
## with the police. Half its believers stop believing, so it has to be won again.

## Building `index` was lost.
signal lost(index: int)

const A: AwarenessSettings = preload("res://data/awareness.tres")

@export var districts: Districts
@export var population: Population
@export var awareness: Awareness
@export var heat: Heat

var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 23


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = A.tick
	for i in districts.buildings.size():
		if is_exposed(i) and _rng.randf() < chance_per_minute(i) * A.tick / 60.0:
			crumble(i)


## Building `index` is yours, not the headquarters or a core, not in a complete block,
## and has at most fragile_neighbours of yours next to it.
func is_exposed(index: int) -> bool:
	var b := districts.buildings[index]
	if b == null or not districts.is_yours(index) or index == districts.headquarters \
			or districts.is_core(b) or districts.in_complete_block(index):
		return false
	return awareness.held_neighbours(index) <= A.fragile_neighbours


func chance_per_minute(index: int) -> float:
	var b := districts.buildings[index]
	var d := districts.district_of(index)
	return A.fragility_per_minute \
			* (awareness.level(d) + heat.heat_of(b) / A.fragility_heat_scale)


## Lose building `index` now: revert_share of the plain believers who live there stop
## believing, and anyone sitting in goes home.
func crumble(index: int) -> void:
	var b := districts.buildings[index]
	population.revert_believers(b, A.revert_share)
	districts.lose(index)
	lost.emit(index)
