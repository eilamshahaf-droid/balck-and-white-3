class_name Balance
extends Resource
## Every tunable number for miracle witnesses, exposure and the belief pool's start.
## Open data/balance.tres in Godot and change values in the Inspector.
##
## Miracles don't convert: they are proof a preacher works with. Witnesses
## stop to stare, and some film it.

@export_group("Miracles: situation S")
@export_range(-1.0, 1.0) var spectacle_situation := 0.5    # watching something harmless and strange

@export_group("Situation of the helped")
@export var helped_situation := 1.0          # S for someone the miracle actually helped

@export_group("Witnesses")
@export var witness_radius := 35.0           # how far people see miracles (needs a clear line of sight)
@export var witness_interval := 0.25         # seconds between witness checks
@export var look_time := 2.5                 # seconds a witness stops and stares
@export_range(0.0, 1.0) var phone_chance := 0.75     # share of people who film what they see

@export_group("Exposure")
@export var exposure_per_video := 0.02       # per filming witness, times the miracle's intensity
@export var exposure_decay := 0.0005         # per second, as the news moves on

@export_group("Belief (the resource)")
@export var belief_start := 100.0            # belief in the pool when the game starts
