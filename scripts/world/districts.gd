extends Node
## Splits the city into districts and keeps track of which buildings are yours
## (design doc: "השתלטות על רובע"). A building people live in is yours while
## enough of its residents believe (the same rule decrees use). An empty one
## (offices, shops) turns through influence: believers on the street outside
## lean on it, and every building already yours leans on its neighbours, like
## religious pressure in Civilization. Neighbours are buildings across a narrow
## street; a wide avenue stops the spread, so believers have to carry it over.
## A district is yours once enough of its buildings are.

signal layout_ready
signal building_changed(index: int, yours: bool)
signal district_controlled(district: int)

const S = preload("res://data/districts.tres")
const B = preload("res://data/balance.tres")
const D: DecreeSettings = preload("res://data/decrees.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")

## Every building, by index. A demolished one stays in the list as null.
var buildings: Array[Node3D] = []
## Each building's box (width, height, depth).
var sizes := PackedVector3Array()

var _district_of := PackedInt32Array()   # -1 once demolished
var _yours := PackedByteArray()
var _faith := PackedFloat32Array()       # 0..1; at 1 the building turns
var _neighbors: Array[PackedInt32Array] = []
var _totals := PackedInt32Array()        # standing buildings per district
var _owned := PackedInt32Array()         # buildings of yours per district
var _controlled := PackedByteArray()
var _believers := PackedVector3Array()   # reused every tick
var _index := {}                         # building -> index
var _residents := PackedInt32Array()     # per building, counted every tick
var _faithful := PackedInt32Array()      # residents who believe, per building
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
	_faith[i] = 0.0
	buildings[i] = null
	_index.erase(building)


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
		_faith[i] = 1.0
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
	_count_residents()
	var r2 := S.believer_radius * S.believer_radius
	for i in buildings.size():
		if _district_of[i] < 0:
			continue
		if _residents[i] > 0:
			var mine := float(_faithful[i]) / _residents[i] >= D.owner_share
			_faith[i] = 1.0 if mine else 0.0
			if mine != (_yours[i] == 1):
				_set_side(i, mine)
			continue
		var p := buildings[i].global_position
		var near := 0
		for q in _believers:
			if Vector2(q.x - p.x, q.z - p.z).length_squared() < r2:
				near += 1
		var pressure := 0
		for j in _neighbors[i]:
			pressure += _yours[j]
		var gain := S.believer_rate * near + S.neighbor_rate * pressure - S.decay
		_faith[i] = clampf(_faith[i] + gain * S.tick, 0.0, 1.0)
		if _yours[i] == 0 and _faith[i] >= 1.0:
			_set_side(i, true)
		elif _yours[i] == 1 and _faith[i] < S.lose_below:
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


func _count_residents() -> void:
	_residents.fill(0)
	_faithful.fill(0)
	for r: Resident in population.residents:
		var i: int = _index.get(r.home, -1)
		if i >= 0:
			_residents[i] += 1
			if r.belief > B.believer_threshold:
				_faithful[i] += 1


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
	_faith.resize(n)
	_faith.fill(0.0)
	_residents.resize(n)
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
