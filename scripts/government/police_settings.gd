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
@export var roadblock_time := 90.0          # seconds the street stays closed
@export var barrier_color := Color(0.95, 0.95, 0.95)
@export var stripe_color := Color(0.9, 0.2, 0.15)
@export var car_color := Color(0.15, 0.25, 0.6)
@export var closed_street_color := Color(0.9, 0.2, 0.15, 0.45)   # the shut stretch of street
@export var dented_color := Color(0.55, 0.5, 0.45)

@export_group("Breaking a roadblock")
@export var roadblock_hp := 100.0
@export var break_speed := 6.0              # a thrown taxi or crate this fast hurts it
@export var throw_damage := 4.0             # times the speed
@export var fire_radius := 8.0
@export var fire_damage := 10.0             # per second, while a fire burns near it
@export var crowd_size := 4                 # believers at the building that push through
@export var crowd_damage := 1.5             # per believer, per second
@export var wreck_tilt := 18.0              # degrees the barriers lean per damage stage
@export var break_heat := 2.0               # heat (times a crowd's) a smashed roadblock raises
@export var label_size := 0.008             # world size of one label pixel
@export var closed_half_length := 14.0     # barriers stand this far either side of the building's front

@export_group("Arresting the priest")
@export var officers := 4                   # in the squad
@export var ring_radius := 2.0              # metres from the priest
@export var arrest_time := 40.0             # seconds before he is taken
@export var arrest_tick := 0.25             # seconds between looks at the squad
@export var free_distance := 6.0            # officers farther than this from him no longer hold him
@export var officer_mass := 1.0
@export var scatter_impulse := 6.0          # what a miracle throws an officer with
@export var uniform_color := Color(0.15, 0.25, 0.6)
@export var skin_color := Color(0.9, 0.72, 0.6)
