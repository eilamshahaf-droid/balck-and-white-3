class_name BuildingLayout
extends RefCounted
## The rooms fitted into one building: a grid of bays (columns) and floors (rows, 0 is
## the ground floor) and the pieces placed on it. A cell with no piece is a plain flat.
## Pure data: Rooms owns one per building of yours.

## One room on the grid.
class Piece:
	var kind: RoomKind
	var origin := Vector2i.ZERO
	var turns := 0

	func cells() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for c in kind.turned(turns):
			out.append(origin + c)
		return out


var columns := 0
var rows := 0
var pieces: Array[Piece] = []


## The piece covering `cell`, or null.
func piece_at(cell: Vector2i) -> Piece:
	for p in pieces:
		if p.cells().has(cell):
			return p
	return null


## Could `kind`, turned `turns`, go with its corner at `origin`: inside the grid, on free
## cells, and on the ground floor if it must be.
func fits(kind: RoomKind, origin: Vector2i, turns: int) -> bool:
	var grounded := false
	for c in kind.turned(turns):
		var cell := origin + c
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows or piece_at(cell):
			return false
		grounded = grounded or cell.y == 0
	return grounded or not kind.ground_only


func add(kind: RoomKind, origin: Vector2i, turns: int) -> Piece:
	var p := Piece.new()
	p.kind = kind
	p.origin = origin
	p.turns = turns
	pieces.append(p)
	return p


## Cells with no room in them.
func free_cells() -> int:
	var used := 0
	for p in pieces:
		used += p.kind.cells.size()
	return columns * rows - used
