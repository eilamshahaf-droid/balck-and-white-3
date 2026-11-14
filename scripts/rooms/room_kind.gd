class_name RoomKind
extends Resource
## One kind of room the player can fit into a building: its shape on the building's
## grid of bays and floors, what it costs, and what it gives.

@export var id := &""
@export var title := ""
## What it does, in a few words, for the palette.
@export var note := ""
@export var color := Color.WHITE
## The cells it covers, from its bottom-left corner (x across, y up).
@export var cells: Array[Vector2i] = [Vector2i.ZERO]
@export var money := 0.0
@export var paperwork := 0.0

@export_group("What it gives")
## Followers it houses (a cell with no room in it is a plain flat).
@export var followers := 0
@export var clerks := 0
@export var sellers := 0
@export var paperwork_cap := 0.0
@export var money_cap := 0.0
## Reps more that may be out at once.
@export var reps := 0
@export var attraction := 0.0
@export var security := 0

@export_group("Where it fits")
## Only in an office (today: the main Office).
@export var office_only := false
## One of its cells must be on the ground floor.
@export var ground_only := false


## Its cells turned a quarter turn `turns` times, moved back so the lowest and leftmost
## are at 0.
func turned(turns: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var low := Vector2i(1 << 20, 1 << 20)
	for cell in cells:
		var c := cell
		for t in posmod(turns, 4):
			c = Vector2i(-c.y, c.x)
		out.append(c)
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
	for k in out.size():
		out[k] -= low
	return out
