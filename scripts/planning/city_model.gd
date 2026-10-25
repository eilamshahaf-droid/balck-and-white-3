extends RefCounted
## The city-planning model with no graphics. The land has hills and a river
## (terrain.gd), the streets are a graph the player can redraw (road_network.gd),
## and the blocks are whatever closed areas the streets leave, in any shape.
## Lots line each block along its streets, facing them.
##
## Three levels, as in the design doc ("building at a modern scale"):
##   neighbourhood - zone a block (homes, shops, industry) and how dense;
##                   buildings then rise on their own by zone and demand,
##   plot          - place a landmark anywhere in a block, facing its street,
##   street        - draw roads and paths, close streets to cars, add details.
## Every structure stamps a value per metric that fades with distance onto a
## fine grid (BW2's PlacementData), so the fields are smooth blobs. Anything
## built higher up reaches further (BW2's hill bonus).
##
## The city grows organically: the most wanted lots are built first, heights
## follow land value, and each building is slowly rebuilt in the look of the
## god its street belongs to (good, evil, or neutral "grey").

const Terrain = preload("res://scripts/planning/terrain.gd")
const Roads = preload("res://scripts/planning/road_network.gd")
const P: PlanningSettings = preload("res://data/planning.tres")

const METRICS := ["belief", "commerce", "quality", "fear", "influence"]
const ZONES := ["residential", "commercial", "industrial"]
const CELL := 6.0                 # metres per field cell
const NEIGHBOUR_RADIUS := 110.0   # blocks this close count as neighbours (mixed use)

var terrain
var roads
var blocks: Array = []     # {polygon, sides, bbox, area, center, zone, density, lots, edges, water}
var lots: Array = []       # {block, pos, width, depth, rot, front, corners, base, low, floors, zone, character, landmark, seed}
var landmarks: Array = []  # {kind, pos, rot, front, width, depth, corners, block, lots}
var details: Array = []    # {kind, pos}
var half_size := Vector2.ZERO
var grid_size := Vector2i.ZERO
var grid_origin := Vector2.ZERO

var _field := {}           # metric -> PackedFloat32Array, grid_size.x * grid_size.y
var _block_residents := PackedInt32Array()
var _mixed := PackedByteArray()
var _neighbours: Array = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 7) -> void:
	_rng.seed = seed_value
	terrain = Terrain.new()
	roads = Roads.new(terrain)
	half_size = terrain.half_size
	grid_origin = -half_size
	grid_size = Vector2i(ceili(half_size.x * 2.0 / CELL) + 1, ceili(half_size.y * 2.0 / CELL) + 1)
	for m in METRICS:
		var arr := PackedFloat32Array()
		arr.resize(grid_size.x * grid_size.y)
		_field[m] = arr


## The city already exists (design doc): its streets follow the land, shops
## on the avenues, industry by the river, homes everywhere else, partly built.
func seed_existing_city() -> void:
	roads.generate()
	relayout()
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		if block.water:
			continue
		var c: Vector3 = block.center
		var by_river: bool = absf(c.z - terrain.river_z(c.x)) < 70.0
		var on_avenue := false
		for e in block.edges:
			on_avenue = on_avenue or e.kind == "avenue"
		var zone := "residential"
		var roll := _rng.randf()
		if by_river and roll < 0.35:
			zone = "industrial"
		elif on_avenue and roll < 0.5:
			zone = "commercial"
		set_zone(b, zone)
		block.density = _rng.randi_range(1, 2)
		for lot_id in block.lots:
			if _rng.randf() < 0.6:
				_build(lot_id)


# --- Player actions: streets ---

## Draw a road. Returns the landmarks it had to knock down.
func add_road(points: PackedVector2Array, kind: String, follow_terrain := true) -> Array:
	if roads.add_road(points, kind, follow_terrain) == 0:
		return []
	return relayout()


func remove_road_near(pos: Vector3) -> bool:
	var hit: Dictionary = roads.nearest_edge(Vector2(pos.x, pos.z), 4.0)
	if hit.is_empty():
		return false
	roads.remove_edge(hit.edge)
	relayout()
	return true


## Close a street to cars (a plaza along it), or open it again.
func toggle_pedestrian_near(pos: Vector3) -> bool:
	var hit: Dictionary = roads.nearest_edge(Vector2(pos.x, pos.z), 4.0)
	if hit.is_empty() or hit.edge.kind not in ["street", "pedestrian"]:
		return false
	roads.set_kind(hit.edge, "street" if hit.edge.kind == "pedestrian" else "pedestrian")
	recompute_fields()
	return true


# --- Player actions: zones, landmarks, details ---

func set_zone(b: int, zone: String) -> void:
	var block: Dictionary = blocks[b]
	if block.zone == zone or block.water:
		return
	block.zone = zone
	# Buildings of another zone don't vanish at once; they are replaced one by
	# one as the area grows (the doc's gradual conversion).
	if zone == "":
		for lot_id in block.lots:
			_demolish(lot_id)
	_update_mixed()


func change_density(b: int, step: int) -> void:
	blocks[b].density = clampi(blocks[b].density + step, 1, 3)


## Where a landmark of `kind` would stand if placed at `pos`: along the
## nearest street of the block, facing it. Empty if it doesn't fit there.
func landmark_footprint(kind: String, pos: Vector3) -> Dictionary:
	var p := Vector2(pos.x, pos.z)
	var b := block_at(pos)
	if b < 0 or not P.landmarks.has(kind) or blocks[b].water:
		return {}
	var block: Dictionary = blocks[b]
	var poly: PackedVector2Array = block.polygon
	var best_k := 0
	var best_q := Vector2.ZERO
	var best_d := INF
	for k in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])
		if q.distance_to(p) < best_d:
			best_d = q.distance_to(p)
			best_k = k
			best_q = q
	var t := (poly[(best_k + 1) % poly.size()] - poly[best_k]).normalized()
	var inward := signf(block.area_signed) * Vector2(-t.y, t.x)
	var offset: float = block.sides[best_k] / 2.0 + P.sidewalk
	var width: float = P.landmark_width[kind]
	for scale in [1.0, 0.8, 0.6]:
		var depth: float = P.landmark_depth[kind] * scale
		var w: float = width * scale
		var centre: Vector2 = best_q + inward * (offset + depth / 2.0)
		var corners := _rect(centre, t, inward, w, depth)
		if _fits(corners, block):
			return {"kind": kind, "pos": _ground(centre), "rot": -t.angle(), "front": -signf(block.area_signed),
					"width": w, "depth": depth, "corners": corners, "block": b}
	return {}


## Place a landmark; it takes the lots under it. Returns it, or an empty
## dictionary if it doesn't fit or another landmark is in the way.
func place_landmark(kind: String, pos: Vector3) -> Dictionary:
	var lm := landmark_footprint(kind, pos)
	if lm.is_empty():
		return {}
	for other in landmarks:
		if _overlap(lm.corners, other.corners):
			return {}
	lm.lots = []
	for lot_id in blocks[lm.block].lots:
		if _overlap(lm.corners, lots[lot_id].corners):
			_demolish(lot_id)
			lots[lot_id].landmark = lm
			lm.lots.append(lot_id)
	landmarks.append(lm)
	_stamp(P.landmarks[kind], lm.pos, 1.0, _reach_bonus(kind, lm.pos))
	return lm


## Remove the landmark under `pos`. Returns it, or an empty dictionary.
func remove_landmark_at(pos: Vector3) -> Dictionary:
	for lm in landmarks:
		if Geometry2D.is_point_in_polygon(Vector2(pos.x, pos.z), lm.corners):
			_stamp(P.landmarks[lm.kind], lm.pos, -1.0, _reach_bonus(lm.kind, lm.pos))
			for n in lm.lots:
				lots[n].landmark = null
			landmarks.erase(lm)
			return lm
	return {}


func place_detail(kind: String, pos: Vector3) -> void:
	details.append({"kind": kind, "pos": _ground(Vector2(pos.x, pos.z))})
	_stamp(P.details[kind], pos, 1.0)


## Remove a street detail within 6 m of `pos`. Returns its index, or -1.
func remove_detail_near(pos: Vector3) -> int:
	for n in details.size():
		if Vector2(details[n].pos.x, details[n].pos.z).distance_to(Vector2(pos.x, pos.z)) < 6.0:
			_stamp(P.details[details[n].kind], details[n].pos, -1.0)
			details.remove_at(n)
			return n
	return -1


# --- Blocks and lots from the streets ---

## Work out the blocks and lots again after the streets changed. Blocks keep
## the zone of the old block they lie in, lots that didn't move keep their
## building, and landmarks a new road ran through are knocked down (returned).
func relayout() -> Array:
	var old_blocks := blocks
	var old_lots := {}
	for lot in lots:
		old_lots[_lot_key(lot)] = lot
	blocks = []
	lots = []
	for f in roads.faces():
		var poly: PackedVector2Array = f.polygon
		var c := _centroid(poly)
		var water := 0
		for k in range(0, poly.size(), maxi(poly.size() / 8, 1)):
			water += int(terrain.is_water(poly[k].lerp(c, 0.5)))
		var block := {"polygon": poly, "sides": f.sides, "edges": f.edges, "area": absf(f.area),
				"area_signed": f.area, "bbox": _bbox(poly), "center": _ground(c), "zone": "", "density": 1,
				"lots": [], "water": terrain.is_water(c) or water >= 4}
		for ob in old_blocks:
			if ob.bbox.has_point(c) and Geometry2D.is_point_in_polygon(c, ob.polygon):
				block.zone = ob.zone
				block.density = ob.density
				break
		if block.water:
			block.zone = ""
		blocks.append(block)
		_place_lots(blocks.size() - 1)
	for lot in lots:
		var old: Dictionary = old_lots.get(_lot_key(lot), {})
		if not old.is_empty():
			for key in ["floors", "zone", "character", "seed"]:
				lot[key] = old[key]
	var knocked_down: Array = []
	for lm in landmarks.duplicate():
		var b := block_at(lm.pos)
		if b < 0 or not _fits(lm.corners, blocks[b]):
			knocked_down.append(lm)
			landmarks.erase(lm)
			continue
		lm.block = b
		lm.lots = []
		for lot_id in blocks[b].lots:
			if _overlap(lm.corners, lots[lot_id].corners):
				lots[lot_id].floors = 0
				lots[lot_id].zone = ""
				lots[lot_id].landmark = lm
				lm.lots.append(lot_id)
	_neighbours = []
	for b in blocks.size():
		var near: Array = []
		for o in blocks.size():
			if o != b and blocks[o].center.distance_to(blocks[b].center) < NEIGHBOUR_RADIUS:
				near.append(o)
		_neighbours.append(near)
	_update_mixed()
	recompute_fields()
	return knocked_down


## Lots along every street of a block, facing it, as deep as the block allows.
func _place_lots(b: int) -> void:
	var block: Dictionary = blocks[b]
	if block.water:
		return
	var poly: PackedVector2Array = block.polygon
	var n := poly.size()
	var cum := PackedFloat32Array([0.0])
	for k in n:
		cum.append(cum[k] + poly[k].distance_to(poly[(k + 1) % n]))
	var perimeter := cum[n]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(block.center.x), roundi(block.center.z))) + roundi(block.area)
	var s := signf(block.area_signed)
	var placed: Array = []
	var along := rng.randf_range(0.0, 4.0)
	while along < perimeter - P.lot_width_min:
		var w := rng.randf_range(P.lot_width_min, P.lot_width_max)
		var k := _segment_at(cum, along)
		var a := _point_at(poly, cum, along)
		var e := _point_at(poly, cum, minf(along + w, perimeter))
		var t := e - a
		if t.length() < P.lot_width_min * 0.7:
			along += 2.0
			continue
		t = t.normalized()
		var inward := s * Vector2(-t.y, t.x)
		var offset: float = block.sides[k] / 2.0 + P.sidewalk
		var done := false
		for depth in [P.lot_depth, P.lot_depth_short]:
			var centre: Vector2 = (a + e) / 2.0 + inward * (offset + depth / 2.0)
			var corners := _rect(centre, t, inward, a.distance_to(e) - 0.4, depth)
			if not _fits(corners, block):
				continue
			var clash := false
			for other in placed:
				if _overlap(corners, other):
					clash = true
					break
			if clash:
				continue
			placed.append(corners)
			var heights := []
			for c in corners:
				heights.append(terrain.height2(c))
			block.lots.append(lots.size())
			lots.append({"block": b, "pos": _ground(centre), "width": a.distance_to(e) - 0.4, "depth": depth,
					"rot": -t.angle(), "front": -s, "corners": corners, "base": heights.max(), "low": heights.min(),
					"floors": 0, "zone": "", "character": "", "landmark": null, "seed": rng.randf()})
			done = true
			break
		along += w if done else 3.0


## A footprint fits a block if it is inside it, clear of every street and its
## sidewalk, on dry land and not too steep to build on.
func _fits(corners: PackedVector2Array, block: Dictionary) -> bool:
	var poly: PackedVector2Array = block.polygon
	var probes := PackedVector2Array(corners)
	var centre := (corners[0] + corners[2]) / 2.0
	probes.append(centre)
	for k in 4:
		probes.append((corners[k] + corners[(k + 1) % 4]) / 2.0)
	var low := INF
	var high := -INF
	for p in probes:
		if not Geometry2D.is_point_in_polygon(p, poly) or terrain.is_water(p):
			return false
		var h: float = terrain.height2(p)
		low = minf(low, h)
		high = maxf(high, h)
		for k in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])
			if q.distance_to(p) < block.sides[k] / 2.0 + P.sidewalk * 0.6:
				return false
	return high - low < 9.0


# --- The city filling itself in ---

## One building goes up, or is rebuilt in a new look, where it is most wanted:
## of a few random lots that need work, the one with the highest land value.
## Returns the lot id that changed, or -1.
func step() -> int:
	if lots.is_empty():
		return -1
	var best := -1
	var best_score := -INF
	for attempt in 10:
		var lot_id := _rng.randi_range(0, lots.size() - 1)
		if not _needs_work(lot_id):
			continue
		var score := land_value(lot_id) + _rng.randf_range(0.0, 4.0)
		if score > best_score:
			best = lot_id
			best_score = score
	if best >= 0:
		_demolish(best)
		_build(best)
	return best


func _needs_work(lot_id: int) -> bool:
	var lot: Dictionary = lots[lot_id]
	var block: Dictionary = blocks[lot.block]
	if block.zone == "" or lot.landmark != null or not _wanted(lot_id, block.zone):
		return false
	if lot.zone != block.zone or lot.character != character_for(lot_id):
		return true
	var target := target_floors(lot_id)
	return lot.floors < target * 0.6 or lot.floors > ceili(target * 1.5)


func _wanted(lot_id: int, zone: String) -> bool:
	match zone:
		"residential":
			return value("quality", lot_id) >= P.min_quality_to_build_homes
		"commercial":
			return residents_near(lots[lot_id].pos, P.shop_customer_radius) >= P.residents_per_shop
	return true


func _build(lot_id: int) -> void:
	var lot: Dictionary = lots[lot_id]
	var block: Dictionary = blocks[lot.block]
	if block.zone == "" or lot.landmark != null:
		return
	lot.zone = block.zone
	lot.character = character_for(lot_id)
	lot.floors = target_floors(lot_id)
	_block_residents[lot.block] += residents(lot_id)
	_stamp(P.zone_effects[lot.zone], lot.pos, 1.0)


func _demolish(lot_id: int) -> void:
	var lot: Dictionary = lots[lot_id]
	if lot.floors == 0:
		return
	_stamp(P.zone_effects[lot.zone], lot.pos, -1.0)
	_block_residents[lot.block] -= residents(lot_id)
	lot.floors = 0
	lot.zone = ""
	lot.character = ""


## Rebuild every field from what stands now (after the streets changed).
func recompute_fields() -> void:
	for m in METRICS:
		var arr: PackedFloat32Array = _field[m]
		arr.fill(0.0)
		_field[m] = arr
	_block_residents = PackedInt32Array()
	_block_residents.resize(blocks.size())
	for n in lots.size():
		var lot: Dictionary = lots[n]
		if lot.floors > 0:
			_block_residents[lot.block] += residents(n)
			_stamp(P.zone_effects[lot.zone], lot.pos, 1.0)
	for lm in landmarks:
		_stamp(P.landmarks[lm.kind], lm.pos, 1.0, _reach_bonus(lm.kind, lm.pos))
	for d in details:
		_stamp(P.details[d.kind], d.pos, 1.0)
	# A street closed to cars is a long plaza: one plaza's worth every 40 m.
	for e in roads.edges:
		if e.kind == "pedestrian":
			for p in Roads.resample(e.points, 40.0):
				_stamp(P.plaza, Vector3(p.x, 0, p.y), 1.0)


# --- Reading the city ---

## A metric's field value at any point (smoothly interpolated).
func field_at(metric: String, pos: Vector3) -> float:
	var g := (Vector2(pos.x, pos.z) - grid_origin) / CELL
	var x := clampi(floori(g.x), 0, grid_size.x - 2)
	var y := clampi(floori(g.y), 0, grid_size.y - 2)
	var fx := clampf(g.x - x, 0.0, 1.0)
	var fy := clampf(g.y - y, 0.0, 1.0)
	var arr: PackedFloat32Array = _field[metric]
	var i := y * grid_size.x + x
	return lerpf(lerpf(arr[i], arr[i + 1], fx), lerpf(arr[i + grid_size.x], arr[i + grid_size.x + 1], fx), fy)


## A metric's value at a lot: the field plus the mixed-use bonus.
func value(metric: String, lot_id: int) -> float:
	var v := field_at(metric, lots[lot_id].pos)
	if _mixed[lots[lot_id].block]:
		if metric == "quality":
			v += P.mixed_use_quality
		elif metric == "commerce":
			v += P.mixed_use_commerce
	return v


func land_value(lot_id: int) -> float:
	return value("commerce", lot_id) + value("quality", lot_id) + value("influence", lot_id)


## Which god the street around this lot belongs to: "good", "evil", "grey" or "".
func character_for(lot_id: int) -> String:
	var scores := character_scores(lot_id)
	var best := ""
	var best_score: float = P.character_threshold
	for c in scores:
		if scores[c] > best_score:
			best = c
			best_score = scores[c]
	return best


func character_scores(lot_id: int) -> Dictionary:
	return {
		"good": value("quality", lot_id) + value("belief", lot_id) / 2.0 - 2.0,
		"evil": 2.0 * maxf(value("fear", lot_id), 0.0) - 1.0,
		"grey": value("influence", lot_id) - 1.0,
	}


func target_floors(lot_id: int) -> int:
	var lot: Dictionary = lots[lot_id]
	var block: Dictionary = blocks[lot.block]
	var top: float = P.floors_per_density[block.density - 1]
	var appeal := clampf(land_value(lot_id) / P.land_value_full, 0.0, 1.0)
	var f := top * lerpf(0.45, 1.1, appeal) * lerpf(0.85, 1.1, lot.seed)
	match character_for(lot_id):
		"good":
			f *= P.good_height_factor
		"evil":
			f *= P.evil_height_factor
		"grey":
			f *= P.grey_height_factor
	if block.zone == "industrial":
		f = minf(f, 4.0)
	return maxi(1, roundi(f))


func residents(lot_id: int) -> int:
	var lot: Dictionary = lots[lot_id]
	return lot.floors * P.residents_per_floor if lot.zone == "residential" else 0


func residents_near(pos: Vector3, radius: float) -> int:
	var total := 0
	for b in blocks.size():
		if blocks[b].center.distance_to(pos) < radius:
			total += _block_residents[b]
	return total


## How placing `kind` at `pos` would change each metric in the block there:
## the number shown before placing.
func preview(kind: String, pos: Vector3, b: int) -> Dictionary:
	var def := definition(kind)
	var bonus := _reach_bonus(kind, pos)
	var out := {}
	var block_lots: Array = blocks[b].lots
	for metric in def:
		var v: float = def[metric][0]
		var r: float = def[metric][1] + bonus
		var sum := 0.0
		for lot_id in block_lots:
			sum += _falloff(v, r, _flat(lots[lot_id].pos).distance_to(_flat(pos)))
		out[metric] = sum / maxi(block_lots.size(), 1)
	return out


func definition(kind: String) -> Dictionary:
	if kind == "pedestrian":
		return P.plaza
	return P.landmarks.get(kind, P.details.get(kind, {}))


func reach_of(kind: String, pos := Vector3.ZERO) -> float:
	var def := definition(kind)
	var r := 0.0
	for metric in def:
		r = maxf(r, def[metric][1])
	return r + _reach_bonus(kind, pos) if r > 0.0 else 0.0


## What the city makes per minute on each path, and how it is doing.
func stats() -> Dictionary:
	var population := 0
	var prayer := 0.0
	var quality := 0.0
	var fear := 0.0
	var jobs := 0.0
	var money := 0.0
	var built := 0
	var looks := {"good": 0, "evil": 0, "grey": 0}
	for n in lots.size():
		var lot: Dictionary = lots[n]
		var people := residents(n)
		population += people
		if people > 0:
			var faith := maxf(value("belief", n), 0.0) + P.fear_prayer * maxf(value("fear", n), 0.0)
			prayer += people * P.prayer_per_resident * clampf(faith / P.belief_field_full, 0.0, 1.0)
			quality += value("quality", n) * people
			fear += maxf(value("fear", n), 0.0) * people
		if lot.zone == "commercial" or lot.zone == "industrial":
			var here: float = lot.floors * 10.0
			jobs += here
			money += here * P.money_per_job * (1.0 + maxf(value("commerce", n), 0.0) / 10.0)
		if lot.floors > 0:
			built += 1
			if lot.character != "":
				looks[lot.character] += 1
	var road_m := 0.0
	for e in roads.edges:
		road_m += Roads._length(e.points)
	var avg_quality := quality / maxi(population, 1)
	var avg_fear := fear / maxi(population, 1)
	return {"population": population, "prayer": prayer, "jobs": jobs, "quality": avg_quality, "fear": avg_fear,
			"migrants": population * P.migrants_per_quality * maxf(avg_quality - P.migrant_quality_baseline, 0.0),
			"power": population * P.power_per_fear * avg_fear, "money": money,
			"built": built, "lots": lots.size(), "blocks": blocks.size(), "roads_km": road_m / 1000.0,
			"landmarks": landmarks.size(), "looks": looks}


func block_at(pos: Vector3) -> int:
	var p := Vector2(pos.x, pos.z)
	for b in blocks.size():
		if blocks[b].bbox.has_point(p) and Geometry2D.is_point_in_polygon(p, blocks[b].polygon):
			return b
	return -1


func lot_at(pos: Vector3) -> int:
	var b := block_at(pos)
	if b < 0:
		return -1
	var p := Vector2(pos.x, pos.z)
	for lot_id in blocks[b].lots:
		if Geometry2D.is_point_in_polygon(p, lots[lot_id].corners):
			return lot_id
	return -1


func field_grid(metric: String) -> PackedFloat32Array:
	return _field[metric]


func mixed_use(b: int) -> bool:
	return _mixed[b] == 1


# --- Internals ---

func _update_mixed() -> void:
	_mixed = PackedByteArray()
	_mixed.resize(blocks.size())
	for b in blocks.size():
		if blocks[b].zone == "" or b >= _neighbours.size():
			continue
		for o in _neighbours[b]:
			if blocks[o].zone != "" and blocks[o].zone != blocks[b].zone:
				_mixed[b] = 1
				break


func _reach_bonus(kind: String, pos: Vector3) -> float:
	var bonus := 0.0
	if kind == "tower":
		bonus += maxf(P.tower_height - 30.0, 0.0) * P.height_reach_per_metre
	if P.landmarks.has(kind):
		bonus += maxf(terrain.height_at(pos.x, pos.z) - 1.0, 0.0) * P.hill_reach_per_metre
	return bonus


## Add (sign 1) or take away (sign -1) a structure's fields around `pos`.
func _stamp(def: Dictionary, pos: Vector3, sign: float, reach_bonus := 0.0) -> void:
	var c := (Vector2(pos.x, pos.z) - grid_origin) / CELL
	for metric in def:
		var v: float = def[metric][0] * sign
		var r: float = def[metric][1] + reach_bonus
		var rc := r / CELL
		var arr: PackedFloat32Array = _field[metric]
		for y in range(maxi(floori(c.y - rc), 0), mini(ceili(c.y + rc), grid_size.y - 1) + 1):
			for x in range(maxi(floori(c.x - rc), 0), mini(ceili(c.x + rc), grid_size.x - 1) + 1):
				var d := Vector2(x - c.x, y - c.y).length() * CELL
				if d < r:
					arr[y * grid_size.x + x] += v * (1.0 - d / r)
		_field[metric] = arr


static func _falloff(v: float, r: float, d: float) -> float:
	return v * (1.0 - d / r) if d < r else 0.0


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, terrain.height2(p), p.y)


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


static func _rect(centre: Vector2, t: Vector2, n: Vector2, w: float, d: float) -> PackedVector2Array:
	var hw := t * w / 2.0
	var hd := n * d / 2.0
	return PackedVector2Array([centre - hw - hd, centre + hw - hd, centre + hw + hd, centre - hw + hd])


## Two convex quads overlap (separating axis test), allowing them to touch.
static func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly in [a, b]:
		for k in 4:
			var edge: Vector2 = poly[(k + 1) % 4] - poly[k]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var a_min := INF
			var a_max := -INF
			var b_min := INF
			var b_max := -INF
			for p in a:
				a_min = minf(a_min, axis.dot(p))
				a_max = maxf(a_max, axis.dot(p))
			for p in b:
				b_min = minf(b_min, axis.dot(p))
				b_max = maxf(b_max, axis.dot(p))
			if a_max <= b_min + 0.3 or b_max <= a_min + 0.3:
				return false
	return true


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	var a := 0.0
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		var cross := p.x * q.y - q.x * p.y
		a += cross
		c += (p + q) * cross
	if absf(a) < 0.001:
		return poly[0]
	return c / (3.0 * a)


static func _bbox(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _segment_at(cum: PackedFloat32Array, s: float) -> int:
	for k in cum.size() - 1:
		if s < cum[k + 1]:
			return k
	return cum.size() - 2


static func _point_at(poly: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	var k := _segment_at(cum, s)
	var seg := cum[k + 1] - cum[k]
	return poly[k].lerp(poly[(k + 1) % poly.size()], (s - cum[k]) / seg if seg > 0.0 else 0.0)


func _lot_key(lot: Dictionary) -> String:
	return "%d,%d,%d" % [roundi(lot.pos.x * 2.0), roundi(lot.pos.z * 2.0), roundi(lot.rot * 20.0)]
