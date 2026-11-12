class_name UnitSettings
extends Resource
## Every tunable number for the player's units (GDD sections 4 to 6): ranks,
## converting residents, what believers make, their needs, and training. Open
## data/units.tres in Godot and change values in the Inspector.

@export_group("Ranks")
## What each Resident.Rank is called in the game, in enum order: resident,
## believer, missionary, priest, special agent, high priest. Renaming the
## cult's words happens here, not in code.
@export var rank_titles := PackedStringArray([
	"Resident", "Member", "Canvasser", "Clerk", "Field Delegate", "Secretary",
])
## The same, in the plural (the HUD's captions).
@export var rank_plurals := PackedStringArray([
	"Residents", "Members", "Canvassers", "Clerks", "Field Delegates", "Secretaries",
])
## Body colour per rank, same order (a resident keeps their own colour).
@export var rank_colors := PackedColorArray([
	Color.WHITE, Color(1.0, 0.78, 0.15), Color(1.0, 0.5, 0.2), Color(0.95, 0.95, 1.0),
	Color(0.3, 0.3, 0.35), Color(1.0, 1.0, 1.0),
])
## Charisma per rank (scales converting), same order.
@export var rank_charisma := PackedFloat32Array([0.0, 0.0, 0.2, 0.2, 0.2, 0.8])

@export_group("Converting")
## Chance per attempt = base x curiosity x (1 - skepticism)
## x (1 - anxiety_weight x anxiety) x (1 + charisma_weight x charisma), times
## 1 + the miracle proof where it happens.
@export_range(0.0, 1.0) var conversion_base := 0.6
@export_range(0.0, 1.0) var anxiety_weight := 0.5
@export var charisma_weight := 0.3
## Seconds between one preacher's attempts (missionaries and the high priest).
@export var attempt_interval := 20.0
## How far a preacher reaches on the street, in metres.
@export var preach_reach := 14.0
## Every believer on the street also tries now and then, at this share of a
## preacher's attempt rate.
@export_range(0.0, 1.0) var believer_attempt_share := 0.04
## A core building's residents are this many times harder to win over. Very hard on
## purpose: landmarks marked by the Vandalist will bring it down (0.7.2).
@export var core_difficulty := 60.0

@export_group("Output per believer")
## Per believer per minute: money = this x wealth, belief = this x faith, both times
## the needs multiplier. Belief only while inside a staffed sermon house.
@export var money_per_minute := 4.0
@export var belief_per_minute := 3.0

@export_group("Seats: the soft limit on believers")
## Believers need somewhere to be: seats_base (the Branch), plus seats_per_clerk for
## every clerk (the Secretary included) and seats_per_space for every free space. There
## is no hard cap: a believer past the seats makes money_over_seats of the money and
## belief_over_seats of the belief, and the start district's awareness rises by
## awareness_over_seats a minute times the share of believers without a seat, but never
## past awareness_over_seats_max this way.
@export var seats_base := 20
@export var seats_per_clerk := 10
@export var seats_per_space := 25
@export_range(0.0, 1.0) var money_over_seats := 0.0
@export_range(0.0, 1.0) var belief_over_seats := 0.5
@export var awareness_over_seats := 0.04
@export_range(0.0, 1.0) var awareness_over_seats_max := 0.5

@export_group("Needs")
## Output multiplier with every need unmet and with every need met.
@export var multiplier_min := 0.7
@export var multiplier_max := 1.3
## Where the needs come from until their own systems exist: livelihood is the
## home's comfort, security is 1 - fear, pleasure is this, meaning is one of these.
@export_range(0.0, 1.0) var pleasure_base := 0.5
@export_range(0.0, 1.0) var meaning_free := 0.4
@export_range(0.0, 1.0) var meaning_posted := 0.8
## A believer whose livelihood is met less than this may leave the cult: this
## chance per minute.
@export_range(0.0, 1.0) var leave_below := 0.3
@export_range(0.0, 1.0) var leave_chance_per_minute := 0.2

@export_group("Training")
## Seconds in a sermon house to train a believer into a missionary, and a
## missionary into a priest (the priest only where the high priest serves).
@export var missionary_time := 90.0
@export var priest_time := 180.0
@export var max_priests := 12
## Money it costs to start training a priest; each clerk you already have makes the
## next one priest_cost_growth dearer (compounding).
@export var priest_cost := 400.0
@export var priest_cost_growth := 0.25
## The special agent (in the Slums the Vandalist): trained from a believer at the
## cult's base, this long, for this much money, so many at once.
@export var agent_time := 120.0
@export var agent_cost := 150.0
@export var max_agents := 2
## The cult needs this many believers before it can train one.
@export var agent_unlock_believers := 8


# Accessors rather than indexing the arrays from a const preload: in the editor the
# parser folds a const resource's unsaved arrays to null and rejects the index.
func title(rank: int) -> String:
	return rank_titles[rank]


func plural(rank: int) -> String:
	return rank_plurals[rank]


func color(rank: int) -> Color:
	return rank_colors[rank]


func charisma(rank: int) -> float:
	return rank_charisma[rank]
