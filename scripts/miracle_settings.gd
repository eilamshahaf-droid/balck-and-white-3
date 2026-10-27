class_name MiracleSettings
extends Resource
## Every tunable number for the miracles, accidents and the divine signs.
## Open data/miracles.tres in Godot and change values in the Inspector.
##
## Each miracle has the belief formula's inputs (see balance.gd): intensity I,
## situation S for people who only watch, and deniability (how easy it is to
## explain without a god). People a miracle actually helps always read it
## with balance.tres's helped_situation.

@export_group("Miracle power: believers near the spot")
@export var power_radius := 70.0             # metres: believers this close lend the miracle their faith
@export var full_power_belief := 6.0         # summed belief of those believers for full power
@export var weak_size := 0.6                 # radius of a miracle cast with no believers near...
@export var strong_size := 1.6               # ...and at full power
@export var weak_time := 0.7                 # how long it lasts, the same way
@export var strong_time := 1.5
@export var weak_cost := 1.6                 # cost multiplier: dearer among skeptics...
@export var strong_cost := 0.7               # ...cheaper among your own
@export var power_update := 0.25             # seconds between updates of the power under the hand

@export_group("Proof: what a miracle leaves for the priests")
## A miracle converts nobody; it leaves proof where it landed, and priests there
## persuade (1 + proof) times as well while it lasts.
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

@export_group("Fire: a building, or the street, catches fire")
@export var fire_cost := 50.0
@export var fire_intensity := 0.7
@export_range(-1.0, 1.0) var fire_situation := -0.5     # watching a building burn
@export_range(0.0, 1.0) var fire_deniability := 0.6     # buildings do catch fire
@export var fire_burn_time := 60.0           # seconds until a burning building is lost (water saves it before)
@export var street_fire_size := 3.0          # metres across, for a fire on the street
@export var fire_seen_from := 80.0
@export var fire_proof := 0.2
@export var fire_scare := 0.6                # fear the residents of a burning building feel
@export var fire_cooldown := 20.0

@export_group("Roaches: a building's residents flee")
@export var roach_cost := 70.0
@export var roach_intensity := 0.6
@export_range(-1.0, 1.0) var roach_situation := -0.4   # disgusting, even to watch
@export_range(0.0, 1.0) var roach_deniability := 0.7   # old buildings do have roaches
@export var roach_time := 8.0                # seconds the swarm crawls over the walls
@export var roach_count := 300
@export var roach_seen_from := 40.0
@export var roach_proof := 0.0               # nobody thanks a god for roaches
@export var roach_scare := 1.0               # fear the residents of the building feel
@export var roach_cooldown := 30.0

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
## Every building under the frogs, yours too, may be overrun and emptied.
@export_range(0.0, 1.0) var frog_overrun_chance := 0.3
@export var frog_seen_from := 90.0
@export var frog_gather_radius := 40.0       # people this close come to gawk...
@export var frog_gawkers := 25               # ...at most this many, at size 1
@export var frog_lines: Array[String] = ["Frogs?!", "It's raining FROGS.", "Is this the end?",
		"I'm filming this.", "Somebody call the zoo."]
## Proof the frogs leave, between these: as random as the city's reading of them.
@export var frog_proof_min := -0.6
@export var frog_proof_max := 1.0
@export var frog_cooldown := 40.0
## Chance that the frogs wreck a police roadblock within their reach.
@export_range(0.0, 1.0) var frog_roadblock_chance := 0.7

@export_group("Accidents: believers set their own buildings on fire")
@export var accident_interval := 240.0       # seconds between chances of an accident
@export_range(0.0, 1.0) var accident_chance := 0.15
@export var accident_use_weight := 3.0       # how much likelier a Prayer House or Course Center burns
@export var accident_zealot_radius := 20.0   # each zealot this close makes a building likelier to burn
@export var accident_burn_time := 35.0       # seconds to put it out before the building is lost
@export var accident_lines: Array[String] = ["Who left the candles on?",
		"The incense! THE INCENSE!", "It was a very moving sermon.", "Fire is a sign, right? RIGHT?"]

@export_group("Saved from the fire: water puts out a burning building")
@export var saved_intensity := 1.0
@export_range(-1.0, 1.0) var saved_situation := 0.8     # the god saved our home
@export_range(0.0, 1.0) var saved_deniability := 0.2   # rain on exactly one burning building
@export var saved_seen_from := 60.0
@export var saved_proof := 1.2               # the strongest proof: the god saved their home

@export_group("Head priest marker: so you can find him")
@export var priest_ring_radius := 2.2        # metres, the ring on the ground around him
@export var priest_ring_color := Color(1.0, 0.85, 0.3)
@export var priest_label_pixel := 0.0011
@export var priest_label_height := 4.5       # metres above his feet
@export var priest_preach_mark_time := 4.0   # seconds "preaching..." stays after he talks

@export_group("Floating notes: who just came to believe")
@export var notes_per_second := 4.0          # at most this many "+ Believer" notes at once

@export_group("Divine signs on buildings")
@export var beam_height := 160.0             # metres of the beam of light above the roof
@export var cloud_flash_interval := 3.0      # seconds between flashes in the storm cloud (on average)
@export var ring_spin := 0.6                 # radians per second
