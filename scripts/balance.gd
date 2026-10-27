class_name Balance
extends Resource
## Every tunable number for belief, witnesses, exposure and the hand's power,
## in one place (like the Balance file of Black & White 2).
## Open data/balance.tres in Godot and change values in the Inspector.
##
## Miracles don't convert: they are proof a priest preaches with. Witnesses
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
@export var prayer_rate := 0.25              # belief per second from each full believer praying in a prayer house
@export_range(0.0, 1.0) var believer_threshold := 0.5   # belief above this counts as a believer

@export_group("Stages of belief")
## Where each stage starts on the belief scale (-1..1). Below curious_from a
## person is a skeptic; believer starts at believer_threshold.
@export var curious_from := -0.2
@export var sympathizer_from := 0.15
@export var zealot_from := 0.85
## Every push toward belief (any route) is multiplied by this: the one knob for how fast the cult grows.
@export var persuasion_scale := 0.6

@export_group("Drift")
## Belief per second sliding back toward what a person believed before the
## cult, unless their friends or their building hold it up.
@export var belief_decay := 0.0008
## Belief per second pulled up toward close friends who believe more.
@export var contagion_rate := 0.0015
