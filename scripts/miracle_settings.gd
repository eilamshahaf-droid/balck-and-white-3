class_name MiracleSettings
extends Resource
## Every tunable number for the miracles and the divine signs.
## Open data/miracles.tres in Godot and change values in the Inspector.
##
## Each miracle has the belief formula's inputs (see balance.gd): intensity I,
## situation S for people who only watch, and deniability (how easy it is to
## explain without a god). People a miracle actually helps always read it
## with balance.tres's helped_situation.

@export_group("Water: a cloud rains on one spot")
@export var water_cost := 15.0               # belief
@export var water_intensity := 0.8
@export_range(0.0, 1.0) var water_deniability := 0.35   # rain from a clear sky: odd, but people try
@export var rain_time := 6.0
@export var rain_radius := 8.0
@export var rain_seen_from := 90.0           # metres: a cloud from a clear sky is seen from far off
@export var douse_rate := 0.35               # fire heat put out per second under the rain

@export_group("Fire: a building, or the street, catches fire")
@export var fire_cost := 10.0
@export var fire_intensity := 0.7
@export_range(-1.0, 1.0) var fire_situation := -0.5     # watching a building burn
@export_range(0.0, 1.0) var fire_deniability := 0.6     # buildings do catch fire
@export var fire_burn_time := 60.0           # seconds until a miracle fire burns out by itself
@export var street_fire_size := 3.0          # metres across, for a fire on the street
@export var fire_seen_from := 80.0

@export_group("Lightning: a bolt from a clear sky")
@export var lightning_cost := 20.0
@export var lightning_intensity := 0.9
@export_range(-1.0, 1.0) var lightning_situation := -0.3   # frightening, even for those it misses
@export_range(0.0, 1.0) var lightning_deniability := 0.3
@export var lightning_radius := 6.0          # people this close are knocked off their feet
@export var lightning_push := 9.0            # how far they fly (m/s)
@export var lightning_seen_from := 150.0

@export_group("Shield: a dome nothing harmful gets through")
@export var shield_cost := 25.0
@export var shield_intensity := 0.6
@export_range(-1.0, 1.0) var shield_situation := 0.4
@export_range(0.0, 1.0) var shield_deniability := 0.1   # a glowing dome is hard to explain
@export var shield_radius := 14.0
@export var shield_time := 20.0
@export var shield_seen_from := 70.0

@export_group("Heal: golden light that mends")
@export var heal_cost := 15.0
@export var heal_intensity := 0.7
@export_range(-1.0, 1.0) var heal_situation := 0.6
@export_range(0.0, 1.0) var heal_deniability := 0.4     # "they were fine all along"
@export var heal_radius := 12.0              # knocked-down people get up, burnt buildings are rebuilt
@export var heal_time := 3.0
@export var heal_seen_from := 60.0

@export_group("Divine signs on buildings")
@export var sign_cost := 3.0                 # belief; clearing a sign is free
@export var sign_exposure := 0.01            # everyone sees the sky
@export var sign_reach := 220.0              # believers this close to a signed building answer it
@export var followers_per_sign := 6
@export var errand_time := 30.0              # seconds a believer stays at the building before going home
@export var recruit_interval := 2.0          # seconds between sending more believers
@export_range(0.0, 1.0) var unsure_belief := 0.7    # believers below this belief sometimes misread a sign
@export_range(0.0, 1.0) var misread_chance := 0.15
@export var worship_belief := 0.4            # belief per second from each believer praying at a blessed building
@export var vandal_time := 12.0              # seconds two or more vandals need to set a cursed building alight (evil path)
@export var vandal_exposure := 0.05          # a building torched by your believers draws attention
@export var guard_douse := 0.06              # fire heat each guard of a protected building puts out per second
@export var beam_height := 160.0             # metres of the beam of light above the roof
@export var cloud_flash_interval := 3.0      # seconds between flashes in the storm cloud (on average)
@export var ring_spin := 0.6                 # radians per second
