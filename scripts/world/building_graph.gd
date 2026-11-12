class_name BuildingGraph
extends RefCounted
## Which buildings border each other, worked out once from the stage map; Districts
## asks it who a building's neighbours are.

var _borders: Array[PackedInt32Array] = []


## Neighbours given outright, by index.
func set_borders(lists: Array[PackedInt32Array]) -> void:
	_borders = lists.duplicate()


## Neighbours from the map: two buildings border when their walls stand within `gap`
## metres (next door, or across a street). So nothing is cut off, the buildings of one
## block always join up, and so do two blocks the map calls neighbours, by their
## nearest pair.
func set_from_plan(plan: CityPlan, gap: float) -> void:
	var n := plan.buildings.size()
	var corners: Array[PackedVector2Array] = []
	var reach := PackedFloat32Array()
	for b in plan.buildings:
		corners.append(_corners(b))
		reach.append(b.size.length() / 2.0)
	var links: Array[Dictionary] = []
	for i in n:
		links.append({})
	for i in n:
		for j in range(i + 1, n):
			var apart := plan.buildings[i].centre.distance_to(plan.buildings[j].centre)
			if apart - reach[i] - reach[j] <= gap and _gap(corners[i], corners[j]) <= gap:
				links[i][j] = true
				links[j][i] = true
	for u in plan.units.size():
		var unit := plan.units[u]
		_join(unit.buildings, links, corners)
		for v in unit.next:
			if v > u:
				_bridge(unit.buildings, plan.units[v].buildings, links, corners)
	_borders.clear()
	for i in n:
		_borders.append(PackedInt32Array(links[i].keys()))


## The buildings `index` borders.
func of(index: int) -> PackedInt32Array:
	return _borders[index]


## Every building within `steps` borders of `index` (not `index` itself), skipping those
## `skip` marks with a non-zero byte.
func around(index: int, steps: int, skip: PackedByteArray) -> Array[int]:
	var seen := {index: true}
	var out: Array[int] = []
	var ring: Array[int] = [index]
	for step in steps:
		var next: Array[int] = []
		for i in ring:
			for j in _borders[i]:
				if not seen.has(j) and skip[j] == 0:
					seen[j] = true
					next.append(j)
		out.append_array(next)
		ring = next
	return out


## Link the pieces of `members` that nothing links yet, nearest pair first, until they
## are one group.
static func _join(members: PackedInt32Array, links: Array[Dictionary],
		corners: Array[PackedVector2Array]) -> void:
	if members.is_empty():
		return
	var inside := {}
	for m in members:
		inside[m] = true
	var seen := {members[0]: true}
	while true:
		var todo: Array[int] = []
		todo.assign(seen.keys())
		while not todo.is_empty():
			var i: int = todo.pop_back()
			for j: int in links[i]:
				if inside.has(j) and not seen.has(j):
					seen[j] = true
					todo.append(j)
		if seen.size() == members.size():
			return
		var best := Vector2i(-1, -1)
		var best_gap := INF
		for i: int in seen:
			for j in members:
				if not seen.has(j):
					var g := _gap(corners[i], corners[j])
					if g < best_gap:
						best_gap = g
						best = Vector2i(i, j)
		links[best.x][best.y] = true
		links[best.y][best.x] = true
		seen[best.y] = true


## Make sure blocks `a` and `b` touch: link their nearest pair if nothing links them.
static func _bridge(a: PackedInt32Array, b: PackedInt32Array, links: Array[Dictionary],
		corners: Array[PackedVector2Array]) -> void:
	var best := Vector2i(-1, -1)
	var best_gap := INF
	for i in a:
		for j in b:
			if links[i].has(j):
				return
			var g := _gap(corners[i], corners[j])
			if g < best_gap:
				best_gap = g
				best = Vector2i(i, j)
	if best.x >= 0:
		links[best.x][best.y] = true
		links[best.y][best.x] = true


static func _corners(b: CityPlan.Building) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(b.centre + (k * b.size / 2.0).rotated(b.angle))
	return out


## The gap between two boxes on the ground (0 when they touch or overlap).
static func _gap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(a[0], b) or Geometry2D.is_point_in_polygon(b[0], a):
		return 0.0
	var best := INF
	for k in 4:
		for l in 4:
			var pair := Geometry2D.get_closest_points_between_segments(
					a[k], a[(k + 1) % 4], b[l], b[(l + 1) % 4])
			best = minf(best, pair[0].distance_to(pair[1]))
	return best
