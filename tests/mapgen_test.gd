extends Node
## Headless check of the map generator: same seed, same map; every map valid.

const SETTINGS_PATH := "res://data/mapgen.tres"   # load() at run time: typed Archetype array
const SEEDS := 60

var _failed := 0


func _ready() -> void:
	var settings: MapGenSettings = load(SETTINGS_PATH)
	_check("settings load with 11 archetypes", settings.archetypes.size() == 11)
	var spec := MapSpec.new()
	spec.map_seed = 5
	var a := MapGenerator.generate(spec, settings)
	var b := MapGenerator.generate(spec, settings)
	_check("same seed, same streets", a.avenue_x == b.avenue_x and a.street_z == b.street_z)
	_check("same seed, same blocks", a.blocks == b.blocks and a.skyline == b.skyline)
	_check("same seed, same districts", _ids(a) == _ids(b))
	spec.map_seed = 6
	_check("another seed, another map", MapGenerator.generate(spec, settings).avenue_x != a.avenue_x)
	var ok := true
	var corner_ok := true
	var civic_ok := true
	var unique_ok := true
	var gaps_ok := true
	for s in SEEDS:
		spec.map_seed = s
		var layout := MapGenerator.generate(spec, settings)
		ok = ok and layout.blocks_x() == spec.avenues - 1 and layout.blocks_z() == spec.streets - 1
		ok = ok and layout.district_count() == 9
		corner_ok = corner_ok and layout.start_district in [0, 2, 6, 8]
		corner_ok = corner_ok and layout.district_archetype[layout.start_district].id == &"forgotten"
		var ids := _ids(layout)
		unique_ok = unique_ok and ids.size() == 9 and _distinct(ids)
		for n in layout.blocks.size():
			ok = ok and layout.block_district[n] >= 0 and layout.block_district[n] < 9
		for n in layout.avenue_x.size() - 1:
			var gap := layout.avenue_x[n + 1] - layout.avenue_x[n]
			gaps_ok = gaps_ok and gap >= spec.avenue_gaps.x - 0.01 and gap <= spec.avenue_gaps.y + 0.01
		civic_ok = civic_ok and layout.district_archetype[4].ring_weights.z > 0.0
	_check("%d seeds: sizes and districts valid" % SEEDS, ok)
	_check("start district is a forgotten corner", corner_ok)
	_check("no archetype repeats in a 3x3 map", unique_ok)
	_check("avenue gaps stay in range", gaps_ok)
	_check("centre district is a centre kind", civic_ok)
	spec.map_seed = 2
	spec.archetypes = PackedStringArray(["", "", "", "", "civic"])
	_check("a named archetype is kept", MapGenerator.generate(spec, settings).district_archetype[4].id == &"civic")
	spec.map_seed = 9
	var s1 := OrganicStreets.generate(spec)
	var s2 := OrganicStreets.generate(spec)
	_check("organic streets are made", s1.major.size() > 10 and s1.minor.size() > 30)
	_check("same seed, same organic streets", s1.major == s2.major and s1.minor == s2.minor)
	var inside := true
	for line in s1.major + s1.minor:
		for p in line:
			inside = inside and absf(p.x) <= spec.field_size.x / 2.0 + 0.01
			inside = inside and absf(p.y) <= spec.field_size.y / 2.0 + 0.01
	_check("organic streets stay on the map", inside)
	var parks := 0
	for k in a.blocks:
		parks += int(k == MapLayout.Block.PARK)
	_check("park blocks match the spec", parks == MapSpec.new().park_length)
	print("MAPGEN TEST: ", "PASS" if _failed == 0 else "%d FAILED" % _failed)
	get_tree().quit(_failed)


func _ids(layout: MapLayout) -> Array:
	return layout.district_archetype.map(func(x: Archetype) -> StringName: return x.id)


func _distinct(ids: Array) -> bool:
	var seen := {}
	for id in ids:
		seen[id] = true
	return seen.size() == ids.size()


func _check(label: String, passed: bool) -> void:
	print("  ", "ok  " if passed else "FAIL", "  ", label)
	if not passed:
		_failed += 1
