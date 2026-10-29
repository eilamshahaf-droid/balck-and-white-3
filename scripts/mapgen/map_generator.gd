class_name MapGenerator
extends RefCounted
## Makes a MapLayout from a MapSpec. The same spec and seed always give the same
## map. Streets are a grid with uneven gaps; districts get archetypes by where
## they sit (poor and industrial at the corners, civic at the centre); blocks get
## a skyline from their district's archetype.

enum Ring { CORNER, SIDE, CENTRE }

var _spec: MapSpec
var _settings: MapGenSettings
var _rng := RandomNumberGenerator.new()


static func generate(spec: MapSpec, settings: MapGenSettings) -> MapLayout:
	var generator := MapGenerator.new()
	return generator._make(spec, settings)


func _make(spec: MapSpec, settings: MapGenSettings) -> MapLayout:
	_spec = spec
	_settings = settings
	_rng.seed = spec.map_seed
	var layout := MapLayout.new()
	layout.spec = spec
	layout.avenue_x = _road_lines(spec.avenues, spec.avenue_gaps)
	layout.street_z = _road_lines(spec.streets, spec.street_gaps)
	_place_districts(layout)
	_lay_blocks(layout)
	return layout


func _road_lines(count: int, gaps: Vector2) -> PackedFloat32Array:
	var lines := PackedFloat32Array([0.0])
	for n in count - 1:
		lines.append(lines[n] + _rng.randf_range(gaps.x, gaps.y))
	var mid := lines[count - 1] / 2.0
	for n in count:
		lines[n] -= mid
	return lines


func _place_districts(layout: MapLayout) -> void:
	var count := _spec.columns * _spec.rows
	var chosen: Array[Archetype] = []
	chosen.resize(count)
	var used := {}
	layout.start_district = _spec.start_district if _spec.start_district >= 0 else _pick_corner()
	for d in count:
		var named := _spec.archetypes[d] if d < _spec.archetypes.size() else ""
		if d == layout.start_district and named == "":
			named = String(_settings.start_archetype)
		if named != "":
			chosen[d] = _archetype(StringName(named))
			used[chosen[d].id] = true
	# Centre first, so the rarest kinds land where they belong, then sides, then corners.
	for ring in [Ring.CENTRE, Ring.SIDE, Ring.CORNER]:
		for d in count:
			if chosen[d] == null and _ring_of(d) == ring:
				chosen[d] = _draw(ring, used)
				used[chosen[d].id] = true
	layout.district_archetype = chosen


func _pick_corner() -> int:
	var corners: Array[int] = []
	for d in _spec.columns * _spec.rows:
		if _ring_of(d) == Ring.CORNER:
			corners.append(d)
	return corners[_rng.randi_range(0, corners.size() - 1)]


func _ring_of(d: int) -> int:
	var col := d % _spec.columns
	var row := floori(float(d) / _spec.columns)
	var edges := int(col == 0 or col == _spec.columns - 1) + int(row == 0 or row == _spec.rows - 1)
	return [Ring.CENTRE, Ring.SIDE, Ring.CORNER][edges]


## A weighted pick among the kinds not used yet (any kind once all are used).
func _draw(ring: int, used: Dictionary) -> Archetype:
	var pool: Array[Archetype] = []
	for a in _settings.archetypes:
		if not used.has(a.id):
			pool.append(a)
	if pool.is_empty():
		pool = _settings.archetypes
	var total := 0.0
	for a in pool:
		total += a.ring_weights[ring]
	if total <= 0.0:
		return pool[_rng.randi_range(0, pool.size() - 1)]
	var roll := _rng.randf() * total
	for a in pool:
		roll -= a.ring_weights[ring]
		if roll <= 0.0:
			return a
	return pool[pool.size() - 1]


func _archetype(id: StringName) -> Archetype:
	for a in _settings.archetypes:
		if a.id == id:
			return a
	push_error("Unknown archetype '%s'" % id)
	return _settings.archetypes[0]


func _lay_blocks(layout: MapLayout) -> void:
	var nx := layout.blocks_x()
	var nz := layout.blocks_z()
	layout.blocks.resize(nx * nz)
	layout.skyline.resize(nx * nz)
	layout.block_district.resize(nx * nz)
	var park_column := floori(nx / 2.0)
	var plazas := {}
	while plazas.size() < mini(_spec.plazas, nx * nz):
		var at := Vector2i(_rng.randi_range(0, nx - 1), _rng.randi_range(0, nz - 1))
		if not _is_park(at.x, at.y, park_column, nz):
			plazas[at] = true
	for j in nz:
		for i in nx:
			var n := j * nx + i
			var d := _band(j, nz, _spec.rows) * _spec.columns + _band(i, nx, _spec.columns)
			layout.block_district[n] = d
			layout.blocks[n] = (MapLayout.Block.PARK if _is_park(i, j, park_column, nz)
					else MapLayout.Block.PLAZA if plazas.has(Vector2i(i, j))
					else MapLayout.Block.BUILT)
			var tall := layout.district_archetype[d].skyline
			layout.skyline[n] = clampf(_rng.randf_range(tall.x, tall.y), 0.0, 1.0)


func _is_park(i: int, j: int, park_column: int, nz: int) -> bool:
	return i == park_column and j >= nz - _spec.park_length


## Which of `parts` bands a block falls in, with band edges on road lines
## (the same split Districts uses).
static func _band(block: int, blocks: int, parts: int) -> int:
	var band := 0
	for k in range(1, parts):
		if block >= roundi(float(k * blocks) / parts):
			band = k
	return band
