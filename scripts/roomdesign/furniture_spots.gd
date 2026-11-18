class_name FurnitureSpots
extends RefCounted
## Where furniture may go in the room designer. A floor piece takes whole grid squares
## (`grid_step` metres) on lit places of its row, and no two floor pieces share a square;
## a wall piece slides along the back wall of its row; small things go anywhere. Pure
## rules on RoomDesign items, no nodes.

## How many rings of squares round the wanted spot are tried for a free one.
const SEARCH_RINGS := 16
const EPS := 0.001


static func type_of(o: RoomDesign.Item, catalog: FurnitureCatalog) -> FurnitureCatalog.Place.Type:
	return catalog.place_of(o.model).type


## Squares across and deep the turned, scaled floor piece takes.
static func squares(o: RoomDesign.Item, catalog: FurnitureCatalog) -> Vector2i:
	var step := catalog.settings.grid_step
	var f := catalog.place_of(o.model).footprint * o.scale
	if o.rot % 2 == 1:
		f = Vector2(f.y, f.x)
	return Vector2i(maxi(1, ceili(f.x / step - 0.01)), maxi(1, ceili(f.y / step - 0.01)))


## The squares it takes, in metres: x from the room's left edge, y is depth (z).
static func area(o: RoomDesign.Item, catalog: FurnitureCatalog) -> Rect2:
	var s := Vector2(squares(o, catalog)) * catalog.settings.grid_step
	return Rect2(Vector2(o.x, o.z) - s / 2.0, s)


## `v` on the grid (lines at `origin` + k `step`) for a piece `n` squares long: an odd
## length sits in the middle of a square, an even one on a line.
static func snap_axis(v: float, n: int, step: float, origin: float) -> float:
	var t := (v - origin) / step
	return origin + ((floorf(t) + 0.5) if n % 2 == 1 else roundf(t)) * step


## Whether floor piece `o` may stand where it is among `items`.
static func fits(o: RoomDesign.Item, catalog: FurnitureCatalog, kind: RoomKind,
		items: Array[RoomDesign.Item]) -> bool:
	var r := area(o, catalog)
	var half := catalog.settings.depth / 2.0
	if r.position.y < -half - EPS or r.end.y > half + EPS:
		return false
	if not _lit(o.row, r.position.x, r.end.x, catalog, kind):
		return false
	var inner := r.grow(-EPS)
	for b in items:
		if b != o and b.row == o.row and type_of(b, catalog) == FurnitureCatalog.Place.Type.FLOOR \
				and inner.intersects(area(b, catalog)):
			return false
	return true


## Floor piece `o` on the grid at (`x`, `z`) if it fits there; else it stays. True if moved.
static func move_to(o: RoomDesign.Item, x: float, z: float, catalog: FurnitureCatalog,
		kind: RoomKind, items: Array[RoomDesign.Item]) -> bool:
	var old := Vector2(o.x, o.z)
	_snap_to(o, x, z, catalog, kind)
	if fits(o, catalog, kind, items):
		o.y = 0.0
		return true
	o.x = old.x
	o.z = old.y
	return false


## Floor piece `o` on the free spot nearest where it is; false (and unmoved) when there
## is none.
static func settle(o: RoomDesign.Item, catalog: FurnitureCatalog, kind: RoomKind,
		items: Array[RoomDesign.Item]) -> bool:
	var want := Vector2(o.x, o.z)
	if move_to(o, want.x, want.y, catalog, kind, items):
		return true
	var step := catalog.settings.grid_step
	var base := Vector2(o.x, o.z)
	_snap_to(o, want.x, want.y, catalog, kind)
	var start := Vector2(o.x, o.z)
	for ring in range(1, SEARCH_RINGS + 1):
		var best := Vector2.INF
		var best_d := INF
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				o.x = start.x + dx * step
				o.z = start.y + dz * step
				var d := want.distance_squared_to(Vector2(o.x, o.z))
				if d < best_d and fits(o, catalog, kind, items):
					best = Vector2(o.x, o.z)
					best_d = d
		if best != Vector2.INF:
			o.x = best.x
			o.z = best.y
			o.y = 0.0
			return true
	o.x = base.x
	o.z = base.y
	return false


## Wall piece `o` on its row's back wall, slid to `x` across (snapped, kept on lit places).
static func hang(o: RoomDesign.Item, x: float, catalog: FurnitureCatalog, kind: RoomKind) -> void:
	var s := catalog.settings
	var w := catalog.size_of(o).x
	var span := row_span(o.row, catalog, kind)
	var to := snappedf(x, s.snap) if s.snap > 0.0 else x
	o.x = clampf(to, span.x + w / 2.0, maxf(span.x + w / 2.0, span.y - w / 2.0))
	o.z = -(s.depth / 2.0 - s.wall_margin)
	o.manual = true


static func _snap_to(o: RoomDesign.Item, x: float, z: float, catalog: FurnitureCatalog,
		kind: RoomKind) -> void:
	var s := catalog.settings
	var n := squares(o, catalog)
	var size := Vector2(n) * s.grid_step
	var half := s.depth / 2.0
	var span := row_span(o.row, catalog, kind)
	o.x = snap_axis(x, n.x, s.grid_step, 0.0)
	o.x = clampf(o.x, span.x + size.x / 2.0, maxf(span.x + size.x / 2.0, span.y - size.x / 2.0))
	o.z = snap_axis(z, n.y, s.grid_step, -half)
	o.z = clampf(o.z, -half + size.y / 2.0, maxf(-half + size.y / 2.0, half - size.y / 2.0))


## From the left of the row's first lit place to the right of its last, in metres.
static func row_span(row: int, catalog: FurnitureCatalog, kind: RoomKind) -> Vector2:
	var bay := catalog.settings.bay_width
	var lo := INF
	var hi := -INF
	for c in kind.cells:
		if c.y == row:
			lo = minf(lo, c.x * bay)
			hi = maxf(hi, (c.x + 1) * bay)
	return Vector2(lo, hi) if lo <= hi else Vector2.ZERO


## Whether every place of `row` from `x0` to `x1` metres is lit.
static func _lit(row: int, x0: float, x1: float, catalog: FurnitureCatalog, kind: RoomKind) -> bool:
	var bay := catalog.settings.bay_width
	if x0 < -EPS:
		return false
	for c in range(floori((x0 + EPS) / bay), floori((x1 - EPS) / bay) + 1):
		if not kind.cells.has(Vector2i(c, row)):
			return false
	return true
