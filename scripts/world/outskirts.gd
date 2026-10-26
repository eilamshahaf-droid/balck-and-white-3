extends RefCounted
## The outer neighbourhoods around the city (scenery for surroundings.gd).
## Houses and blocks line the roads that leave the grid and turn with them, so
## towns grow along the roads like real ones. They are taller near the city
## and thin out into houses with pitched roofs, fields and wooded hills, with a
## second cluster of towers across the river. Woods fill the hills.

const S: SurroundingsSettings = preload("res://data/surroundings.tres")
const RASTER := 6.0             # metres per cell of the "something stands here" grid
const BUCKET := 40.0            # metres per bucket of road points, for nearest-road lookups
const KEEP_OFF_CITY := 10.0     # metres of open ground between the grid and the first lots
const MAX_SLOPE := 4.0          # metres of drop across a lot before nobody builds there

var _land: Surroundings
var _rng := RandomNumberGenerator.new()
var _side := 0
var _taken := PackedByteArray()
var _buckets := {}              # Vector2i -> PackedVector2Array of (point, direction) pairs
var _box := SharedMeshes.box(Vector3.ONE)
var _roof := PrismMesh.new()


func _init(land: Surroundings) -> void:
	_land = land
	_rng.seed = 13


func build() -> void:
	_side = ceili(S.reach * 2.0 / RASTER)
	_taken.resize(_side * _side)
	for i in _land.roads.size():
		_claim_road(_land.roads[i], _land.road_widths[i])
	var x := -S.reach
	while x < S.reach:
		var z := -S.reach
		while z < S.reach:
			var jitter := Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3)) * S.lot_spacing
			_try_lot(Vector2(x, z) + jitter)
			z += S.lot_spacing
		x += S.lot_spacing
	_plant_trees()


func _claim_road(points: PackedVector2Array, width: float) -> void:
	var r := width / 2.0 + 3.0  # the road and its sidewalks
	for p in Surroundings.resample(points, RASTER * 0.75):
		_mark_disc(p, r)
	var pts := Surroundings.resample(points, 10.0)
	for n in pts.size():
		var dir := (pts[mini(n + 1, pts.size() - 1)] - pts[maxi(n - 1, 0)]).normalized()
		var key := Vector2i(floori(pts[n].x / BUCKET), floori(pts[n].y / BUCKET))
		if not _buckets.has(key):
			_buckets[key] = PackedVector2Array()
		_buckets[key].append(pts[n])
		_buckets[key].append(dir)


## Distance to the nearest road and its direction there, as (distance, dir.x, dir.y).
func _nearest_road(p: Vector2) -> Vector3:
	var best := Vector3(INF, 1.0, 0.0)
	var key := Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var list: PackedVector2Array = _buckets.get(key + Vector2i(dx, dz), PackedVector2Array())
			for n in range(0, list.size(), 2):
				var d := p.distance_to(list[n])
				if d < best.x:
					best = Vector3(d, list[n + 1].x, list[n + 1].y)
	return best


func _try_lot(p: Vector2) -> void:
	var out := _land.outside_city(p.x, p.y)
	if out < KEEP_OFF_CITY or out > S.building_reach:
		return
	if _land.river_distance(p.x, p.y) < S.promenade_width + 8.0:
		return
	var road := _nearest_road(p)
	var far := smoothstep(0.0, S.building_reach, out)
	var near_road := 1.0 - smoothstep(0.0, S.road_pull, road.x)
	if _rng.randf() > lerpf(S.near_density, S.far_density, far) * (0.15 + 0.85 * near_road):
		return

	# Face the road; lots far from any road keep roughly to the compass.
	var angle := atan2(-road.z, road.y) if road.x < S.road_pull * 2.0 else _rng.randf_range(-0.4, 0.4)
	var size := Vector2(_rng.randf_range(9.0, 17.0), _rng.randf_range(8.0, 14.0)) * lerpf(1.25, 0.8, far)
	if not _footprint(p, size, angle, false):
		return
	var low := INF
	var high := -INF
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var c := p + (corner * size / 2.0).rotated(-angle)
		var y := _land.surface_y(c.x, c.y)
		low = minf(low, y)
		high = maxf(high, y)
	if high - low > MAX_SLOPE:
		return
	_footprint(p, size, angle, true)

	var rise := smoothstep(0.0, S.building_reach * 0.55, out)
	var height := lerpf(_rng.randf_range(S.near_height.x, S.near_height.y), _rng.randf_range(S.far_height.x, S.far_height.y), rise)
	var across := Vector2(_land.river_x(0.0) + S.river_width / 2.0 + S.skyline_radius * 0.7, 0.0)
	height += S.skyline_across * exp(-p.distance_squared_to(across) / (S.skyline_radius * S.skyline_radius)) * _rng.randf_range(0.3, 1.0)
	_add_building(Vector3(p.x, low - 1.0, p.y), Vector3(size.x, height + 1.0, size.y), angle)


func _add_building(base: Vector3, size: Vector3, angle: float) -> void:
	var turn := Basis(Vector3.UP, angle)
	var color := S.building_colors[_rng.randi() % S.building_colors.size()]
	var st := _land.mesh_tool(color)
	st.append_from(_box, 0, Transform3D(turn * Basis.from_scale(size), base + Vector3.UP * size.y / 2.0))
	var top := base + Vector3.UP * size.y
	if size.y < S.pitched_below + 1.0:
		var ridge := minf(size.x, size.z) * 0.45
		_land.mesh_tool(S.roof_color).append_from(_roof, 0, Transform3D(turn * Basis.from_scale(Vector3(size.x, ridge, size.z)), top + Vector3.UP * ridge / 2.0))
	elif size.y > 25.0 and _rng.randf() < 0.5:
		# A narrower tier on top, like a setback tower.
		var tier := Vector3(size.x * 0.65, size.y * _rng.randf_range(0.2, 0.4), size.z * 0.65)
		st.append_from(_box, 0, Transform3D(turn * Basis.from_scale(tier), top + Vector3.UP * tier.y / 2.0))
	elif _rng.randf() < 0.4:
		# Something on the roof: a water tank, a lift room.
		var bit := Vector3.ONE * _rng.randf_range(2.0, 3.5)
		var at := Vector3(_rng.randf_range(-0.25, 0.25) * size.x, 0.0, _rng.randf_range(-0.25, 0.25) * size.z)
		_land.mesh_tool(S.rooftop_color).append_from(_box, 0, Transform3D(turn * Basis.from_scale(bit), top + turn * at + Vector3.UP * bit.y / 2.0))


func _plant_trees() -> void:
	var trunk := SharedMeshes.cylinder(0.25, 0.35, 1.0)
	var crown := SharedMeshes.unit_sphere(6, 3)
	var placed := 0
	var tries := 0
	while placed < S.tree_count and tries < S.tree_count * 8:
		tries += 1
		var p := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * S.reach * 0.8
		if _land.outside_city(p.x, p.y) < KEEP_OFF_CITY or _land.river_distance(p.x, p.y) < S.promenade_width + 4.0:
			continue
		var cell := _cell(p)
		if cell < 0 or _taken[cell] == 1:
			continue
		var y := _land.surface_y(p.x, p.y)
		# Woods on the hills, a tree here and there in the flats.
		if _rng.randf() > 0.2 + clampf(y / 25.0, 0.0, 0.8):
			continue
		var s := _rng.randf_range(0.9, 1.7)
		_land.mesh_tool(S.trunk_color).append_from(trunk, 0, Transform3D(Basis.from_scale(Vector3(s, 2.5 * s, s)), Vector3(p.x, y + 1.25 * s, p.y)))
		var green := S.crown_colors[_rng.randi() % S.crown_colors.size()]
		_land.mesh_tool(green).append_from(crown, 0, Transform3D(Basis.from_scale(Vector3.ONE * 2.4 * s), Vector3(p.x, y + 4.0 * s, p.y)))
		_taken[cell] = 1
		placed += 1


## Checks (or, with `claim`, takes) every cell under a turned rectangle.
func _footprint(p: Vector2, size: Vector2, angle: float, claim: bool) -> bool:
	var r := size.length() / 2.0 + RASTER
	var half := size / 2.0 + Vector2.ONE * 1.5
	var y := p.y - r
	while y <= p.y + r:
		var x := p.x - r
		while x <= p.x + r:
			var local := (Vector2(x, y) - p).rotated(angle)
			if absf(local.x) <= half.x and absf(local.y) <= half.y:
				var cell := _cell(Vector2(x, y))
				if cell < 0:
					return false
				if claim:
					_taken[cell] = 1
				elif _taken[cell] == 1:
					return false
			x += RASTER
		y += RASTER
	return true


func _mark_disc(p: Vector2, r: float) -> void:
	var y := p.y - r
	while y <= p.y + r:
		var x := p.x - r
		while x <= p.x + r:
			var cell := _cell(Vector2(x, y))
			if cell >= 0 and Vector2(x, y).distance_squared_to(p) <= r * r:
				_taken[cell] = 1
			x += RASTER
		y += RASTER


func _cell(p: Vector2) -> int:
	var i := floori((p.x + S.reach) / RASTER)
	var j := floori((p.y + S.reach) / RASTER)
	if i < 0 or j < 0 or i >= _side or j >= _side:
		return -1
	return j * _side + i
