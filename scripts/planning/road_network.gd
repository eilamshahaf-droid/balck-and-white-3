extends RefCounted
## The streets as a graph that can change, like the paths of BW2: nodes are
## crossings and dead ends, edges are curved roads (polylines). Drawing a road
## splits the roads it crosses, and the closed areas between roads are the
## city blocks, whatever their shape.
##
## Kinds: "avenue" (wide), "street", "path" (narrow, for walking) and
## "pedestrian" (a street closed to cars, a plaza along its length).

const P: PlanningSettings = preload("res://data/planning.tres")
const SNAP_NODE := 10.0       # a road end this close to a crossing joins it
const SNAP_EDGE := 8.0        # ...or this close to a road, joins it there
const MERGE := 5.0            # crossings closer than this become one
const SAMPLE := 8.0           # metres between polyline points

var nodes: Array[Vector2] = []
var edges: Array = []         # {id, a, b, points: PackedVector2Array, kind}
var terrain
var _next_id := 0


func _init(t) -> void:
	terrain = t


static func width_of(kind: String) -> float:
	return P.road_widths.get(kind, 9.0)


# --- Building the network ---

## Add a road along `points`. With `follow_terrain` the line is bent around
## slopes first, as engineers do. Returns the number of new road pieces.
func add_road(points: PackedVector2Array, kind: String, follow_terrain := true) -> int:
	var pts := resample(points, SAMPLE)
	if pts.size() < 2 or _length(pts) < 12.0:
		return 0
	if follow_terrain:
		pts = fit_to_terrain(pts)
	# Every place the new road meets the network becomes a node.
	var cuts: Array = []      # [distance along the new road, node id]
	cuts.append([0.0, _snap(pts[0])])
	var along := 0.0
	var hits: Array = []
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		for e in edges:
			var ep: PackedVector2Array = e.points
			for m in ep.size() - 1:
				var q = Geometry2D.segment_intersects_segment(a, b, ep[m], ep[m + 1])
				if q != null:
					hits.append([along + a.distance_to(q), q])
		along += a.distance_to(b)
	for h in hits:
		if h[0] < MERGE or h[0] > along - MERGE:
			continue
		cuts.append([h[0], _snap(h[1], MERGE)])
	cuts.append([along, _snap(pts[pts.size() - 1])])
	cuts.sort_custom(func(x, y): return x[0] < y[0])
	# Cut the new road into pieces between those nodes.
	var made := 0
	for c in cuts.size() - 1:
		var n0: int = cuts[c][1]
		var n1: int = cuts[c + 1][1]
		if n0 == n1:
			continue
		var piece := PackedVector2Array([nodes[n0]])
		var dist := 0.0
		for k in pts.size() - 1:
			dist += pts[k].distance_to(pts[k + 1])
			if dist > cuts[c][0] + 2.0 and dist < cuts[c + 1][0] - 2.0:
				piece.append(pts[k + 1])
		piece.append(nodes[n1])
		if _length(piece) > 6.0 and not _duplicate(n0, n1, piece):
			_add_edge(n0, n1, piece, kind)
			made += 1
	return made


func remove_edge(e: Dictionary) -> void:
	for k in edges.size():
		if edges[k].id == e.id:
			edges.remove_at(k)
			return


func _add_edge(a: int, b: int, pts: PackedVector2Array, kind: String) -> void:
	edges.append({"id": _next_id, "a": a, "b": b, "points": pts, "kind": kind})
	_next_id += 1


func set_kind(e: Dictionary, kind: String) -> void:
	e.kind = kind


## The road nearest to `p`, within `max_dist` of its side. Returns
## {edge, point, segment, distance} or an empty dictionary.
func nearest_edge(p: Vector2, max_dist := 12.0) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for e in edges:
		var ep: PackedVector2Array = e.points
		for m in ep.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, ep[m], ep[m + 1])
			var d := q.distance_to(p) - width_of(e.kind) / 2.0
			if d < best_d:
				best_d = d
				best = {"edge": e, "point": q, "segment": m, "distance": q.distance_to(p)}
	return best


## Bend a line around slopes: each inner point slides sideways (at most
## P.road_max_bend metres) to where the climb between its neighbours is
## gentlest, then the line is smoothed.
func fit_to_terrain(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	var base := pts.duplicate()
	for it in 24:
		for k in range(1, out.size() - 1):
			var t := (out[k + 1] - out[k - 1]).normalized()
			var n := Vector2(-t.y, t.x)
			var best := out[k]
			var best_cost := _bend_cost(out, k, out[k], base[k])
			for s in [-2.5, 2.5]:
				var c: Vector2 = out[k] + n * s
				var cost := _bend_cost(out, k, c, base[k])
				if cost < best_cost:
					best = c
					best_cost = cost
			out[k] = best
	return resample(_smooth(out, 2), SAMPLE)


func _bend_cost(pts: PackedVector2Array, k: int, c: Vector2, origin: Vector2) -> float:
	if c.distance_to(origin) > P.road_max_bend or not terrain.inside(c, 5.0):
		return INF
	var h: float = terrain.road_height(c)
	var g1 := absf(h - terrain.road_height(pts[k - 1])) / maxf(c.distance_to(pts[k - 1]), 1.0)
	var g2 := absf(h - terrain.road_height(pts[k + 1])) / maxf(c.distance_to(pts[k + 1]), 1.0)
	var mid := (pts[k - 1] + pts[k + 1]) / 2.0
	return g1 * g1 + g2 * g2 + 0.0004 * c.distance_squared_to(mid) + (0.5 if terrain.is_water(c) else 0.0)


## The steepest climb along a line (rise over run).
func max_grade(pts: PackedVector2Array) -> float:
	var g := 0.0
	for k in pts.size() - 1:
		var run := pts[k].distance_to(pts[k + 1])
		if run > 0.5:
			g = maxf(g, absf(terrain.road_height(pts[k]) - terrain.road_height(pts[k + 1])) / run)
	return g


# --- The city that is already there ---

## A grid laid over the land the way old cities grew: straight on the flat,
## bending around hills, steep ones as stepped paths, bridges only on some
## avenues, and a road along each river bank.
func generate() -> void:
	var warp := FastNoiseLite.new()
	warp.seed = 11
	warp.frequency = 0.006
	var xs := []
	var zs := []
	var x := -P.grid_avenue_spacing * 4.0
	while x <= P.grid_avenue_spacing * 4.0 + 1.0:
		xs.append(x)
		x += P.grid_avenue_spacing
	var z := -P.grid_street_spacing * 7.0
	while z <= P.grid_street_spacing * 7.0 + 1.0:
		zs.append(z)
		z += P.grid_street_spacing
	# Crossing points, nudged more where the land is hilly.
	var grid := {}
	for i in xs.size():
		for j in zs.size():
			var p := Vector2(xs[i], zs[j])
			var hilly := clampf(terrain.slope_at(p) * 5.0, 0.0, 1.0)
			p += Vector2(warp.get_noise_2d(p.x, p.y), warp.get_noise_2d(p.y + 500.0, p.x)) * 22.0 * hilly
			if terrain.inside(p, 10.0) and not terrain.is_water(p):
				grid[Vector2i(i, j)] = p
	var bridges := [2, 4, 6]
	for key in grid:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = key + d
			if not grid.has(other):
				continue
			var kind := "avenue" if d == Vector2i(0, 1) else "street"
			var line := fit_to_terrain(resample(PackedVector2Array([grid[key], grid[other]]), SAMPLE))
			var wet := false
			for p in line:
				wet = wet or terrain.is_water(p)
			if wet and not (kind == "avenue" and key.x in bridges):
				continue
			# Too steep for cars: a stepped path for walking, as in real hill towns.
			var grade := max_grade(line)
			if grade > P.road_max_grade * 2.5:
				continue
			add_road(line, kind if grade <= P.road_max_grade else "path", false)
	for side in [-1.0, 1.0]:
		var bank := PackedVector2Array()
		var bx: float = -terrain.half_size.x + 20.0
		while bx < terrain.half_size.x - 20.0:
			bank.append(Vector2(bx, terrain.river_z(bx) + side * (P.river_width * 0.5 + 14.0)))
			bx += SAMPLE
		add_road(bank, "avenue", false)


# --- Blocks ---

## The closed areas between roads: [{polygon, area, edges, sides}], where
## `sides` lists each boundary point's road width (for the segment after it).
## Found by walking around every face of the planar graph.
func faces() -> Array:
	var out_edges := {}       # node -> [[angle, edge, forward]]
	for e in edges:
		var ep: PackedVector2Array = e.points
		_add_half(out_edges, e.a, (ep[1] - ep[0]).angle(), e, true)
		_add_half(out_edges, e.b, (ep[ep.size() - 2] - ep[ep.size() - 1]).angle(), e, false)
	for n in out_edges:
		out_edges[n].sort_custom(func(x, y): return x[0] < y[0])
	var used := {}
	var found: Array = []
	for e in edges:
		for forward in [true, false]:
			if used.has(e.id * 2 + int(forward)):
				continue
			var poly := PackedVector2Array()
			var sides := PackedFloat32Array()
			var face_edges: Array = []
			var cur_e: Dictionary = e
			var cur_f: bool = forward
			var guard := 0
			while not used.has(cur_e.id * 2 + int(cur_f)) and guard < 2000:
				guard += 1
				used[cur_e.id * 2 + int(cur_f)] = true
				face_edges.append(cur_e)
				var ep: PackedVector2Array = cur_e.points
				var w := width_of(cur_e.kind)
				for k in ep.size() - 1:
					poly.append(ep[k] if cur_f else ep[ep.size() - 1 - k])
					sides.append(w)
				# At the far node, turn to the next road clockwise from the one we came in on.
				var v: int = cur_e.b if cur_f else cur_e.a
				var list: Array = out_edges[v]
				var back := -1
				for idx in list.size():
					if list[idx][1].id == cur_e.id and list[idx][2] == (not cur_f):
						back = idx
						break
				var nxt: Array = list[(back - 1 + list.size()) % list.size()]
				cur_e = nxt[1]
				cur_f = nxt[2]
			if poly.size() >= 3:
				found.append({"polygon": poly, "sides": sides, "edges": face_edges, "area": _signed_area(poly)})
	# Each connected piece of the network has one outside face, the biggest
	# one turning the other way; everything else is a block.
	var outer_sign := 0.0
	var biggest := 0.0
	for f in found:
		if absf(f.area) > biggest:
			biggest = absf(f.area)
			outer_sign = signf(f.area)
	var blocks: Array = []
	for f in found:
		if signf(f.area) != outer_sign and absf(f.area) > P.min_block_area:
			blocks.append(f)
	return blocks


func _add_half(table: Dictionary, n: int, angle: float, e: Dictionary, forward: bool) -> void:
	if not table.has(n):
		table[n] = []
	table[n].append([angle, e, forward])


# --- Helpers ---

func _snap(p: Vector2, node_radius := SNAP_NODE) -> int:
	var best := -1
	var best_d := node_radius
	for n in nodes.size():
		var d := nodes[n].distance_to(p)
		if d < best_d:
			best = n
			best_d = d
	if best >= 0:
		return best
	var hit := nearest_edge(p, SNAP_EDGE if node_radius >= SNAP_NODE else 0.5)
	if not hit.is_empty() and hit.distance < SNAP_EDGE:
		return _split(hit.edge, hit.segment, hit.point)
	nodes.append(p)
	return nodes.size() - 1


## Split a road at a point on its segment `m`, returning the new node.
func _split(e: Dictionary, m: int, q: Vector2) -> int:
	var ep: PackedVector2Array = e.points
	if q.distance_to(ep[0]) < MERGE:
		return e.a
	if q.distance_to(ep[ep.size() - 1]) < MERGE:
		return e.b
	nodes.append(q)
	var n := nodes.size() - 1
	var first := ep.slice(0, m + 1)
	first.append(q)
	var second := PackedVector2Array([q])
	second.append_array(ep.slice(m + 1))
	remove_edge(e)
	_add_edge(e.a, n, first, e.kind)
	_add_edge(n, e.b, second, e.kind)
	return n


func _duplicate(n0: int, n1: int, piece: PackedVector2Array) -> bool:
	var mid := piece[piece.size() / 2]
	for e in edges:
		if (e.a == n0 and e.b == n1) or (e.a == n1 and e.b == n0):
			var ep: PackedVector2Array = e.points
			if ep[ep.size() / 2].distance_to(mid) < 6.0:
				return true
	return false


static func resample(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() == 0:
		return out
	out.append(pts[0])
	var carry := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := a.distance_to(b)
		var t := spacing - carry
		while t < seg:
			out.append(a.lerp(b, t / seg))
			t += spacing
		carry = seg - (t - spacing)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > spacing * 0.3:
		out.append(pts[pts.size() - 1])
	else:
		out[out.size() - 1] = pts[pts.size() - 1]
	return out


static func _smooth(pts: PackedVector2Array, passes: int) -> PackedVector2Array:
	var out := pts
	for p in passes:
		var s := PackedVector2Array([out[0]])
		for k in out.size() - 1:
			s.append(out[k].lerp(out[k + 1], 0.25))
			s.append(out[k].lerp(out[k + 1], 0.75))
		s.append(out[out.size() - 1])
		out = s
	return out


static func _length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for k in pts.size() - 1:
		l += pts[k].distance_to(pts[k + 1])
	return l


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0
