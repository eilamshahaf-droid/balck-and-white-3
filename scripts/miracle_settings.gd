class_name MiracleSettings
extends Resource
## Every tunable number for the miracles.
## Open data/miracles.tres in Godot and change values in the Inspector.
##
## Each miracle has the belief formula's inputs (see balance.gd): intensity I,
## situation S for people who only watch, and deniability (how easy it is to
## explain without a god). People a miracle actually helps always read it
## with balance.tres's helped_situation.

## The miracles on the wheel. Eilam, 2026-11-12: a miracle never touches a building, so
## fire and roaches (which empty one) are off it until the new list of miracles is chosen.
@export var offered := PackedStringArray(["water", "money", "party", "frogs"])
@export_group("Miracle power: believers near the spot")
@export var power_radius := 70.0             # metres: believers this close lend the miracle their faith
@export var full_power_belief := 6.0         # believers that close for full power
@export var weak_size := 0.6                 # radius of a miracle cast with no believers near...
@export var strong_size := 1.6               # ...and at full power
@export var weak_time := 0.7                 # how long it lasts, the same way
@export var strong_time := 1.5
@export var weak_cost := 1.6                 # cost multiplier: dearer among skeptics...
@export var strong_cost := 0.7               # ...cheaper among your own
@export var power_update := 0.25             # seconds between updates of the power under the hand

@export_group("Proof: what a miracle leaves for the preachers")
## A miracle converts nobody; it leaves proof where it landed, and a preacher's
## chance there is (1 + proof) times as high while it lasts.
@export var proof_time := 60.0               # seconds the proof takes to fade away
@export var proof_radius := 40.0             # metres around the miracle, at size 1
## Each miracle that landed near here in the last proof_memory seconds makes
## the next one's proof this many times as strong (less and less).
@export_range(0.0, 1.0) var proof_saturation := 0.6
@export var proof_memory := 180.0
## Casting the same miracle again soon: each recent cast adds this to its cost
## (0.5 = +50%); a cast is forgotten over repeat_memory seconds.
@export var repeat_cost_step := 0.5
@export var repeat_memory := 120.0


@export_group("Water: a cloud rains on one spot")
@export var water_cost := 60.0               # belief; miracles are dear, to be used deliberately
@export var water_intensity := 0.8
@export_range(0.0, 1.0) var water_deniability := 0.35   # rain from a clear sky: odd, but people try
@export var rain_time := 6.0
@export var rain_radius := 8.0
@export var rain_seen_from := 90.0           # metres: a cloud from a clear sky is seen from far off
@export var douse_rate := 0.35               # fire heat put out per second under the rain
@export var water_proof := 0.2
@export var water_cooldown := 5.0

@export_group("Roaches: a building's residents flee")
@export var roach_time := 8.0                # seconds the swarm crawls over the walls
@export var roach_count := 300

@export_group("Money from the sky: banknotes rain on one spot")
@export var money_cost := 90.0
@export var money_amount := 150.0            # money your believers pick up and hand in, at full power
@export var money_weak_share := 0.3          # share of it they hand in with no believers near
@export var money_intensity := 0.8
@export_range(-1.0, 1.0) var money_situation := 0.7
@export_range(0.0, 1.0) var money_deniability := 0.2   # "an armoured truck lost its doors"
@export var money_radius := 9.0
## Over a building that is yours the notes bring this many times the money.
@export var money_own_multiplier := 2.0
@export var money_time := 6.0
@export var money_seen_from := 80.0
@export var money_proof := 0.3
@export var money_cooldown := 45.0

@export_group("Block Party: a disco ball, and the street dances")
@export var party_cost := 70.0
@export var party_intensity := 0.7
@export_range(-1.0, 1.0) var party_situation := 0.7     # who doesn't like a party
@export_range(0.0, 1.0) var party_deniability := 0.5   # "just a flash mob"
@export var party_radius := 24.0             # people this close drop everything and dance
@export var party_time := 14.0               # seconds the party lasts
@export var party_dancers := 30              # most people who join, at full size
@export var party_lines: Array[String] = ["Woo!", "This is my song!",
		"Is this a cult? Who cares!", "Who brought the disco ball?", "I have work tomorrow!"]
@export var party_seen_from := 70.0
@export var party_proof := 0.8
@export var party_cooldown := 30.0

@export_group("Rain of Frogs: chaos, and nobody knows what it means")
@export var frog_cost := 60.0
@export var frog_intensity := 0.9
@export_range(-1.0, 1.0) var frog_situation_min := -0.7  # each onlooker takes it somewhere in here:
@export_range(-1.0, 1.0) var frog_situation_max := 0.8   # a sign, or a reason to leave town
@export_range(0.0, 1.0) var frog_deniability := 0.25    # "a tornado picked them up from a lake"
@export var frog_radius := 16.0
@export var frog_time := 9.0
@export var frog_count := 220
@export_range(0.0, 1.0) var frog_knock_chance := 0.3    # people hit by a frog and knocked down
@export var frog_push := 5.0                 # how hard a frog knocks someone over (m/s)
@export var frog_seen_from := 90.0
@export var frog_gather_radius := 40.0       # people this close come to gawk...
@export var frog_gawkers := 25               # ...at most this many, at size 1
@export var frog_lines: Array[String] = ["Frogs?!", "It's raining FROGS.", "Is this the end?",
		"I'm filming this.", "Somebody call the zoo."]
## Proof the frogs leave, between these: as random as the city's reading of them.
@export var frog_proof_min := -0.6
@export var frog_proof_max := 1.0
@export var frog_cooldown := 40.0

@export_group("High priest marker: so you can find him")
@export var priest_ring_radius := 2.2        # metres, the ring on the ground around him
@export var priest_ring_color := Color(1.0, 0.85, 0.3)
@export var priest_label_pixel := 0.0011
@export var priest_label_height := 4.5       # metres above his feet

@export_group("Floating notes: who just came to believe")
@export var notes_per_second := 4.0          # at most this many "+ Believer" notes at once


func is_offered(kind: StringName) -> bool:
	return offered.has(String(kind))
