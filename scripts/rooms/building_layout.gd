class_name BuildingLayout
extends RefCounted
## The rooms fitted into one building: a grid of bays (columns) and floors (rows, 0 is
## the ground floor) and the pieces placed on it. A cell with no piece is a plain flat.
## Pure data: Rooms owns one per building of yours.

## One room on the grid.
class Piece:
	var kind: RoomKind
	var origin := Vector2i.ZERO
	## Closed for want of upkeep: it gives nothing until there is money again.
	var open := true
	## What it cost (part comes back when it is taken out); a room given at the start
	## was not bought and doesn't raise the price of the next one.
	var paid := 0.0
	var bought := true

	func cells() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for c in kind.cells:
			out.append(origin + c)
		return out


var columns := 0
var rows := 0
## The staircase: its column on every floor. It climbs two floors at a time and may
## change column between flights, so every plan goes round it. Nothing fits over it.
var stairs := PackedInt32Array()
var pieces: Array[Piece] = []


## The piece covering `cell`, or null.
func piece_at(cell: Vector2i) -> Piece:
	for p in pieces:
		if p.cells().has(cell):
			return p
	return null


## Could `kind` go with its corner at `origin`: inside the grid, on free cells, and on
## the ground floor if it must be.
func fits(kind: RoomKind, origin: Vector2i) -> bool:
	var grounded := false
	for c in kind.cells:
		var cell := origin + c
		if not is_free(cell):
			return false
		grounded = grounded or cell.y == 0
	if kind.ground_only and not grounded:
		return false
	return kind.needs_next == &"" or touches(kind.cells, origin, kind.needs_next)


## `cell` is inside the grid, off the stairs and has no room in it.
func is_free(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows \
			and not is_stairs(cell) and piece_at(cell) == null


func is_stairs(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < stairs.size() and stairs[cell.y] == cell.x


## Would `cells` placed at `origin` share a side with a room of kind `id`. The stairs
## don't come between: rooms on either side of them are next to each other.
func touches(cells: Array[Vector2i], origin: Vector2i, id: StringName) -> bool:
	for c in cells:
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := origin + c + step
			if is_stairs(next):
				next += step
			var other := piece_at(next)
			if other and other.open and other.kind.is_a(id):
				return true
	return false


## The rooms that need `piece` beside them and have no other of its kind to lean on.
func leaning_on(piece: Piece) -> Array[Piece]:
	var out: Array[Piece] = []
	pieces.erase(piece)
	for p in pieces:
		if p.kind.needs_next != &"" and piece.kind.is_a(p.kind.needs_next) \
				and not touches(p.kind.cells, p.origin, p.kind.needs_next):
			out.append(p)
	pieces.append(piece)
	return out


func add(kind: RoomKind, origin: Vector2i) -> Piece:
	var p := Piece.new()
	p.kind = kind
	p.origin = origin
	pieces.append(p)
	return p


## Cells with no room in them.
func free_cells() -> int:
	var used := 0
	for p in pieces:
		used += p.kind.cells.size()
	return columns * rows - stairs.size() - used
