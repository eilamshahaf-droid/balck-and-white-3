class_name AwarenessSettings
extends Resource
## How much the city notices the cult (GDD 0.7.1 brief and the Balance Tester's sim):
## district awareness, the fragility of thin lines, neighbour complaints and the
## condemnation notice, and the Vandalist's murals and arrest. Open data/awareness.tres
## in Godot and change values in the Inspector.

@export_group("Awareness")
## Per minute, awareness grows by rate x concentration: the most attempts on one
## building over all attempts (a thin line is 1, spread-out play is low).
@export var rate := 0.08
## Per minute, awareness falls by decay x (decay_floor + the share of your buildings
## with at least two of yours next to them) x awareness.
@export var decay := 0.08
@export var decay_floor := 0.3
## Seconds over which attempts are counted for the concentration.
@export var attempt_window := 60.0
## Conversion is multiplied by max(effect_min, 1 - effect x awareness).
@export var effect := 0.6
@export var effect_min := 0.2
## The first attempt on a district's core makes the whole district fully aware this long.
@export var core_spike_minutes := 10.0
## Buildings of yours next to the core shield the attempt from that: up to
## protection_max, reached at protection_neighbours of them.
@export_range(0.0, 1.0) var protection_max := 0.7
@export var protection_neighbours := 3
## Seconds between updates.
@export var tick := 1.0

@export_group("Fragility")
## Per minute, a building of yours with at most fragile_neighbours of yours next to it
## (not the headquarters or a core) is lost with chance
## per_minute x (awareness + heat / heat_scale); revert_share of its believers stop believing.
@export var fragility_per_minute := 0.02
@export var fragile_neighbours := 1
@export var fragility_heat_scale := 100.0
@export_range(0.0, 1.0) var revert_share := 0.5

@export_group("Complaints and condemnation")
## A building of yours with more than noise_at believers draws
## complaint_rate x (believers - noise_at) complaints a minute; each adds
## complaint_awareness to its district. Raising complaint_rate to 0.1 breaks the
## Slums (Balance Tester), so playtest before changing it.
@export var noise_at := 2
@export var complaint_rate := 0.05
@export var complaint_awareness := 0.03
## At this many complaints the building is condemned: a warning, then it is closed
## and emptied for close_minutes. Only one notice at a time.
@export var condemn_at := 3.0
@export var warning_seconds := 30.0
@export var close_minutes := 5.0
## Tearing the notice off with the hand costs this much belief and reopens it at once.
@export var tear_cost := 20.0
@export var notice_color := Color(1.0, 0.3, 0.25)
## What the Secretary says when the hand tears a notice off (one at random).
@export var tear_quips := PackedStringArray([
	"Secretary: \"The notice was taken down for proofreading.\"",
	"Secretary: \"Minutes note the paperwork blew away. Divinely.\"",
	"Secretary: \"City Hall will be informed. Eventually. By post.\"",
])

@export_group("Murals")
## Seconds the Vandalist paints for, where the hand sets him down.
@export var paint_seconds := 30.0
@export var paint_line := "*psssht*"
## Each mural within mural_steps borders of a believer's home adds this much pleasure.
@export var mural_pleasure := 0.15
@export var mural_steps := 2
@export var mural_awareness := 0.02
@export var mural_size := Vector2(5.0, 3.5)
@export var mural_colors := PackedColorArray([
	Color(1.0, 0.35, 0.55), Color(0.2, 0.8, 0.9), Color(1.0, 0.8, 0.15), Color(0.5, 0.9, 0.3),
])

@export_group("The neighbourhood answers")
## After each mural one answer is drawn by weight; an answer's weight grows by its
## growth each time it is drawn, so the city adapts. Same order in every array.
@export var answer_names := PackedStringArray(["Painted over", "Fined", "Camera installed"])
@export var answer_weights := PackedFloat32Array([1.0, 1.0, 1.0])
@export var answer_growth := PackedFloat32Array([0.5, 0.5, 0.5])
## Chance the answer ends in the Vandalist's arrest: about 0.1 per mural while the
## answers are equally likely (Balance Tester).
@export var answer_arrest := PackedFloat32Array([0.0, 0.15, 0.15])
@export var fine := 50.0
@export var camera_color := Color(0.15, 0.15, 0.18)
## A camera adds this to the arrest chance of murals and marks within camera_steps
## borders of it.
@export var camera_arrest := 0.1
@export var camera_steps := 2

@export_group("Arrest and martyr")
## Three ways out of an arrest: throw the squad off him with the hand (costs
## rescue_belief), pay bail_money once he is taken, or wait jail_seconds.
@export var rescue_belief := 15.0
@export var bail_money := 150.0
@export var jail_seconds := 180.0
## From the moment the squad arrives: conversion times martyr_bonus for martyr_minutes
## for anyone living within martyr_steps borders of the spot; and awareness rises.
@export var martyr_bonus := 1.3
@export var martyr_minutes := 3.0
@export var martyr_steps := 3
@export var arrest_awareness := 0.1


# Accessors rather than indexing the arrays from a const preload: in the editor the
# parser folds a const resource's unsaved arrays to null and rejects the index.
func answer_count() -> int:
	return answer_names.size()


func answer_name(i: int) -> String:
	return answer_names[i]


func answer_weight(i: int) -> float:
	return answer_weights[i]


func growth(i: int) -> float:
	return answer_growth[i]


func arrest_chance(i: int) -> float:
	return answer_arrest[i]


func quip(i: int) -> String:
	return tear_quips[i % tear_quips.size()]


func mural_color_count() -> int:
	return mural_colors.size()


func mural_color(i: int) -> Color:
	return mural_colors[i % mural_colors.size()]
