class_name FollowersSettings
extends Resource
## Tunables for followers as numbers (followers.gd): room, growth, the roles' slots, what
## a seller and a clerk bring in, the cap on Reps, and the pull on neighbours. Room and
## slots come from the rooms (data/rooms.tres).
## Open data/followers.tres in Godot and change values in the Inspector. All provisional.

@export var tick := 1.0   # seconds between rounds

@export_group("Room and growth")
## A building just taken starts with this share of its room filled.
@export_range(0.0, 1.0) var start_share := 0.5
## Followers a building gains a minute, while it has room, and how much faster in a
## complete block (the block bonus).
@export var growth_per_minute := 0.5
@export var block_growth := 0.25

@export_group("Shops: sellers")
## Money a second the first seller brings in; each further seller this share of the last.
@export var seller_income := 1.2
@export_range(0.0, 1.0) var seller_falloff := 0.7
## Money a second every seller is paid, out of the shop's own takings.
@export var seller_pay := 0.35

@export_group("Offices: clerks")
## Paperwork a second per clerk.
@export var clerk_paperwork := 0.25
## Clerks at work in all, at most: desks past this make nothing, so the Rep cap, not
## paperwork, stays the limit (the Balance Tester's sim).
@export var max_clerks := 8

@export_group("Reps")
## Reps the player may have out at once (free, at a door or in training; Managers don't
## count); every Training Room adds one.
@export var rep_cap := 2
## Paperwork and money to train a Rep, and a Fixer.
@export var rep_paperwork := 30.0
@export var rep_money := 50.0
@export var fixer_paperwork := 80.0
@export var fixer_money := 0.0
@export var fixer_cap := 1

@export_group("The pull on neighbours, inside a block")
## A building of yours raises the takeover meter of each neighbour in its own block by
## this much of a full meter a minute, times its attraction; the main Office this many
## times as hard.
@export var pull_per_minute := 0.05
@export var office_pull := 4.0
## A meter nothing holds up sinks by this much a minute.
@export var sink_per_minute := 0.05

@export_group("Upkeep of buildings")
## Money a minute every building of yours costs to keep, on top of its rooms' upkeep; a
## building in a complete block pays this share of it.
@export var building_upkeep := 4.0
@export_range(0.0, 1.0) var complete_block_upkeep_share := 0.5
## The buildings' upkeep grows with the money in hand, from nothing at $0 to all of it
## at this much (rooms always cost theirs). Above the price of a Laundry Room, so a
## Committee short of money can still save up for one.
@export var full_upkeep_at := 250.0

@export_group("The god's attention")
## The building under the hand is taken over, and trains, this many times as fast.
@export var attention := 2.0

@export_group("A loan")
## One at a time: paperwork to open it, money it gives, what is owed for it, and the
## share of the takings that pays it back.
@export var loan_paperwork := 40.0
@export var loan_money := 400.0
@export var loan_owed := 500.0
@export_range(0.0, 1.0) var loan_repay_share := 0.5
