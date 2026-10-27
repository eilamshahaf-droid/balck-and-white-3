class_name CampaignSettings
extends Resource
## Tunables for the three ways to take a building (campaigns.gd). Open
## data/campaigns.tres in Godot and change values in the Inspector.

@export var tick := 0.5                     # seconds between steps of every campaign
@export var line_color := Color(1.0, 0.85, 0.3)

@export_group("Force (skull)")
## The Change Use that trains fighters; you need one building with it.
@export var training_use := "Combat Training"
@export var fighters := 4                   # believers sent at once
@export var force_interval := 6.0           # seconds between residents scared out
@export var force_exposure := 0.03          # exposure per resident scared out: the police notice
@export var fighter_line := "Out! This floor belongs to the Hand."

@export_group("Buy (dollar)")
@export var buyers := 1
@export var apartment_price := 80.0         # money per resident bought out
@export var buy_interval := 5.0
@export var buyer_line := "Cash offer. Today only."

@export_group("Missionaries (sky sign)")
@export var missionaries := 3
@export var preach_interval := 3.0          # seconds between sermons
@export var preach_strength := 0.25         # belief a sermon adds, before skepticism
@export var preach_cost := 4.0              # belief per sermon
@export var missionary_line := "Have you heard about the Hand?"
