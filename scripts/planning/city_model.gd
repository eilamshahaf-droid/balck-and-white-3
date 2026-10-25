extends RefCounted
## The city-planning model with no graphics: blocks, lots, landmarks, street
## details and the influence fields they add up to. Three levels, as in the
## design doc ("building at a modern scale"):
##   neighbourhood - zone a block (homes, shops, industry) and how dense;
##                   buildings then rise on their own by zone and demand,
##   plot          - place a landmark anywhere in a block,
##   street        - small details, or close a street segment into a plaza.
## Every structure stamps a value per metric that fades with distance onto a
## fine grid (BW2's PlacementData), so the fields are smooth blobs, not blocks.
##
## The city grows organically: lots have different widths, the most wanted
## spots are built first, heights follow land value, and each building is
## slowly rebuilt in the look of whichever god its surroundings belong to
## (the doc's gradual conversion): good, evil, or neutral (grey).

const City = preload("res://scripts/city.gd")
const P: PlanningSettings = preload("res://data/planning.tres")

const METRICS := ["belief", "commerce", "quality", "fear", "influence"]
const ZONES := ["residential", "commercial", "industrial"]
const CHARACTERS := ["", "good", "evil", "grey"]
const CELL := 6.0                 # metres per field cell
const MARGIN := 60.0              # fields reach this far past the city edge

var blocks: Array = []     # {i, j, center, size, zone, density, lots: [lot ids]}
var lots: Array = []       # {block, pos, width, depth, floors, zone, character, landmark, seed}
var landmarks: Array = []  # {kind, pos, block, width, lots}
var details: Array = []    # {kind, pos}
var plazas: Array = []     # {pos, size}
var half_size := Vector2.ZERO
var grid_size := Vector2i.ZERO
var grid_origin := Vector2.ZERO

var _field := {}           # metric -> PackedFloat32Array, grid_size.x * grid_size.y
var _block_residents := PackedInt32Array()
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 7) -> void:
	_rng.seed = seed_value
	half_size = Vector2((City.AVENUES - 1) * City.AVENUE_SPACING, (City.STREETS - 1) * City.STREET_SPACING) / 2.0
	for i in City.AVENUES - 1:
		for j in City.STREETS - 1:
			var a := _intersection(i, j)
			var b := _intersection(i + 1, j + 1)
			var x0 := a.x + City.AVENUE_WIDTH / 2.0 + City.SIDEWALK
			var x1 := b.x - City.AVENUE_WIDTH / 2.0 - City.SIDEWALK
			var z0 := a.z + City.STREET_WIDTH / 2.0 + City.SIDEWALK
			var z1 := b.z - City.STREET_WIDTH / 2.0 - City.SIDEWALK
			var block := {"i": i, "j": j, "center": Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0),
					"size": Vector2(x1 - x0, z1 - z0), "zone": "", "density": 1, "lots": []}
			# Lots of different widths, like the 25 ft lots of New York merging into bigger buildings.
			var x := x0
			while x1 - x > 0.5:
				var w := _rng.randf_range(P.lot_width_min, P.lot_width_max)
				if x1 - x - w < P.lot_width_min:
					w = x1 - x
				block.lots.append(lots.size())
				lots.append({"block": blocks.size(), "pos": Vector3(x + w / 2.0, 0, block.center.z),
						"width": w, "depth": z1 - z0, "floors": 0, "zone": "", "character": "",
						"landmark": null, "seed": _rng.randf()})
				x += w
			blocks.append(block)
	_block_residents.resize(blocks.size())
	grid_origin = -half_size - Vector2.ONE * MARGIN
	grid_size = Vector2i(ceili((half_size.x + MARGIN) * 2.0 / CELL) + 1, ceili((half_size.y + MARGIN) * 2.0 / CELL) + 1)
	for m in METRICS:
		var arr := PackedFloat32Array()
		arr.resize(grid_size.x * grid_size.y)
		_field[m] = arr


## The city already exists (design doc): shops on some streets, homes in
## between, some industry at the edges, all partly built.
func seed_existing_city() -> void:
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		var edge: bool = block.i == 0 or block.i == City.AVENUES - 2
		var zone := "residential"
		if edge and block.j % 4 == 0:
			zone = "industrial"
		elif block.j % 3 == 0:
			zone = "commercial"
		set_zone(b, zone)
		block.density = _rng.randi_range(1, 2)
		for lot_id in block.lots:
			if _rng.randf() < 0.6:
				_build(lot_id)


# --- Player actions ---

func set_zone(b: int, zone: String) -> void:
	var block: Dictionary = blocks[b]
	if block.zone == zone:
		return
	block.zone = zone
	# Buildings of another zone don't vanish at once; they are replaced one by
	# one as the area grows (the doc's gradual conversion).
	if zone == "":
		for lot_id in block.lots:
			_demolish(lot_id)


func change_density(b: int, step: int) -> void:
	blocks[b].density = clampi(blocks[b].density + step, 1, 3)


## Where a landmark of `kind` would stand if placed at `pos`: the middle of its
## footprint, kept inside the block. Vector3.INF if not on a block.
func landmark_centre(kind: String, pos: Vector3) -> Vector3:
	var b := block_at(pos)
	if b < 0:
		return Vector3.INF
	var block: Dictionary = blocks[b]
	var half: float = minf(P.landmark_width.get(kind, 20.0), block.size.x) / 2.0
	var x := clampf(pos.x, block.center.x - block.size.x / 2.0 + half, block.center.x + block.size.x / 2.0 - half)
	return Vector3(x, 0, block.center.z)


## Place a landmark wherever it is put in a block; it takes the lots under it.
## Returns the landmark, or an empty dictionary if something is in the way.
func place_landmark(kind: String, pos: Vector3) -> Dictionary:
	var centre := landmark_centre(kind, pos)
	if centre == Vector3.INF or not P.landmarks.has(kind):
		return {}
	var b := block_at(centre)
	var width: float = minf(P.landmark_width[kind], blocks[b].size.x)
	var taken: Array = []
	for lot_id in blocks[b].lots:
		var lot: Dictionary = lots[lot_id]
		if absf(lot.pos.x - centre.x) < (width + lot.width) / 2.0 - 1.0:
			if lot.landmark != null:
				return {}
			taken.append(lot_id)
	var lm := {"kind": kind, "pos": centre, "block": b, "width": width, "lots": taken}
	for lot_id in taken:
		_demolish(lot_id)
		lots[lot_id].landmark = lm
	landmarks.append(lm)
	_stamp(P.landmarks[kind], centre, 1.0, _reach_bonus(kind))
	return lm


## Remove the landmark under `pos`. Returns it, or an empty dictionary.
func remove_landmark_at(pos: Vector3) -> Dictionary:
	var lot_id := lot_at(pos)
	if lot_id < 0 or lots[lot_id].landmark == null:
		return {}
	var lm: Dictionary = lots[lot_id].landmark
	_stamp(P.landmarks[lm.kind], lm.pos, -1.0, _reach_bonus(lm.kind))
	for n in lm.lots:
		lots[n].landmark = null
	landmarks.erase(lm)
	return lm


func place_detail(kind: String, pos: Vector3) -> void:
	details.append({"kind": kind, "pos": pos})
	_stamp(P.details[kind], pos, 1.0)


## Remove a street detail within 6 m of `pos`. Returns its index, or -1.
func remove_detail_near(pos: Vector3) -> int:
	for n in details.size():
		if details[n].pos.distance_to(pos) < 6.0:
			_stamp(P.details[details[n].kind], details[n].pos, -1.0)
			details.remove_at(n)
			return n
	return -1


## The cross-street segment (between two avenues) under `pos`, as {pos, size},
## or an empty dictionary. Avenues stay open: they carry the city's traffic.
func street_segment_at(pos: Vector3) -> Dictionary:
	var j := roundi((pos.z + half_size.y) / City.STREET_SPACING)
	var street_z := j * City.STREET_SPACING - half_size.y
	if j <= 0 or j >= City.STREETS - 1 or absf(pos.z - street_z) > City.STREET_WIDTH / 2.0 + City.SIDEWALK:
		return {}
	var i := floori((pos.x + half_size.x) / City.AVENUE_SPACING)
	if i < 0 or i >= City.AVENUES - 1:
		return {}
	var x0 := i * City.AVENUE_SPACING - half_size.x + City.AVENUE_WIDTH / 2.0
	var x1 := (i + 1) * City.AVENUE_SPACING - half_size.x - City.AVENUE_WIDTH / 2.0
	if pos.x < x0 or pos.x > x1:
		return {}
	return {"pos": Vector3((x0 + x1) / 2.0, 0, street_z), "size": Vector2(x1 - x0, City.STREET_WIDTH + City.SIDEWALK * 2.0)}


func place_plaza(pos: Vector3) -> Dictionary:
	var seg := street_segment_at(pos)
	if seg.is_empty() or plaza_index_at(pos) >= 0:
		return {}
	plazas.append(seg)
	_stamp(P.plaza, seg.pos, 1.0)
	return seg


func plaza_index_at(pos: Vector3) -> int:
	var seg := street_segment_at(pos)
	if seg.is_empty():
		return -1
	for n in plazas.size():
		if plazas[n].pos.distance_to(seg.pos) < 1.0:
			return n
	return -1


func remove_plaza(n: int) -> void:
	_stamp(P.plaza, plazas[n].pos, -1.0)
	plazas.remove_at(n)


# --- The city filling itself in ---

## One building goes up, or is rebuilt in a new look, where it is most wanted:
## of a few random lots that need work, the one with the highest land value.
## Returns the lot id that changed, or -1.
func step() -> int:
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
	if mixed_use(lots[lot_id].block):
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


func block_value(metric: String, b: int) -> float:
	var sum := 0.0
	for lot_id in blocks[b].lots:
		sum += value(metric, lot_id)
	return sum / blocks[b].lots.size()


## How placing `kind` at `pos` would change each metric in the block there:
## the number shown before placing.
func preview(kind: String, pos: Vector3, b: int) -> Dictionary:
	var def := definition(kind)
	var bonus := _reach_bonus(kind)
	var out := {}
	for metric in def:
		var v: float = def[metric][0]
		var r: float = def[metric][1] + bonus
		var sum := 0.0
		for lot_id in blocks[b].lots:
			sum += _falloff(v, r, lots[lot_id].pos.distance_to(pos))
		out[metric] = sum / blocks[b].lots.size()
	return out


func definition(kind: String) -> Dictionary:
	if kind == "plaza":
		return P.plaza
	return P.landmarks.get(kind, P.details.get(kind, {}))


func reach_of(kind: String) -> float:
	var def := definition(kind)
	var r := 0.0
	for metric in def:
		r = maxf(r, def[metric][1])
	return r + _reach_bonus(kind)


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
	var avg_quality := quality / maxi(population, 1)
	var avg_fear := fear / maxi(population, 1)
	return {"population": population, "prayer": prayer, "jobs": jobs, "quality": avg_quality, "fear": avg_fear,
			"migrants": population * P.migrants_per_quality * maxf(avg_quality, 0.0),
			"power": population * P.power_per_fear * avg_fear, "money": money,
			"built": built, "landmarks": landmarks.size(), "looks": looks}


func block_at(pos: Vector3) -> int:
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		if absf(pos.x - block.center.x) <= block.size.x / 2.0 and absf(pos.z - block.center.z) <= block.size.y / 2.0:
			return b
	return -1


func block_index(i: int, j: int) -> int:
	return i * (City.STREETS - 1) + j


func lot_at(pos: Vector3) -> int:
	var b := block_at(pos)
	if b < 0:
		return -1
	for lot_id in blocks[b].lots:
		if absf(pos.x - lots[lot_id].pos.x) <= lots[lot_id].width / 2.0:
			return lot_id
	return -1


func field_grid(metric: String) -> PackedFloat32Array:
	return _field[metric]


func mixed_use(b: int) -> bool:
	var block: Dictionary = blocks[b]
	if block.zone == "":
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var i: int = block.i + d.x
		var j: int = block.j + d.y
		if i < 0 or j < 0 or i >= City.AVENUES - 1 or j >= City.STREETS - 1:
			continue
		var other: String = blocks[block_index(i, j)].zone
		if other != "" and other != block.zone:
			return true
	return false


# --- Internals ---

func _reach_bonus(kind: String) -> float:
	return maxf(P.tower_height - 30.0, 0.0) * P.height_reach_per_metre if kind == "tower" else 0.0


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


func _intersection(i: int, j: int) -> Vector3:
	return Vector3(i * City.AVENUE_SPACING - half_size.x, 0.0, j * City.STREET_SPACING - half_size.y)
