class_name PeopleSettings
extends Resource
## Every tunable number for the city's residents: who they are, how they move.
## Open data/people.tres in Godot and change values in the Inspector.

@export_group("Population")
## Every home gets at least this many residents; the city's total is that or
## resident_count, whichever is more.
@export var min_residents_per_home := 5
@export var resident_count := 500
## One resident in this many walks the streets at a time (at least one from
## every lived-in home); the rest are indoors. Each body on the street costs
## frame time, so this is the knob for slower computers.
@export var residents_per_body := 25
## Seconds between one person going indoors and another coming out (out of view).
@export var swap_interval := 0.5
@export var groups: Array[SocialGroup] = []
@export var family_size_min := 1
@export var family_size_max := 4
## Close friends per person: the ties belief will travel along.
@export var friends_min := 2
@export var friends_max := 5
## Friends are mostly neighbours or colleagues: a home within this many metres counts as a neighbour.
@export var neighbour_radius := 120.0
## Share of friends picked from anywhere in the city instead.
@export_range(0.0, 1.0) var distant_friend_chance := 0.2
## Starting belief, before the god does anything.
@export var belief_min := -0.6
@export var belief_max := 0.2
## Buildings taller than this are glass office towers: people work there but don't live there.
@export var office_height := 60.0

@export_group("Sandbox congregation")
## Skipping the opening starts you with one congregation living around one corner.
@export var congregation_size := 14
@export var congregation_corner := Vector2i(6, 3)
@export var congregation_belief_min := 0.6
@export var congregation_belief_max := 0.95
@export var congregation_skepticism_max := 0.3

@export_group("Walking")
## How far (in metres) people wander from their home corner.
@export var home_range := 90.0
@export var walk_speed_min := 2.0
@export var walk_speed_max := 4.0
## People spread across the street instead of walking one line.
@export var lane_spread := 3.0
@export var notice_pause_min := 1.0
@export var notice_pause_max := 2.0
## Seconds between the lines a believer repeats while answering a sign.
@export var errand_line_min := 4.0
@export var errand_line_max := 7.0
## Chance to actually speak each time; with several followers at one building most stay quiet.
@export_range(0.0, 1.0) var errand_line_chance := 0.35
@export var errand_line_time := 2.5

@export_group("Occupying")
## A believer the hand sets down on a building, or this close to its walls, sits in there to claim it.
@export var occupy_reach := 3.0
## Seconds an occupant stays before going home; 0 = until the hand picks them up.
@export var occupy_time := 0.0
## Seconds between refreshes of each building's cached believing presence.
@export var presence_refresh := 0.5

@export_group("Comfort and fear")
## Comfort drifts toward a home's comfort at this rate per second. A home's
## comfort starts at its residents' average wealth; decrees and events add to it.
@export var comfort_rate := 0.01
## Fear fades by this much per second.
@export var fear_decay := 0.004
## Fear a miracle that hurt someone adds, times its intensity and how bad it was.
@export var fear_per_harm := 0.5
## A priest only reaches people at least this comfortable and at most this afraid.
@export_range(0.0, 1.0) var preach_min_comfort := 0.3
@export_range(0.0, 1.0) var preach_max_fear := 0.5
## Force works this well on someone with no fear at all (1 = as on the terrified).
@export_range(0.0, 1.0) var force_without_fear := 0.2
## Money works this well on the richest (1 = as on the poorest).
@export_range(0.0, 1.0) var money_on_rich := 0.3
## Above this fear a resident moves to another home; their fear halves.
@export_range(0.0, 1.0) var flee_fear := 0.85

@export_group("Jobs")
## Free believers can be given a post. A building takes one person per this many
## cubic metres (footprint times height), at least one, so a tower holds far
## more than a shed; priests are limited on top of that.
@export var staff_volume := 1500.0
@export var priest_slots := 2
## Comfortable staff do more: output is times 1 + this * comfort.
@export var comfort_output_bonus := 0.5
## Frightened believers fight harder: a takeover by force is times 1 + this *
## the fear of the believers there, and the police need that much more heat.
@export var fear_force_bonus := 0.5
@export var fear_defense_bonus := 1.0

@export_group("Upgrades")
## Every upgrade or added floor bought for a building costs more than the last
## one there: base * growth ^ purchases so far. Treasury charges it.
@export var upgrade_base_cost := 200.0
@export var upgrade_cost_growth := 1.5
## Elevator and roof garden raise the residents' comfort; cameras and a gate scare them.
@export_range(0.0, 1.0) var upgrade_comfort := 0.1
@export_range(0.0, 1.0) var upgrade_fear := 0.15
## Each purchase also adds this many places to the building.
@export var slots_per_purchase := 2

@export_group("Housing")
## A home holds its starting residents times this; past that it is crowded.
@export var housing_slack := 1.3
## Comfort lost at twice the capacity (scaled by how crowded the home is). Shops
## and prayer houses have no residents, so converting one crowds the homes around.
@export_range(0.0, 1.0) var crowding_penalty := 0.5

## Prayer house upgrades: each loudspeaker widens the reach of its priests, each
## lecture hall makes their preaching stronger, by this share.
@export var loudspeaker_reach := 0.25
@export var lecture_hall_strength := 0.25

@export_group("Fire")
## A building burns down with its people inside: each one indoors dies with this chance.
@export_range(0.0, 1.0) var fire_death_chance := 0.5

@export_group("Colours")
@export var believer_color := Color(1.0, 0.78, 0.15)
@export var zealot_color := Color(1.0, 0.45, 0.1)

@export_group("Priest")
## The cult's head priest, a believer from the starting congregation, walks
## the streets and preaches to everyone within reach every few seconds.
@export var priest_interval := 3.0
@export var priest_reach := 12.0
@export var priest_strength := 0.15
## Belief per second the priest prays into the pool on his own.
@export var priest_prayer := 0.02
@export var priest_color := Color(1.0, 1.0, 1.0)
## Priests are drawn this many times larger, so the crowd can pick them out.
@export var priest_scale := 1.5

@export_group("Dancing")
## People sent on an errand to dance (a block party) bob this high, this fast, and turn.
@export var dance_bob_height := 0.35
@export var dance_bob_rate := 7.0
@export var dance_spin := 2.5

@export_group("Fleeing")
## When a building is evacuated (roaches), its residents this close to it run out.
@export var flee_reach := 60.0
## How far they run before calming down, in metres, and for how long they hurry.
@export var flee_distance := 50.0
@export var flee_time := 6.0
@export var flee_speed_factor := 2.2

@export_group("Falling")
@export var gravity := 20.0
@export var hard_landing_speed := 14.0
@export var tumble_min_speed := 3.0
@export var get_up_time := 0.6
## Impact speed below which a person the hand lets go of without throwing lands on their feet.
@export var set_down_max_impact := 16.0

@export_group("Names")
@export var first_names: PackedStringArray = []
@export var last_names: PackedStringArray = []

@export_group("Debug card")
## With B on, the card shows whoever stands within this many metres of the cursor.
@export var card_pick_radius := 4.0
## Seconds between redraws of the lines to family, friends, home and work.
@export var card_refresh := 0.1
