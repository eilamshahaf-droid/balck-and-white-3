class_name DistrictLayout
extends RefCounted
## Where things stand on a stage map, chosen from Districts' public answers: each
## district's core, the base, and the key buildings. Districts asks once at the start
## (and for a new core when one is demolished) and keeps the score itself.

const S: DistrictSettings = preload("res://data/districts.tres")

var districts: Districts
var plan: CityPlan


func _init(of: Districts, map: CityPlan) -> void:
	districts = of
	plan = map


## Each district's core: the largest building of the block the stage map marks as its
## core, or the building nearest its middle when the map marks none.
func cores(count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(count)
	out.fill(-1)
	for unit in plan.units:
		if unit.core and unit.district >= 0 and unit.district < count:
			out[unit.district] = largest(unit.buildings, unit.district)
	for d in count:
		if out[d] < 0:
			out[d] = pick_core(d)
	return out


## The standing building nearest the middle of district `d`, or -1.
func pick_core(d: int) -> int:
	var middle := districts.district_centre(d)
	var best := -1
	var best_gap := INF
	for i in districts.buildings.size():
		if districts.district_of(i) != d:
			continue
		var p := districts.buildings[i].global_position
		var gap := Vector2(p.x, p.z).distance_squared_to(middle)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## The base: the largest building of the block of district `d` farthest from its core,
## so the cult starts at the edge and works its way in to the heart.
func edge_building(d: int) -> int:
	var core := districts.core_of(d)
	var middle := districts.buildings[core].global_position
	var far := core
	var far_d := -1.0
	for i in districts.buildings.size():
		if districts.district_of(i) != d:
			continue
		var gap := districts.buildings[i].global_position.distance_squared_to(middle)
		if gap > far_d:
			far_d = gap
			far = i
	return largest(districts.block_members(districts.block_of(far)), d)


## District `d`'s key buildings, its core first: then the largest building of one block
## in every blocks_per_key, each time the block farthest from those chosen so far, so
## they spread over the district. Never in the base's block.
func keys(d: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var core := districts.core_of(d)
	if core < 0:
		return out
	var base_block := districts.block_of(districts.headquarters)
	var blocks: Array[int] = []
	var middles := {}
	for block in districts.block_count():
		var lead := largest(districts.block_members(block), d)
		if lead >= 0 and block != base_block and block != districts.block_of(core):
			blocks.append(block)
			middles[block] = districts.buildings[lead].global_position
	var chosen: Array[Vector3] = [districts.buildings[core].global_position]
	out.append(core)
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
		out.append(largest(districts.block_members(far), d))
	return out


## The roomiest of `members` standing in district `d`, or -1.
func largest(members: PackedInt32Array, d: int) -> int:
	var best := -1
	var best_volume := -1.0
	for i in members:
		var size := districts.sizes[i]
		var volume := size.x * size.y * size.z
		if districts.district_of(i) == d and volume > best_volume:
			best_volume = volume
			best = i
	return best
