class_name Districts
extends Node
## Knows the stage map's districts (CityPlan) and keeps who holds every building. Eilam's
## rule (2026-11-13): every building has a takeover meter; a rep at its door fills it
## (Campaigns), your buildings next to it in its own block pull it up slowly (Preaching),
## and when it is full a rep takes the building over and stays as its manager: it is
## yours while it is managed. The game starts from the base (`headquarters`, the main
## Office, always yours) at the edge of the start district and works in toward the core
## in the middle. A district is yours once its bar is full
## (DistrictProgress: a wide following, key places, or both). Decrees ask owns(), so there
## is one answer.
## Buildings change hands one at a time (index = CityPlan building index). Each stands
## in a block (a map unit: a block or a run of one); a block whose standing buildings
## are all yours is complete, which pays a bonus (block_bonus, in_complete_block).
## A building can only become yours if it borders one you already hold (can_claim),
## so the city is taken outwards from the headquarters. A core
## also needs most of the buildings around it first.

signal layout_ready
signal building_changed(index: int, yours: bool)
signal district_controlled(district: int)
## Block `block` became complete (all its standing buildings are yours), or stopped being.
signal block_changed(block: int, complete: bool)
## Building `index`'s takeover meter moved (0 = nothing, 1 = it wants you).
signal meter_changed(index: int, value: float)
## Every building was counted again (a few times a second).
signal counted
## District `district` has a different core building now (the old one was demolished).
signal core_changed(district: int)

const S: DistrictSettings = preload("res://data/districts.tres")

## Every building, by index. A demolished one stays in the list as null.
var buildings: Array[Node3D] = []
## Each building's box (width, height, depth).
var sizes := PackedVector3Array()
## The cult's first building: the start district's core.
var headquarters := -1
## The key buildings (about one per few blocks): inspectors come out of them. They can't
## be taken yet (round C).
var keys := PackedInt32Array()
## How free each district is (0..1); see DistrictSettings.independence.
var independence := PackedFloat32Array()

var _district_of := PackedInt32Array()   # -1 once demolished
var _yours := PackedByteArray()
var _totals := PackedInt32Array()        # standing buildings per district
var _owned := PackedInt32Array()         # buildings of yours per district
var _controlled := PackedByteArray()
var _unlocked := PackedByteArray()
var _core := PackedInt32Array()          # per district: index of its core building, -1 if none
var _index := {}                         # building -> index
var _graph := BuildingGraph.new()
var _meter := PackedFloat32Array()        # per building: the takeover meter, 0..1
var _managed := PackedByteArray()        # per building: a rep manages it, so it is yours
var _block_of := PackedInt32Array()
var _block_members: Array[PackedInt32Array] = []
var _block_standing := PackedInt32Array()   # per block: buildings not demolished
var _block_held := PackedInt32Array()       # of them, yours
var _block_complete := PackedByteArray()
var _key := PackedByteArray()            # per building: 1 for a key building
var _timer := 0.0

@onready var city: City = get_parent()


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
	for i in buildings.size():
		if _district_of[i] < 0:
			continue
		var mine := _holds(i)
		if mine != (_yours[i] == 1):
			_set_side(i, mine)
	counted.emit()


func district_count() -> int:
	return city.plan.districts.size()


## The district at `p`; off the map, the start district (the outskirts are its edge).
func district_at(p: Vector3) -> int:
	var d := city.plan.district_at(Vector2(p.x, p.z))
	return d if d >= 0 else city.plan.start_district


## The kind of district (DistrictSettings.kinds) at `p`: who lives there.
func kind_at(p: Vector3) -> String:
	return city.plan.districts[district_at(p)].kind


## The cult's first building, or null.
func start_building() -> Node3D:
	return buildings[headquarters] if headquarters >= 0 else null


## The district the cult starts in (the Slums).
func start_district() -> int:
	return city.plan.start_district


## `building` is the cult's base (where the high priest starts and agents train).
func is_base(building: Node3D) -> bool:
	return headquarters >= 0 and buildings[headquarters] == building


## Can the player work in district `d` yet? Only the start district for now:
## the stages after it are not built.
func is_unlocked(d: int) -> bool:
	return d >= 0 and d < _unlocked.size() and _unlocked[d] == 1


## Is the place where `building` stands open to the player?
func is_open(building: Node3D) -> bool:
	return is_unlocked(district_at(building.global_position))


func district_name(d: int) -> String:
	return city.plan.districts[d].name


## The middle of the district on the ground (x, z).
func district_centre(d: int) -> Vector2:
	return city.plan.districts[d].centre


## Share of the district's standing buildings that are yours, 0..1.
func share(d: int) -> float:
	return float(_owned[d]) / maxi(_totals[d], 1)


func is_controlled(d: int) -> bool:
	return _controlled[d] == 1


## The district's hard central building, as an index (-1 when it has none).
func core_of(d: int) -> int:
	return _core[d]


## District `d` is won (DistrictProgress says its bar is full).
func win(d: int) -> void:
	if _controlled[d] == 0:
		_controlled[d] = 1
		district_controlled.emit(d)


func is_yours(index: int) -> bool:
	return _yours[index] == 1


## How far building `index` is toward wanting you, 0..1.
func meter_of(index: int) -> float:
	return _meter[index]


## Move building `index`'s takeover meter by `amount` (a rep at the door, the pull of
## your buildings next to it, or time wearing it down).
func add_meter(index: int, amount: float) -> void:
	if _yours[index] == 1 or _district_of[index] < 0 or _key[index] == 1:
		return
	var now := clampf(_meter[index] + amount, 0.0, 1.0)
	# Compared exactly: "about equal" would leave a meter a hair under full for ever.
	if now != _meter[index]:
		_meter[index] = now
		meter_changed.emit(index, now)


## Building `index` is not yours but wants you: it only needs a rep to manage it.
func wants_you(index: int) -> bool:
	return _yours[index] == 0 and _meter[index] >= 1.0


## A rep takes building `index` over and manages it: it is yours from now on. False
## when it can't be claimed yet (can_claim).
func take(index: int) -> bool:
	if _yours[index] == 1 or not can_claim(index):
		return false
	_managed[index] = 1
	_meter[index] = 1.0
	_set_side(index, true)
	return true


func block_count() -> int:
	return _block_members.size()


## The block building `index` stands in.
func block_of(index: int) -> int:
	return _block_of[index]


## The buildings of `block`, demolished ones included.
func block_members(block: int) -> PackedInt32Array:
	return _block_members[block]


## How many of `block`'s standing buildings are yours.
func block_held(block: int) -> int:
	return _block_held[block]


func block_size(block: int) -> int:
	return _block_standing[block]


func is_block_complete(block: int) -> bool:
	return _block_complete[block] == 1


## Building `index` stands in a block that is all yours.
func in_complete_block(index: int) -> bool:
	return _block_complete[_block_of[index]] == 1


## Building `index` could become yours: its district is open, it borders a building you
## hold, and, for a core, enough of the buildings around it are yours (core_base).
func can_claim(index: int) -> bool:
	var d := _district_of[index]
	if index == headquarters:
		return true
	if d < 0 or _unlocked[d] == 0 or _key[index] == 1 or not borders_yours(index):
		return false
	return _core[d] != index or core_base(index) >= S.core_base_share


func is_key(index: int) -> bool:
	return _key[index] == 1


## The name on key building `index`'s sign.
func key_name(index: int) -> String:
	return S.key_name(keys.find(index))


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
		_managed[index] = 0
		_meter[index] = S.lost_meter
		_set_side(index, false)
		meter_changed.emit(index, _meter[index])


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
	return S.wealth_of_kind(city.plan.districts[d].kind)


func wealth_at(index: int) -> float:
	return wealth_of(_district_of[index]) if _district_of[index] >= 0 else 1.0


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
	_block_standing[_block_of[i]] -= 1
	_check_block(_block_of[i])
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
	for i in order.slice(0, count):
		_managed[i] = 1
		_meter[i] = 1.0
		_set_side(i, true)


## A building is yours while a rep manages it (the base always is).
func _holds(i: int) -> bool:
	return i == headquarters or _managed[i] == 1


## The base, always yours, is where the game starts; only its district is open.
func _found_headquarters() -> void:
	var start := start_district()
	headquarters = _edge_building(start)
	_unlocked[start] = 1



## The base: the largest building of the block of district `d` farthest from its core,
## so the cult starts at the edge and works its way in to the heart.
func _edge_building(d: int) -> int:
	var middle := buildings[_core[d]].global_position
	var far := _core[d]
	var far_d := -1.0
	for i in buildings.size():
		if _district_of[i] != d:
			continue
		var gap := buildings[i].global_position.distance_squared_to(middle)
		if gap > far_d:
			far_d = gap
			far = i
	return _largest(_block_members[_block_of[far]], d)


## The roomiest of `members` standing in district `d`.
func _largest(members: PackedInt32Array, d: int) -> int:
	var best := -1
	var best_volume := -1.0
	for i in members:
		var volume := sizes[i].x * sizes[i].y * sizes[i].z
		if _district_of[i] == d and volume > best_volume:
			best_volume = volume
			best = i
	return best


func _set_side(i: int, mine: bool) -> void:
	_yours[i] = 1 if mine else 0
	var d := _district_of[i]
	_owned[d] += 1 if mine else -1
	_block_held[_block_of[i]] += 1 if mine else -1
	building_changed.emit(i, mine)
	_check_block(_block_of[i])


func _check_block(block: int) -> void:
	var complete := _block_standing[block] > 0 and _block_held[block] == _block_standing[block]
	if complete != (_block_complete[block] == 1):
		_block_complete[block] = 1 if complete else 0
		block_changed.emit(block, complete)


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
	var blocks := city.plan.units.size()
	_block_standing.resize(blocks)
	_block_held.resize(blocks)
	_block_complete.resize(blocks)
	for unit in city.plan.units:
		_block_members.append(unit.buildings)
	for i in city.building_nodes.size():
		var b: Node3D = city.building_nodes[i]
		var p := city.plan.buildings[i]
		var d := p.district if p.district >= 0 else district_at(b.global_position)
		_index[b] = i
		buildings.append(b)
		sizes.append(BuildingBox.size_of(b))
		_district_of.append(d)
		_block_of.append(p.unit)
		_block_standing[p.unit] += 1
		_totals[d] += 1
	_find_cores(count)
	var n := buildings.size()
	_yours.resize(n)
	_yours.fill(0)
	_meter.resize(n)
	_managed.resize(n)
	_key.resize(n)
	_find_borders()
	_found_headquarters()
	for d in count:
		_find_keys(d)


## Which buildings border each other (next door or across a street, and across district
## lines, so a new district is entered from the edge of one you hold).
func _find_borders() -> void:
	_graph.set_from_plan(city.plan, S.border_gap)


func _demolished() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(buildings.size())
	for i in buildings.size():
		out[i] = 1 if _district_of[i] < 0 else 0
	return out


## District `d`'s key buildings: its core, and the largest building of one block in every
## blocks_per_key, each time the block farthest from those chosen so far, so they spread
## over the district. Never in the base's block.
func _find_keys(d: int) -> void:
	if _core[d] < 0:
		return
	var blocks: Array[int] = []
	var middles := {}
	for block in _block_members.size():
		var lead := _largest(_block_members[block], d)
		if lead >= 0 and block != _block_of[headquarters] and block != _block_of[_core[d]]:
			blocks.append(block)
			middles[block] = buildings[lead].global_position
	var chosen: Array[Vector3] = [buildings[_core[d]].global_position]
	_key[_core[d]] = 1
	keys.append(_core[d])
	var wanted := roundi((blocks.size() + 2) / S.blocks_per_key)
	while chosen.size() < wanted and not blocks.is_empty():
		var far := -1
		var far_d := -1.0
		for block in blocks:
			var nearest := INF
			for p in chosen:
				nearest = minf(nearest, p.distance_squared_to(middles[block]))
			if nearest > far_d:
				far_d = nearest
				far = block
		blocks.erase(far)
		chosen.append(middles[far])
		var index := _largest(_block_members[far], d)
		_key[index] = 1
		keys.append(index)


## Each district's core is the largest building of the block the stage map marks as
## its core.
func _find_cores(count: int) -> void:
	_core.resize(count)
	_core.fill(-1)
	for unit in city.plan.units:
		if unit.core and unit.district >= 0 and unit.district < count:
			_core[unit.district] = _largest(unit.buildings, unit.district)
	for d in count:
		if _core[d] < 0:
			_core[d] = _pick_core(d)


## The standing building nearest the middle of district `d`, or -1.
func _pick_core(d: int) -> int:
	var middle := district_centre(d)
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
