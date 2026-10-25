extends RefCounted
## Three example plans, one for each god, built on the same starting city with
## the same tools the player has, streets included. Each follows the planning
## approach of its path in the design doc ("cities and stages"):
##   good    - Jane Jacobs and Jan Gehl: a humane city,
##   evil    - Robert Moses and Haussmann: the city as a machine,
##   neutral - agglomeration and land value capture: a business district on the line.

const P: PlanningSettings = preload("res://data/planning.tres")

const TITLES := {"good": "Good god", "evil": "Evil god", "neutral": "Neutral god"}
const TEXTS := {
	"good": "Jacobs and Gehl, the humane city. Walking paths cut the big blocks into short ones, central streets are car-free, every block mixes homes and shops, a temple and squares at the heart, parks on the hilltops, street trees, benches and small shrines, no cameras. Buildings stay human-scale. The city makes quality of life, so people move in by choice.",
	"evil": "Moses and Haussmann, the city as a machine. Two straight boulevards are cut through the old streets and over the hills, a monument where they meet and another on the highest hill, seen from everywhere. Factories by the river, worker housing slabs beside them, cameras along the boulevards, no trees. The city makes power: fear, compliance and recruits.",
	"neutral": "Agglomeration and land value capture. A new avenue carries the line across the city, with three stations on it and a dense business district around each. Headquarters towers stand on the nearby hills, where they are seen from far away, and billboards line the avenues. Homes are pushed outwards. The city makes money and commuters.",
}


static func apply(model, which: String) -> void:
	match which:
		"good":
			_good(model)
		"evil":
			_evil(model)
		"neutral":
			_neutral(model)
	model.recompute_fields()
	# Let the city grow into the plan: buildings rise and convert where wanted.
	var idle := 0
	for n in 6000:
		if model.step() < 0:
			idle += 1
			if idle > 200:
				break
		else:
			idle = 0


static func _good(model) -> void:
	# Short blocks: a walking path across each of the biggest central blocks.
	var central := _by_distance(model, Vector2.ZERO).slice(0, 16)
	central.sort_custom(func(a, b): return model.blocks[a].area > model.blocks[b].area)
	var cuts: Array = []
	for b in central.slice(0, 7):
		var cut := _cut_across(model.blocks[b])
		if cut.size() == 2:
			cuts.append(cut)
	for cut in cuts:
		model.add_road(cut, "path", true)
	# Car-free streets at the heart.
	var streets: Array = model.roads.edges.filter(func(e): return e.kind == "street")
	streets.sort_custom(func(a, b): return _mid(a).length() < _mid(b).length())
	for e in streets.slice(0, 6):
		model.roads.set_kind(e, "pedestrian")
	# Every block mixes homes and shops; denser in the middle.
	var order := _by_distance(model, Vector2.ZERO)
	for rank in order.size():
		var b: int = order[rank]
		model.set_zone(b, "residential" if rank % 2 == 0 else "commercial")
		model.blocks[b].density = 2 if rank < 20 else 1
	_landmark_near(model, "temple", Vector2.ZERO)
	_landmark_near(model, "square", Vector2(60, 20))
	_landmark_near(model, "square", Vector2(-120, -60))
	for b in _highest(model, 2):
		_landmark_near(model, "park", _flat(model.blocks[b].center))
	for p in _along_roads(model, ["street", "avenue", "path", "pedestrian"], 220.0, 20.0, 1.0):
		model.place_detail("tree", Vector3(p.x, 0, p.y))
	for lm in model.landmarks:
		if lm.kind in ["square", "temple"]:
			for side in [-1.0, 1.0]:
				var q: Vector3 = lm.pos + Vector3(side * 6.0, 0, 0)
				model.place_detail("bench", q)
	for k in range(3, order.size(), 6):
		model.place_detail("shrine", model.blocks[order[k]].center)


static func _evil(model) -> void:
	# Haussmann's percées: straight boulevards through everything, hills or not.
	model.add_road(PackedVector2Array([Vector2(-390, -270), Vector2(390, 210)]), "avenue", false)
	model.add_road(PackedVector2Array([Vector2(-390, 230), Vector2(390, -250)]), "avenue", false)
	var t = model.terrain
	for b in model.blocks.size():
		var c: Vector3 = model.blocks[b].center
		var from_river := absf(c.z - t.river_z(c.x))
		if from_river < 85.0:
			model.set_zone(b, "industrial")
			model.blocks[b].density = 3
		elif from_river < 190.0:
			model.set_zone(b, "residential")   # worker housing next to the factories
			model.blocks[b].density = 3
		else:
			model.set_zone(b, "commercial" if b % 7 == 0 else "residential")
			model.blocks[b].density = 2
	var by_river := range(model.blocks.size())
	by_river = by_river.filter(func(b): return not model.blocks[b].water)
	by_river.sort_custom(func(a, b): return _river_distance(model, a) < _river_distance(model, b))
	var placed := 0
	for b in by_river:
		if placed < 5 and not model.place_landmark("factory", model.blocks[b].center).is_empty():
			placed += 1
	_landmark_near(model, "monument", Vector2(0, -22))
	_landmark_near(model, "monument", _flat(model.blocks[_highest(model, 1)[0]].center))
	for p in _along_roads(model, ["avenue"], 260.0, 36.0, 1.0):
		model.place_detail("camera", Vector3(p.x, 0, p.y))


static func _neutral(model) -> void:
	# The line: a new avenue across the city, bending around the hills.
	var line := PackedVector2Array()
	for x in range(-380, 381, 40):
		line.append(Vector2(x, 120.0 + 25.0 * sin(x * 0.01)))
	model.add_road(line, "avenue", true)
	var stations: Array[Vector2] = [Vector2(-220, 115), Vector2(0, 120), Vector2(220, 125)]
	for s in stations:
		_landmark_near(model, "station", s)
	for b in model.blocks.size():
		var c := _flat(model.blocks[b].center)
		var near := INF
		for s in stations:
			near = minf(near, c.distance_to(s))
		if near < 110.0:
			model.set_zone(b, "commercial")    # the business district around the stations
			model.blocks[b].density = 3
		elif model.blocks[b].zone != "industrial":
			model.set_zone(b, "residential")
			model.blocks[b].density = 2 if near < 260.0 else 1
	# Headquarters on the highest ground near each station.
	for s in stations:
		var best := -1
		var best_h := -INF
		for b in model.blocks.size():
			var c := _flat(model.blocks[b].center)
			if c.distance_to(s) < 200.0 and model.blocks[b].center.y > best_h:
				best_h = model.blocks[b].center.y
				best = b
		if best >= 0:
			_landmark_near(model, "tower", _flat(model.blocks[best].center))
	for p in _along_roads(model, ["avenue"], 300.0, 45.0, -1.0):
		model.place_detail("billboard", Vector3(p.x, 0, p.y))


# --- Helpers ---

## Place a landmark in the block nearest `p` where it fits.
static func _landmark_near(model, kind: String, p: Vector2) -> void:
	for b in _by_distance(model, p).slice(0, 12):
		var c: Vector3 = model.blocks[b].center
		if not model.place_landmark(kind, c).is_empty():
			return


static func _by_distance(model, p: Vector2) -> Array:
	var order := range(model.blocks.size()).filter(func(b): return not model.blocks[b].water)
	order.sort_custom(func(a, b): return _flat(model.blocks[a].center).distance_to(p) < _flat(model.blocks[b].center).distance_to(p))
	return order


static func _highest(model, count: int) -> Array:
	var order := range(model.blocks.size()).filter(func(b): return not model.blocks[b].water)
	order.sort_custom(func(a, b): return model.blocks[a].center.y > model.blocks[b].center.y)
	return order.slice(0, count)


static func _river_distance(model, b: int) -> float:
	var c: Vector3 = model.blocks[b].center
	return absf(c.z - model.terrain.river_z(c.x))


## A line across a block, the short way, from street to street.
static func _cut_across(block: Dictionary) -> PackedVector2Array:
	var poly: PackedVector2Array = block.polygon
	var c := _flat(block.center)
	var box: Rect2 = block.bbox
	var dir := Vector2(0, 1) if box.size.x > box.size.y else Vector2(1, 0)
	var ends: Array = [null, null]
	var dists := [INF, INF]
	for k in poly.size():
		var q = Geometry2D.segment_intersects_segment(c - dir * 400.0, c + dir * 400.0, poly[k], poly[(k + 1) % poly.size()])
		if q == null:
			continue
		var side := 0 if (q - c).dot(dir) < 0.0 else 1
		var d: float = q.distance_to(c)
		if d < dists[side]:
			dists[side] = d
			ends[side] = q
	if ends[0] == null or ends[1] == null:
		return PackedVector2Array()
	return PackedVector2Array([ends[0], ends[1]])


## Points along roads of the given kinds within `radius` of the centre, every
## `spacing` metres, on the sidewalk (alternating sides, or side -1 for always the same side).
static func _along_roads(model, kinds: Array, radius: float, spacing: float, side: float) -> Array:
	var out: Array = []
	var flip := 1.0
	for e in model.roads.edges:
		if e.kind not in kinds:
			continue
		var pts: PackedVector2Array = e.points
		var offset: float = model.roads.width_of(e.kind) / 2.0 + P.sidewalk * 0.5
		var s := 0.0
		for k in pts.size() - 1:
			var seg := pts[k].distance_to(pts[k + 1])
			var t := (pts[k + 1] - pts[k]).normalized()
			var n := Vector2(-t.y, t.x)
			while s < seg:
				var p := pts[k].lerp(pts[k + 1], s / seg)
				if p.length() < radius:
					out.append(p + n * offset * flip)
					flip = -flip if side > 0.0 else flip
				s += spacing
			s -= seg
	return out


static func _mid(e: Dictionary) -> Vector2:
	var pts: PackedVector2Array = e.points
	return pts[pts.size() / 2]


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)
