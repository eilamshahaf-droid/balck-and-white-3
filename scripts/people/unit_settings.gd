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
	"Resident", "Member", "Rep", "Clerk", "Fixer", "Secretary",
])
## The same, in the plural (the HUD's captions).
@export var rank_plurals := PackedStringArray([
	"Residents", "Members", "Reps", "Clerks", "Fixers", "Secretaries",
])
## Body colour per rank, same order (a resident keeps their own colour).
@export var rank_colors := PackedColorArray([
	Color.WHITE, Color(1.0, 0.78, 0.15), Color(1.0, 0.5, 0.2), Color(0.95, 0.95, 1.0),
	Color(0.3, 0.3, 0.35), Color(1.0, 1.0, 1.0),
])
## Charisma per rank (scales converting), same order.
@export var rank_charisma := PackedFloat32Array([0.0, 0.0, 0.2, 0.2, 0.2, 0.8])

@export_group("Converting")
@export_range(0.0, 1.0) var anxiety_weight := 0.5
@export var charisma_weight := 0.3
## Seconds between the rounds of a street meeting.
@export var attempt_interval := 20.0
@export_group("Winning people over without being asked")
@export var spread_low := 0.3
@export var spread_high := 1.5
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

@export_group("Training")
## Seconds in a sermon house to train a believer into a missionary, and a
## missionary into a priest (the priest only where the high priest serves).
@export var missionary_time := 90.0
@export var priest_cost_growth := 0.25
## The special agent (in the Slums the Vandalist): trained from a believer at the
## cult's base, this long, for this much money, so many at once.
@export var agent_time := 120.0


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
