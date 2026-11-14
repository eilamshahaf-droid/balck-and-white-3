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
## The column the staircase runs up, ground to roof: nothing fits over it.
var stairs := 0
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
		if not is_free(cell):
			return false
		grounded = grounded or cell.y == 0
	if kind.ground_only and not grounded:
		return false
	return kind.needs_next == &"" or touches(kind.turned(turns), origin, kind.needs_next)


## `cell` is inside the grid, off the stairs and has no room in it.
func is_free(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows \
			and cell.x != stairs and piece_at(cell) == null


## Would `cells` placed at `origin` share a side with a room of kind `id`. The stairs
## don't come between: rooms on either side of them are next to each other.
func touches(cells: Array[Vector2i], origin: Vector2i, id: StringName) -> bool:
	for c in cells:
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := origin + c + step
			if next.x == stairs:
				next += step
			var other := piece_at(next)
			if other and other.kind.id == id:
				return true
	return false


## The rooms that need `piece` beside them and have no other of its kind to lean on.
func leaning_on(piece: Piece) -> Array[Piece]:
	var out: Array[Piece] = []
	pieces.erase(piece)
	for p in pieces:
		if p.kind.needs_next == piece.kind.id and not touches(p.kind.turned(p.turns), p.origin, piece.kind.id):
			out.append(p)
	pieces.append(piece)
	return out


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
	return (columns - 1) * rows - used
