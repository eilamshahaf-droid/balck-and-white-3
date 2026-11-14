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
## Followers a cell with no room in it houses (a plain flat).
@export var followers_per_cell := 1

@export_group("Stores")
## What can be kept with no Archive and no Vault.
@export var base_paperwork_cap := 150.0
@export var base_money_cap := 1200.0
## The share of a room's money that comes back when it is taken out.
@export_range(0.0, 1.0) var refund_share := 0.5
## The rooms the main Office opens with: kind id, column, row, quarter turns.
@export var office_start: Array[String] = ["desks 0 0 0", "shop 2 0 0"]

@export_group("Editor")
@export var cell_pixels := 76.0
@export var flat_color := Color(0.32, 0.34, 0.42)
@export var grid_color := Color(0.1, 0.1, 0.14)
@export var ok_color := Color(0.4, 1.0, 0.5, 0.55)
@export var bad_color := Color(1.0, 0.3, 0.3, 0.55)
@export var backdrop_color := Color(0.06, 0.06, 0.09, 0.95)
@export var outline_color := Color(0.04, 0.04, 0.06)
@export var outline_width := 3.0


func kind(id: StringName) -> RoomKind:
	for k in kinds:
		if k.id == id:
			return k
	return null
