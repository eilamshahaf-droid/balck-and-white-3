class_name HeatSettings
extends Resource
## Every number behind the police's hidden criteria (heat.gd).
## Open data/heat.tres in Godot and change values in the Inspector.

@export_group("When the police step in")
## Heat a building can take before the police step in.
@export var police_threshold := 10.0
## How much tougher a hard district is: the threshold is multiplied by
## 1 + hardness_scale * hardness (hardness 0 .. 1, set per building).
@export var hardness_scale := 1.5
## Heat lost per second as things calm down.
@export var decay := 0.05
## Seconds after a call before the same building can call the police again.
@export var cooldown := 60.0
## Seconds between checks.
@export var tick := 1.0

@export_group("What raises heat")
## A believer sitting in on the building.
@export var sit_in := 1.5
## Per non-believer in a crowd a priest draws there.
@export var crowd := 0.3
## Per breach of the building rules (a floor over the limit, a change of use).
@export var code_breach := 4.0
## An accident (a fire a zealot started).
@export var accident := 5.0
