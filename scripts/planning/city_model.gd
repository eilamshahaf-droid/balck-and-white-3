extends RefCounted
## The city-planning model with no graphics: blocks, lots, landmarks, street
## details and the influence fields they add up to. Three levels, as in the
## design doc ("building at a modern scale"):
##   neighbourhood - zone a block (homes, shops, industry) and how dense;
##                   buildings then rise on their own by zone and demand,
##   plot          - place a landmark (temple, station, square, tower, factory),
##   street        - small details (tree, bench, camera, shrine).
## Every structure stamps a value per metric that fades with distance, and the
## fields are kept per lot, so reading a value is cheap (BW2's PlacementData).

const City = preload("res://scripts/city.gd")
const P: PlanningSettings = preload("res://data/planning.tres")

const METRICS := ["belief", "commerce", "quality", "fear", "influence"]
const ZONES := ["residential", "commercial", "industrial"]
const LOTS_PER_BLOCK := 6
const LANDMARK_LOTS := [2, 3]     # a landmark takes the two middle lots of its block

var blocks: Array = []     # {i, j, center, size, zone, density, landmark, lots: [lot ids]}
var lots: Array = []       # {block, pos, width, depth, floors, zone}
var details: Array = []    # {kind, pos}
var half_size := Vector2.ZERO

var _field := {}           # metric -> PackedFloat32Array, one value per lot
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7
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
					"size": Vector2(x1 - x0, z1 - z0), "zone": "", "density": 1, "landmark": "", "lots": []}
			var w := (x1 - x0) / LOTS_PER_BLOCK
			for n in LOTS_PER_BLOCK:
				block.lots.append(lots.size())
				lots.append({"block": blocks.size(), "pos": Vector3(x0 + w * (n + 0.5), 0, block.center.z),
						"width": w, "depth": z1 - z0, "floors": 0, "zone": ""})
			blocks.append(block)
	for m in METRICS:
		var arr := PackedFloat32Array()
		arr.resize(lots.size())
		_field[m] = arr


## The city already exists (design doc): shops on the avenues side, homes in
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


func place_landmark(b: int, kind: String) -> bool:
	var block: Dictionary = blocks[b]
	if block.landmark != "" or not P.landmarks.has(kind):
		return false
	for n in LANDMARK_LOTS:
		_demolish(block.lots[n])
	block.landmark = kind
	_stamp(P.landmarks[kind], block.center, 1.0, _reach_bonus(kind))
	return true


func remove_landmark(b: int) -> void:
	var block: Dictionary = blocks[b]
	if block.landmark == "":
		return
	_stamp(P.landmarks[block.landmark], block.center, -1.0, _reach_bonus(block.landmark))
	block.landmark = ""


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


# --- The city filling itself in ---

## One building goes up (or is replaced) somewhere it is wanted. Returns the
## lot id that changed, or -1.
func step() -> int:
	for attempt in 12:
		var lot_id := _rng.randi_range(0, lots.size() - 1)
		var lot: Dictionary = lots[lot_id]
		var block: Dictionary = blocks[lot.block]
		if block.zone == "" or _is_landmark_lot(lot_id):
			continue
		var target: int = P.floors_per_density[block.density - 1]
		# Already the right kind and about the right height for the density.
		if lot.zone == block.zone and lot.floors >= target * 0.4 and lot.floors <= ceili(target * 1.1):
			continue
		if not _wanted(lot_id, block.zone):
			continue
		_demolish(lot_id)
		_build(lot_id)
		return lot_id
	return -1


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
	if block.zone == "" or _is_landmark_lot(lot_id):
		return
	var top: int = P.floors_per_density[block.density - 1]
	# Better places get taller buildings.
	var appeal := clampf((value("quality", lot_id) + value("commerce", lot_id)) / 12.0, 0.0, 1.0)
	lot.floors = maxi(1, roundi(top * lerpf(0.5, 1.0, appeal) * _rng.randf_range(0.8, 1.1)))
	lot.zone = block.zone
	_stamp(P.zone_effects[lot.zone], lot.pos, 1.0)


func _demolish(lot_id: int) -> void:
	var lot: Dictionary = lots[lot_id]
	if lot.floors == 0:
		return
	_stamp(P.zone_effects[lot.zone], lot.pos, -1.0)
	lot.floors = 0
	lot.zone = ""


# --- Reading the city ---

## A metric's value at a lot: the stamped field plus the mixed-use bonus.
func value(metric: String, lot_id: int) -> float:
	var v: float = _field[metric][lot_id]
	if _mixed_use(lots[lot_id].block):
		if metric == "quality":
			v += P.mixed_use_quality
		elif metric == "commerce":
			v += P.mixed_use_commerce
	return v


func residents(lot_id: int) -> int:
	var lot: Dictionary = lots[lot_id]
	return lot.floors * P.residents_per_floor if lot.zone == "residential" else 0


func residents_near(pos: Vector3, radius: float) -> int:
	var total := 0
	for n in lots.size():
		if lots[n].zone == "residential" and lots[n].pos.distance_to(pos) < radius:
			total += residents(n)
	return total


func block_value(metric: String, b: int) -> float:
	var sum := 0.0
	for lot_id in blocks[b].lots:
		sum += value(metric, lot_id)
	return sum / LOTS_PER_BLOCK


## How placing `kind` at `pos` would change each metric in the block there:
## the number shown before placing.
func preview(kind: String, pos: Vector3, b: int) -> Dictionary:
	var def: Dictionary = P.landmarks.get(kind, P.details.get(kind, {}))
	var bonus := _reach_bonus(kind)
	var out := {}
	for metric in def:
		var v: float = def[metric][0]
		var r: float = def[metric][1] + bonus
		var sum := 0.0
		for lot_id in blocks[b].lots:
			sum += _falloff(v, r, lots[lot_id].pos.distance_to(pos))
		out[metric] = sum / LOTS_PER_BLOCK
	return out


func reach_of(kind: String) -> float:
	var def: Dictionary = P.landmarks.get(kind, P.details.get(kind, {}))
	var r := 0.0
	for metric in def:
		r = maxf(r, def[metric][1])
	return r + _reach_bonus(kind)


func stats() -> Dictionary:
	var population := 0
	var prayer := 0.0
	var quality := 0.0
	var fear := 0.0
	var commerce := 0.0
	var built := 0
	for n in lots.size():
		var people := residents(n)
		population += people
		prayer += people * P.prayer_per_resident * clampf(value("belief", n) / P.belief_field_full, 0.0, 1.0)
		if people > 0:
			quality += value("quality", n) * people
			fear += value("fear", n) * people
		if lots[n].zone == "commercial" or lots[n].zone == "industrial":
			commerce += lots[n].floors
		if lots[n].floors > 0:
			built += 1
	var landmarks := 0
	for b in blocks:
		if b.landmark != "":
			landmarks += 1
	return {"population": population, "prayer": prayer, "jobs": commerce * 10,
			"quality": quality / maxi(population, 1), "fear": fear / maxi(population, 1),
			"built": built, "landmarks": landmarks}


func block_at(pos: Vector3) -> int:
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		if absf(pos.x - block.center.x) <= block.size.x / 2.0 and absf(pos.z - block.center.z) <= block.size.y / 2.0:
			return b
	return -1


func lot_at(pos: Vector3) -> int:
	var b := block_at(pos)
	if b < 0:
		return -1
	for lot_id in blocks[b].lots:
		if absf(pos.x - lots[lot_id].pos.x) <= lots[lot_id].width / 2.0:
			return lot_id
	return -1


# --- Internals ---

func _is_landmark_lot(lot_id: int) -> bool:
	var block: Dictionary = blocks[lots[lot_id].block]
	return block.landmark != "" and block.lots.find(lot_id) in LANDMARK_LOTS


func _mixed_use(b: int) -> bool:
	var block: Dictionary = blocks[b]
	if block.zone == "":
		return false
	var rows := City.STREETS - 1
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var i: int = block.i + d.x
		var j: int = block.j + d.y
		if i < 0 or j < 0 or i >= City.AVENUES - 1 or j >= rows:
			continue
		var other: String = blocks[i * rows + j].zone
		if other != "" and other != block.zone:
			return true
	return false


func _reach_bonus(kind: String) -> float:
	return maxf(P.tower_height - 30.0, 0.0) * P.height_reach_per_metre if kind == "tower" else 0.0


## Add (sign 1) or take away (sign -1) a structure's fields around `pos`.
func _stamp(def: Dictionary, pos: Vector3, sign: float, reach_bonus := 0.0) -> void:
	for metric in def:
		var v: float = def[metric][0] * sign
		var r: float = def[metric][1] + reach_bonus
		var arr: PackedFloat32Array = _field[metric]
		for n in lots.size():
			var d: float = lots[n].pos.distance_to(pos)
			if d < r:
				arr[n] += _falloff(v, r, d)
		_field[metric] = arr


static func _falloff(v: float, r: float, d: float) -> float:
	return v * (1.0 - d / r) if d < r else 0.0


func _intersection(i: int, j: int) -> Vector3:
	return Vector3(i * City.AVENUE_SPACING - half_size.x, 0.0, j * City.STREET_SPACING - half_size.y)
