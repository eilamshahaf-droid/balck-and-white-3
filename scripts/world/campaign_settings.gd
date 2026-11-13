class_name CampaignSettings
extends Resource
## Tunables for taking a building (campaigns.gd). Open data/campaigns.tres in Godot and
## change values in the Inspector.

@export var tick := 0.5                     # seconds between steps
@export var line_color := Color(1.0, 0.85, 0.3)
## The mark over a building shrinks as the camera comes in: full size from this far away...
@export var mark_far_distance := 160.0
## ...down to this share of it, up close.
@export_range(0.05, 1.0) var mark_min_scale := 0.25

@export_group("Reps at the door")
## Seconds one Rep takes to fill an ordinary building's meter.
@export var rep_seconds := 60.0
## Room for followers in an ordinary building; a bigger one takes longer in proportion,
## within these limits.
@export var ordinary_room := 12.0
@export var size_factor_min := 0.5
@export var size_factor_max := 3.0
@export var missionary_line := "Have you got a minute for the Committee?"
