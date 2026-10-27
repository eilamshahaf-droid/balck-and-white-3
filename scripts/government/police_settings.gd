class_name PoliceSettings
extends Resource
## Tunables for the police (police.gd). Open data/police.tres in Godot and
## change values in the Inspector. The crew working a marked building
## adds to its hidden Heat (heat.gd); when Heat calls the police they close the street.

@export var check_interval := 1.0           # seconds between looks
@export var doubter_share := 0.15           # each non-believer living there counts this much of a crew member
@export var force_multiplier := 2.5         # fighters scaring people out draw much more
@export var exposure_multiplier := 2.0      # load times (1 + exposure * this)
@export var hardest_wealth := 2.0           # district wealth that counts as the hardest police (hardness 1)
@export var roadblock_time := 45.0          # seconds the street stays closed
@export var roadblock_break_heat := 2.0     # crowds worth of heat when frogs wreck a roadblock
@export var barrier_color := Color(0.95, 0.95, 0.95)
@export var stripe_color := Color(0.9, 0.2, 0.15)
@export var car_color := Color(0.15, 0.25, 0.6)
