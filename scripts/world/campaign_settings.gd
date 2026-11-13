class_name CampaignSettings
extends Resource
## Tunables for the three ways to take a building (campaigns.gd). Open
## data/campaigns.tres in Godot and change values in the Inspector.

@export var tick := 0.5                     # seconds between steps of every campaign
@export var line_color := Color(1.0, 0.85, 0.3)
## The marks shrink as the camera comes in: full size from this far away...
@export var mark_far_distance := 160.0
## ...down to this share of it, up close.
@export_range(0.05, 1.0) var mark_min_scale := 0.25

@export_group("Force (skull)")
## The Change Use that trains fighters; you need one building with it.
@export var training_use := "Combat Training"
@export var fighters := 4                   # believers sent at once
@export var max_fighters := 12              # with a gym's holy warriors added
@export var force_interval := 6.0           # seconds between pushes
@export_range(0.0, 1.0) var force_meter := 0.25   # of a full meter per push
@export var force_exposure := 0.03          # exposure per push: the police notice
@export var fighter_line := "Out! This floor belongs to the Hand."

@export_group("Buy (dollar)")
@export var buyers := 1
@export var apartment_price := 80.0         # money per payment
@export var buy_interval := 5.0
@export_range(0.0, 1.0) var buy_meter := 0.2      # of a full meter per payment
@export var buyer_line := "Cash offer. Today only."

@export_group("Reps (sky sign)")
## Seconds one rep takes to fill an ordinary building's meter, at full pace.
@export var rep_seconds := 60.0
@export var missionary_line := "Have you got a minute for the Committee?"
