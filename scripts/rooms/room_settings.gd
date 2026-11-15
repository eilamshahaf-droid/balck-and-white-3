class_name RoomSettings
extends Resource
## Every number of the rooms inside buildings: the grid, the kinds of room, the stores
## with no room built, and the editor's look. Load with load(): its array is typed.

@export var kinds: Array[RoomKind] = []

@export_group("The grid")
## A building has one column for every this many metres of front, and one row a floor.
@export var bay_width := 4.0
@export var floor_height := 3.2
@export var min_columns := 2
@export var max_columns := 7
@export var min_rows := 2
@export var max_rows := 12
## The highest tier of room this stage offers (the Slums teach with the basic ones).
@export var max_tier := 0
## Every building has a staircase, one place on every floor, that climbs this many
## floors in one column before it changes column.
@export var stairs_flight := 2
@export var stairs_color := Color(0.2, 0.2, 0.24)
@export var stairs_line_color := Color(0.6, 0.6, 0.66)
## The main Office is raised to at least this many floors when the game starts, so the
## heart of the Committee has room to plan in.
@export var office_min_rows := 6
## Followers a cell with no room in it houses (a plain flat).
@export var followers_per_cell := 1
## Each room already bought in a building makes the next one there this much dearer
## (0.25: the second costs 1.25 times its price, the third 1.5 times).
@export var price_step := 0.25
## Rooms whose price never rises: the Office's key rooms, which could otherwise pass the
## purse and never be bought.
@export var price_step_exempt: Array[StringName] = [&"training", &"archive", &"vault"]
## The Office's first this many rooms bought don't raise the price of the next: the
## first lesson (a Shop, a Desk Room, two homes) costs what the purse holds.
@export var office_steady_rooms := 4

@export_group("Upkeep")
## Seconds between rounds of reopening rooms that closed for want of upkeep.
@export var upkeep_tick := 5.0
## A closed room opens again once there is this much money.
@export var reopen_money := 150.0

@export_group("Stores")
## What can be kept with no Archive and no Vault.
@export var base_paperwork_cap := 150.0
@export var base_money_cap := 600.0
## The share of a room's money that comes back when it is taken out.
@export_range(0.0, 1.0) var refund_share := 0.5
## The rooms the main Office opens with, each fitted into the first place it goes. Empty:
## the player plans the Office from the start (the first lesson).
@export var office_start: Array[StringName] = []

@export_group("Editor")
@export var cell_pixels := 76.0
@export var flat_color := Color(0.32, 0.34, 0.42)
@export var grid_color := Color(0.1, 0.1, 0.14)
@export var ok_color := Color(0.4, 1.0, 0.5, 0.55)
@export var bad_color := Color(1.0, 0.3, 0.3, 0.55)
@export var closed_shade := 0.35
@export var backdrop_color := Color(0.06, 0.06, 0.09, 0.95)
@export var outline_color := Color(0.04, 0.04, 0.06)
@export var outline_width := 3.0


func kind(id: StringName) -> RoomKind:
	for k in kinds:
		if k.id == id:
			return k
	return null
