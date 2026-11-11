class_name Districts
extends Node
## Splits the city into districts and keeps who holds every building. Eilam's
## rule: a building is yours once most of the people who live there believe
## (Population's residents); an empty one is yours while a believer sits in on
## it. Campaigns (campaigns.gd) are how the player tips a building: force, buying
## or missionaries. The cult starts from the start district's core building (its
## headquarters, always yours), in a neglected district with empty, abandoned
## buildings. A district is yours once its core and enough of its buildings are. Decrees ask owns(), so there is one answer.
## A building can only become yours if it borders one you already hold (can_claim),
## so the city is taken outwards from the headquarters; abandoned places too. A core
## also needs most of the buildings around it first.

signal layout_ready
signal building_changed(index: int, yours: bool)
signal district_controlled(district: int)
## Every building was counted again (a few times a second).
signal counted
## Building `index` stands empty for good now (start district, fire, roaches).
signal building_abandoned(index: int)
## District `district` has a different core building now (the old one was demolished).
signal core_changed(district: int)

const S: DistrictSettings = preload("res://data/districts.tres")

## Every building, by index. A demolished one stays in the list as null.
var buildings: Array[Node3D] = []
## Each building's box (width, height, depth).
var sizes := PackedVector3Array()
## The cult's first building: the start district's core.
var headquarters := -1
## How free each district is (0..1); see DistrictSettings.independence.
var independence := PackedFloat32Array()

var _district_of := PackedInt32Array()   # -1 once demolished
var _yours := PackedByteArray()
var _abandoned := PackedByteArray()
var _totals := PackedInt32Array()        # standing buildings per district
var _owned := PackedInt32Array()         # buildings of yours per district
var _controlled := PackedByteArray()
var _unlocked := PackedByteArray()
var _core := PackedInt32Array()          # per district: index of its core building, -1 if none
var _index := {}                         # building -> index
var _residents := PackedInt32Array()     # people who live there, counted every tick
var _believers := PackedInt32Array()     # of them, believers
var _presence := PackedFloat32Array()    # believing presence (residents and sit-ins)
var _graph := BuildingGraph.new()
var _timer := 0.0

@onready var city: Node3D = get_parent()
@onready var population: Population = get_node("../Population")


func _ready() -> void:
	set_physics_process(false)
	await city.ready  # the city builds its blocks in its own _ready, after ours
	_collect()
	set_physics_process(true)
	layout_ready.emit()


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.tick
	_count()
	for i in buildings.size():
		if _district_of[i] < 0:
			continue
		var mine := _holds(i)
		if mine and _yours[i] == 0 and not can_claim(i):
			mine = false
		if mine != (_yours[i] == 1):
			_set_side(i, mine)
	counted.emit()


func district_count() -> int:
	return S.columns * S.rows


func district_at(p: Vector3) -> int:
	var block: Vector2i = city.block_of(p)
	return _band(block.y, city.STREETS - 1, S.rows) * S.columns + _band(block.x, city.AVENUES - 1, S.columns)


## The kind of district (DistrictSettings.kinds) at `p`: who lives there.
func kind_at(p: Vector3) -> String:
	return S.kind_of(district_at(p))


## The cult's first building, or null.
func start_building() -> Node3D:
	return buildings[headquarters] if headquarters >= 0 else null


## Can the player work in district `d` yet? Only the start district for now:
## the stages after it are not built.
func is_unlocked(d: int) -> bool:
	return d >= 0 and d < _unlocked.size() and _unlocked[d] == 1


## Is the place where `building` stands open to the player?
func is_open(building: Node3D) -> bool:
	return is_unlocked(district_at(building.global_position))


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


## The district's hard central building, as an index (-1 when it has none).
func core_of(d: int) -> int:
	return _core[d]


## Once a district's core is yours, City Hall and the police leave it alone.
func leaves_alone(d: int) -> bool:
	return _core[d] >= 0 and _yours[_core[d]] == 1


func is_yours(index: int) -> bool:
	return _yours[index] == 1


## Is `building` the god's? Decrees ask here, so there is one answer.
## Building `index` could become yours: its district is open, it borders a building you
## hold, and, for a core, enough of the buildings around it are yours (core_base).
func can_claim(index: int) -> bool:
	var d := _district_of[index]
	if index == headquarters:
		return true
	if d < 0 or _unlocked[d] == 0 or not borders_yours(index):
		return false
	return _core[d] != index or core_base(index) >= S.core_base_share


## Building `index` borders a standing building of yours.
func borders_yours(index: int) -> bool:
	for j in _graph.of(index):
		if _yours[j] == 1 and _district_of[j] >= 0:
			return true
	return false


## The share of the standing buildings within core_base_steps borders of `index`
## that are yours.
func core_base(index: int) -> float:
	var near := around(index, S.core_base_steps)
	var held := 0
	for j in near:
		held += _yours[j]
	return float(held) / maxi(near.size(), 1)


## The standing buildings within `steps` borders of building `index` (not itself).
func around(index: int, steps: int) -> Array[int]:
	return _graph.around(index, steps, _demolished())


## Which district building `index` is in, -1 once demolished.
func district_of(index: int) -> int:
	return _district_of[index]


## Building `index` is yours no longer (a thin line gave way): it counts as lost until
## the next count says otherwise.
func lose(index: int) -> void:
	if _yours[index] == 1 and index != headquarters:
		_set_side(index, false)


## The buildings that building `index` borders (demolished ones included).
func borders_of(index: int) -> PackedInt32Array:
	return _graph.of(index)


## `building` is a district's core.
func is_core(building: Node3D) -> bool:
	var i: int = _index.get(building, -1)
	return i >= 0 and _core[_district_of[i]] == i


func owns(building: Node3D) -> bool:
	var i: int = _index.get(building, -1)
	return i >= 0 and _yours[i] == 1


func index_of(building: Node3D) -> int:
	return _index.get(building, -1)


## How well off district `d` is (1 = average; the start district is poor).
func wealth_of(d: int) -> float:
	return S.wealth[d] if d < S.wealth.size() else 1.0


func wealth_at(index: int) -> float:
	return wealth_of(_district_of[index]) if _district_of[index] >= 0 else 1.0


func is_abandoned(index: int) -> bool:
	return _abandoned[index] == 1


func residents_in(index: int) -> int:
	return _residents[index]


func believers_in(building: Node3D) -> int:
	var i: int = _index.get(building, -1)
	return _believers[i] if i >= 0 else 0


func believers_at(index: int) -> int:
	return _believers[index]


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


## Everyone leaves `building` for good: it becomes an abandoned place anyone
## can move into.
func abandon(building: Node3D) -> void:
	if mark_abandoned(building):
		population.evacuate(building)


## `building` was emptied already (a miracle fire burnt it out, roaches):
## Miracles.building_abandoned is connected here. True if it was not before.
func mark_abandoned(building: Node3D) -> bool:
	var i: int = _index.get(building, -1)
	if i < 0 or _abandoned[i] == 1:
		return false
	_abandoned[i] = 1
	building_abandoned.emit(i)
	return true


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
	var d := _district_of[i]
	_totals[d] -= 1
	_district_of[i] = -1
	buildings[i] = null
	_index.erase(building)
	building_changed.emit(i, false)
	if _core[d] == i:
		_core[d] = _pick_core(d)
		core_changed.emit(d)


## Testing shortcut: the `count` buildings nearest `p` become yours at once
## (their residents start believing, so the next count agrees).
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
		_set_side(i, true)
	for r: Resident in population.residents:
		if chosen.has(r.home) and not r.is_believer():
			population.convert_to(r, Resident.Rank.BELIEVER)


## Most residents believe; an empty building, a believer sits in on it.
func _holds(i: int) -> bool:
	if i == headquarters:
		return true
	if _residents[i] == 0:
		return _presence[i] > 0.0
	var needed := S.core_capture_share if _core[_district_of[i]] == i else S.capture_share
	return float(_believers[i]) / _residents[i] > needed


func _count() -> void:
	_residents.fill(0)
	_believers.fill(0)
	for r: Resident in population.residents:
		var i: int = _index.get(r.home, -1)
		if i < 0:
			continue
		_residents[i] += 1
		if r.is_believer():
			_believers[i] += 1
	for i in buildings.size():
		_presence[i] = population.power_presence(buildings[i]) if buildings[i] else 0.0


## The start district's core is the cult's first building; some of the
## district's other buildings stand empty.
func _found_headquarters() -> void:
	var start := S.start_district
	headquarters = _core[start]
	_unlocked[start] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in buildings.size():
		var odds := S.abandoned_start if _district_of[i] == start else S.abandoned_elsewhere
		if i != headquarters and i != _core[_district_of[i]] and rng.randf() < odds:
			abandon(buildings[i])


func _set_side(i: int, mine: bool) -> void:
	_yours[i] = 1 if mine else 0
	var d := _district_of[i]
	_owned[d] += 1 if mine else -1
	building_changed.emit(i, mine)
	if mine and _controlled[d] == 0 and share(d) >= S.control_share \
			and _core[d] >= 0 and _yours[_core[d]] == 1:
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
	_unlocked.resize(count)
	_unlocked.fill(0)
	independence = S.start_independence(count)
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Node3D
		var d := district_at(b.global_position)
		_index[b] = buildings.size()
		buildings.append(b)
		sizes.append(BuildingBox.size_of(b))
		_district_of.append(d)
		_totals[d] += 1
	_find_cores(count)
	var n := buildings.size()
	_yours.resize(n)
	_yours.fill(0)
	_abandoned.resize(n)
	_abandoned.fill(0)
	_residents.resize(n)
	_believers.resize(n)
	_presence.resize(n)
	_find_borders()
	_found_headquarters()


## Which buildings border each other (see DistrictSettings.border_gap), across district
## lines too, so a new district is entered from the edge of one you hold.
func _find_borders() -> void:
	var feet: Array[Rect2] = []
	for i in buildings.size():
		var p := buildings[i].global_position
		var s := Vector2(sizes[i].x, sizes[i].z)
		feet.append(Rect2(Vector2(p.x, p.z) - s / 2.0, s))
	_graph.build(feet, S.border_gap)


func _demolished() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(buildings.size())
	for i in buildings.size():
		out[i] = 1 if _district_of[i] < 0 else 0
	return out


func _find_cores(count: int) -> void:
	_core.resize(count)
	for d in count:
		_core[d] = _pick_core(d)


## The standing building nearest the middle of district `d`, or -1.
func _pick_core(d: int) -> int:
	var middle := district_rect(d).get_center()
	var best := -1
	var best_gap := INF
	for i in buildings.size():
		if _district_of[i] != d:
			continue
		var p := buildings[i].global_position
		var gap := Vector2(p.x, p.z).distance_squared_to(middle)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## Which of `parts` bands a block falls in, with band edges on road lines.
static func _band(block: int, blocks: int, parts: int) -> int:
	var band := 0
	for k in range(1, parts):
		if block >= _edge(k, blocks, parts):
			band = k
	return band


static func _edge(k: int, blocks: int, parts: int) -> int:
	return roundi(float(k * blocks) / parts)
