class_name Balance
extends Resource
## Every tunable number for belief, witnesses, exposure and the hand's power,
## in one place (like the Balance file of Black & White 2).
## Open data/balance.tres in Godot and change values in the Inspector.
##
## Belief change of person i after miracle m (from the design doc):
##   dB = I * S * (1 - k) * N + sigma * (friends' average belief)
## I = intensity of the miracle, S = situation (+ helped, - hurt),
## k = the person's hidden skepticism, N = novelty (drops each time they see it again).

@export_group("Miracles: situation S")
@export_range(-1.0, 1.0) var spectacle_situation := 0.5    # watching something harmless and strange

@export_group("Explanations")
## Before belief changes, each witness explains the miracle: god, chance, fraud or a plot.
@export var helped_situation := 1.0          # S for someone the miracle actually helped
@export_range(0.0, 1.0) var bystander_timing := 0.3   # how much a miracle seems "meant for me" when it wasn't
@export var fraud_weight := 0.6              # how readily skeptics call it a hoax
@export var plot_weight := 0.15              # how readily skeptics suspect someone's scheme
@export var fraud_penalty := 0.5             # belief lost (times intensity) by calling it a hoax
@export var plot_penalty := 0.2

@export_group("Witnesses")
@export var witness_radius := 35.0           # how far people see miracles (needs a clear line of sight)
@export var witness_interval := 0.25         # seconds between witness checks
@export_range(0.0, 1.0) var novelty_step := 0.5   # novelty lost each time the same kind is seen again; the third time looks like a trick
@export var novelty_floor := -0.5            # past that, repeats read as a trick and breed skepticism
@export_range(0.0, 1.0) var friends_weight := 0.05   # sigma: pull of a person's close friends
@export var look_time := 2.5                 # seconds a witness stops and stares
@export_range(0.0, 1.0) var phone_chance := 0.75     # share of people who film what they see

@export_group("Exposure")
@export var exposure_per_video := 0.02       # per filming witness, times the miracle's intensity
@export var exposure_decay := 0.0005         # per second, as the news moves on

@export_group("Belief (the resource)")
@export var belief_start := 100.0            # belief in the pool when the game starts
@export var prayer_rate := 0.25              # belief per second from each full believer's prayers
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
