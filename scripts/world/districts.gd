extends Node
## Splits the city into districts and keeps the claim meter of every building
## (design doc: "איך משתלטים על מקום"). A meter fills from 0 to full and the
## building is yours; it slips back below a threshold. Only the power route
## fills it so far: believers who live there, believers in the street outside,
## and your buildings next door. Outside your influence zone (next to one of
## your buildings) only an abandoned place takes a claim. The cult starts from
## its headquarters, where most believers live, in a neglected district full of
## abandoned places. Neighbours are buildings across a narrow street; a wide
## avenue stops the zone. A district is yours once enough of its buildings are.
## Decrees ask owns(), so there is one answer.

signal layout_ready
signal building_changed(index: int, yours: bool)
signal district_controlled(district: int)

const S = preload("res://data/districts.tres")
const B = preload("res://data/balance.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")

## Every building, by index. A demolished one stays in the list as null.
var buildings: Array[Node3D] = []
## Each building's box (width, height, depth).
var sizes := PackedVector3Array()
## The cult's first building, or -1 until it has believers living somewhere.
var headquarters := -1

var _district_of := PackedInt32Array()   # -1 once demolished
var _yours := PackedByteArray()
var _claim := PackedFloat32Array()       # 0..claim_full; full = yours
var _abandoned := PackedByteArray()
var _neighbors: Array[PackedInt32Array] = []
var _totals := PackedInt32Array()        # standing buildings per district
var _owned := PackedInt32Array()         # buildings of yours per district
var _controlled := PackedByteArray()
var _believers := PackedVector3Array()   # reused every tick
var _index := {}                         # building -> index
var _faithful := PackedInt32Array()      # residents who believe, per building, counted every tick
var _timer := 0.0

@onready var city: Node3D = get_parent()
@onready var population: Node = get_node("../Population")


func _ready() -> void:
	set_physics_process(false)
	await city.ready  # the city builds its blocks in its own _ready, after ours
	_collect()
	set_physics_process(true)
	layout_ready.emit()


func district_count() -> int:
	return S.columns * S.rows


func district_at(p: Vector3) -> int:
	var block: Vector2i = city.block_of(p)
	return _band(block.y, city.STREETS - 1, S.rows) * S.columns + _band(block.x, city.AVENUES - 1, S.columns)


func district_name(d: int) -> String:
	return S.names[d] if d < S.names.size() else "District %d" % (d + 1)


## The district's ground, between the road centre lines around it (x, z).
func district_rect(d: int) -> Rect2:
	var col := d % S.columns
	var row := floori(float(d) / S.columns)
	var a: Vector3 = city.intersection(Vector2i(_edge(col, city.AVENUES - 1, S.columns), _edge(row, city.STREETS - 1, S.rows)))
	var b: Vector3 = city.intersection(Vector2i(_edge(col + 1, city.AVENUES - 1, S.columns), _edge(row + 1, city.STREETS - 1, S.rows)))
	return Rect2(a.x, a.z, b.x - a.x, b.z - a.z)


## Share of the district's standing buildings that are yours, 0..1.
func share(d: int) -> float:
	return float(_owned[d]) / maxi(_totals[d], 1)


func is_controlled(d: int) -> bool:
	return _controlled[d] == 1


func is_yours(index: int) -> bool:
	return _yours[index] == 1


## Is `building` the god's? Decrees ask here, so there is one answer.
func owns(building: Node3D) -> bool:
	var i: int = _index.get(building, -1)
	return i >= 0 and _yours[i] == 1


## The claim meter of a building, 0..1.
func claim_of(index: int) -> float:
	return _claim[index] / S.claim_full


func is_abandoned(index: int) -> bool:
	return _abandoned[index] == 1


## The standing building nearest `p` on the ground, or -1.
func building_near(p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in buildings.size():
		if _district_of[i] < 0:
			continue
		var q := buildings[i].global_position
		var d := Vector2(q.x - p.x, q.z - p.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


## A rival knocks the meter back (City Hall's inspection, the police).
func lower_claim(building: Node3D, amount: float) -> void:
	var i: int = _index.get(building, -1)
	if i < 0:
		return
	_claim[i] = maxf(_claim[i] - amount, 0.0)
	if _yours[i] == 1 and _claim[i] < S.lose_below:
		_set_side(i, false)


func converted_buildings() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in buildings.size():
		if _yours[i] == 1:
			out.append(buildings[i])
	return out


## A building was torn down: it no longer counts for anyone.
func remove_building(building: Node3D) -> void:
	var i := buildings.find(building)
	if i < 0:
		return
	if _yours[i] == 1:
		_set_side(i, false)
	_totals[_district_of[i]] -= 1
	_district_of[i] = -1
	_claim[i] = 0.0
	buildings[i] = null
	_index.erase(building)
	building_changed.emit(i, false)


## Testing shortcut: the `count` buildings nearest `p` become yours at once
## (their residents start believing, so the next tick agrees).
func convert_near(p: Vector3, count: int) -> void:
	var order: Array[int] = []
	for i in buildings.size():
		if _district_of[i] >= 0 and _yours[i] == 0:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return buildings[a].global_position.distance_squared_to(p) < buildings[b].global_position.distance_squared_to(p))
	var chosen := {}
	for i in order.slice(0, count):
		chosen[buildings[i]] = true
		_claim[i] = S.claim_full
		_set_side(i, true)
	for r: Resident in population.residents:
		if chosen.has(r.home):
			r.belief = maxf(r.belief, B.believer_threshold + 0.2)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.tick
	_gather_believers()
	_count_faithful()
	if headquarters < 0:
		_found_headquarters()
	var r2 := S.believer_radius * S.believer_radius
	for i in buildings.size():
		if _district_of[i] < 0:
			continue
		var zone := 0
		for j in _neighbors[i]:
			zone += _yours[j]
		var gain := 0.0
		# The beachhead rule: outside your zone only an abandoned place can be claimed.
		if _yours[i] == 1 or zone > 0 or _abandoned[i] == 1:
			var p := buildings[i].global_position
			var street := 0
			for q in _believers:
				if Vector2(q.x - p.x, q.z - p.z).length_squared() < r2:
					street += 1
			gain = S.resident_rate * _faithful[i] + S.street_rate * street + S.zone_rate * zone
		if gain == 0.0:
			gain = -S.decay
		_claim[i] = clampf(_claim[i] + gain * S.tick, 0.0, S.claim_full)
		if _yours[i] == 0 and _claim[i] >= S.claim_full:
			_set_side(i, true)
		elif _yours[i] == 1 and _claim[i] < S.lose_below:
			_set_side(i, false)


func _gather_believers() -> void:
	var people := get_tree().get_nodes_in_group("citizens")
	_believers.resize(people.size())
	var n := 0
	for c in people:
		if c.belief > B.believer_threshold:
			_believers[n] = c.global_position
			n += 1
	_believers.resize(n)


func _count_faithful() -> void:
	_faithful.fill(0)
	for r: Resident in population.residents:
		var i: int = _index.get(r.home, -1)
		if i >= 0 and r.belief > B.believer_threshold:
			_faithful[i] += 1


## The building where most believers live becomes the cult's first; its
## district is the neglected start district, full of abandoned places.
func _found_headquarters() -> void:
	var best := -1
	for i in buildings.size():
		if _faithful[i] > 0 and (best < 0 or _faithful[i] > _faithful[best]):
			best = i
	if best < 0:
		return
	headquarters = best
	var start := _district_of[best]
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in buildings.size():
		var odds := S.abandoned_start if _district_of[i] == start else S.abandoned_elsewhere
		if i != best and rng.randf() < odds:
			_abandoned[i] = 1
			building_changed.emit(i, false)
	_claim[best] = S.claim_full
	_set_side(best, true)


func _set_side(i: int, mine: bool) -> void:
	_yours[i] = 1 if mine else 0
	var d := _district_of[i]
	_owned[d] += 1 if mine else -1
	building_changed.emit(i, mine)
	if mine and _controlled[d] == 0 and share(d) >= S.control_share:
		_controlled[d] = 1
		district_controlled.emit(d)


func _collect() -> void:
	var count := district_count()
	_totals.resize(count)
	_totals.fill(0)
	_owned.resize(count)
	_owned.fill(0)
	_controlled.resize(count)
	_controlled.fill(0)
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Node3D
		var d := district_at(b.global_position)
		_index[b] = buildings.size()
		buildings.append(b)
		sizes.append(DivineSign.building_size(b))
		_district_of.append(d)
		_totals[d] += 1
	var n := buildings.size()
	_yours.resize(n)
	_yours.fill(0)
	_claim.resize(n)
	_claim.fill(0.0)
	_abandoned.resize(n)
	_abandoned.fill(0)
	_faithful.resize(n)
	for i in n:
		var near := PackedInt32Array()
		for j in n:
			if i != j and _gap(i, j) < S.neighbor_gap:
				near.append(j)
		_neighbors.append(near)


## Ground distance between two buildings' footprints (0 if they touch).
func _gap(i: int, j: int) -> float:
	var a := buildings[i].global_position
	var b := buildings[j].global_position
	var dx := absf(a.x - b.x) - (sizes[i].x + sizes[j].x) / 2.0
	var dz := absf(a.z - b.z) - (sizes[i].z + sizes[j].z) / 2.0
	return maxf(maxf(dx, dz), 0.0)


## Which of `parts` bands a block falls in, with band edges on road lines.
static func _band(block: int, blocks: int, parts: int) -> int:
	var band := 0
	for k in range(1, parts):
		if block >= _edge(k, blocks, parts):
			band = k
	return band


static func _edge(k: int, blocks: int, parts: int) -> int:
	return roundi(float(k * blocks) / parts)
