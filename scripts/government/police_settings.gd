class_name PoliceSettings
extends Resource
## Tunables for the police (police.gd). Open data/police.tres in Godot and
## change values in the Inspector. Heat builds at a marked building while the
## cult's crew works it; a lot of heat brings a roadblock.

@export var check_interval := 1.0           # seconds between looks
@export var heat_per_crew := 1.0            # per second, per crew member at the building
@export var heat_per_doubter := 0.15        # per second, per non-believer living there, while a crew works
@export var force_multiplier := 2.5         # fighters scaring people out draw much more
@export var exposure_multiplier := 2.0      # heat times (1 + exposure * this)
@export var heat_decay := 1.0               # per second, where nothing happens
@export var roadblock_heat := 60.0
@export var roadblock_time := 45.0          # seconds the street stays closed
@export var barrier_color := Color(0.95, 0.95, 0.95)
@export var stripe_color := Color(0.9, 0.2, 0.15)
@export var car_color := Color(0.15, 0.25, 0.6)
