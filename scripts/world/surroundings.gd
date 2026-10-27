class_name Surroundings
extends Node3D
## What lies past the playable grid, so the city never just stops in a void:
## rolling land that rises into hills, a river along the east side with a
## promenade and bridges, the grid's roads carrying on and wandering off into
## outer neighbourhoods (outskirts.gd), clouds, and a haze that melts the far
## land into the sky. None of it is played on; it is all scenery, built once
## into a handful of merged meshes.

const S: SurroundingsSettings = preload("res://data/surroundings.tres")
const OutskirtsScript := preload("res://scripts/world/outskirts.gd")
const LAYER_WORLD := 1
const ROAD_STEP := 12.0         # metres between points while a road wanders
const RIBBON_STEP := 8.0        # metres between cross-sections of a drawn road
const ROAD_LIFT := 0.12         # above the ground, so the road wins the depth test
const BANK_SLOPE := 25.0        # metres from the water's edge to the river bed

## Roads outside the grid, as ground-plane polylines (x, z), and their widths.
var roads: Array[PackedVector2Array] = []
var road_widths := PackedFloat32Array()
## The city's ground: road centre lines plus the asphalt margin (half extents).
var city_edge := Vector2.ZERO

var _noise := FastNoiseLite.new()
var _heights := PackedFloat32Array()    # terrain vertex heights, row by row (z), then x
var _side := 0                          # terrain vertices per side
var _bridges: Array[Vector3] = []       # x from, x to, z
var _clouds := Node3D.new()
var _tools := {}                        # Color -> SurfaceTool: one merged mesh per colour

@onready var city: Node3D = get_parent()


func _ready() -> void:
	set_process(false)
	await city.ready  # the city lays out its grid in its own _ready, after ours
	city_edge = city.half_size + city.GROUND_MARGIN
	_noise.seed = 7
	_noise.frequency = S.hill_frequency
	_noise.fractal_octaves = 3
	_set_haze(city.env)
	# Scenery nobody sees on the first frame: one step per frame, so the game starts sooner.
	_build_land()
	await get_tree().process_frame
	_build_water()
	_lay_roads()
	for i in roads.size():
		_ribbon(roads[i], road_widths[i], ROAD_LIFT, S.road_color)
	_build_bridges()
	await get_tree().process_frame
	await OutskirtsScript.new(self).build()
	_build_clouds()
	_flush()
	set_process(true)


func _process(delta: float) -> void:
	_clouds.rotation.y += deg_to_rad(S.cloud_turn_speed) * delta


## Ground height under (x, z), exactly on the drawn terrain.
func surface_y(x: float, z: float) -> float:
	var g := (Vector2(x, z) + Vector2.ONE * S.reach) / S.cell
	var i := clampi(floori(g.x), 0, _side - 2)
	var j := clampi(floori(g.y), 0, _side - 2)
	var fx := clampf(g.x - i, 0.0, 1.0)
	var fz := clampf(g.y - j, 0.0, 1.0)
	var h00 := _heights[j * _side + i]
	var h10 := _heights[j * _side + i + 1]
	var h01 := _heights[(j + 1) * _side + i]
	var h11 := _heights[(j + 1) * _side + i + 1]
	# Same split as the mesh: each cell is two triangles along its 00-11 diagonal.
	if fx >= fz:
		return h00 + fx * (h10 - h00) + fz * (h11 - h10)
	return h00 + fz * (h01 - h00) + fx * (h11 - h01)


## Metres from the river's nearest bank; negative over the water.
func river_distance(x: float, z: float) -> float:
	return absf(x - river_x(z)) - S.river_width / 2.0


func river_x(z: float) -> float:
	var middle := city_edge.x + S.river_offset + S.river_wiggle * 2.0 + S.river_width / 2.0
	return middle - S.river_wiggle * cos(z * TAU / S.river_wavelength)


## Metres from the city's ground; 0 inside it.
func outside_city(x: float, z: float) -> float:
	return Vector2(maxf(absf(x) - city_edge.x, 0.0), maxf(absf(z) - city_edge.y, 0.0)).length()


# --- Land ---

func _height(x: float, z: float) -> float:
	var out := outside_city(x, z)
	if out <= 0.0:
		return -0.3  # under the city's asphalt
	var river := river_distance(x, z)
	if river < 0.0:
		return lerpf(0.0, S.water_level - S.river_depth, smoothstep(0.0, BANK_SLOPE, -river))
	var hills := smoothstep(S.flat_margin, S.flat_margin + S.hill_rise, out) * smoothstep(20.0, 450.0, river)
	return hills * S.hill_height * clampf(_noise.get_noise_2d(x, z) + 0.55, 0.0, 1.4)


func _build_land() -> void:
	_side = roundi(S.reach * 2.0 / S.cell) + 1
	_heights.resize(_side * _side)
	for j in _side:
		for i in _side:
			_heights[j * _side + i] = _height(i * S.cell - S.reach, j * S.cell - S.reach)
	var st := mesh_tool(S.grass_color)
	for j in _side - 1:
		for i in _side - 1:
			var v00 := _vertex(i, j)
			var v10 := _vertex(i + 1, j)
			var v01 := _vertex(i, j + 1)
			var v11 := _vertex(i + 1, j + 1)
			_up_tri(st, v00, v10, v11)
			_up_tri(st, v00, v11, v01)

	# The same heights as a collision floor, so whatever the hand throws out of town lands.
	var shape := HeightMapShape3D.new()
	shape.map_width = _side
	shape.map_depth = _side
	var data := _heights.duplicate()
	for n in data.size():
		data[n] /= S.cell  # the shape is scaled by the cell size below
	shape.map_data = data
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.set_meta("surface", &"grass")
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3.ONE * S.cell
	body.add_child(col)
	add_child(body)


func _vertex(i: int, j: int) -> Vector3:
	return Vector3(i * S.cell - S.reach, _heights[j * _side + i], j * S.cell - S.reach)


func _build_water() -> void:
	var water := PackedVector2Array()
	var z := -S.reach
	while z <= S.reach:
		water.append(Vector2(river_x(z), z))
		z += RIBBON_STEP * 4.0
	_ribbon(water, S.river_width + 6.0, 0.0, S.water_color, S.water_level)
	for side: float in [-1.0, 1.0]:
		var walk := PackedVector2Array()
		for p in water:
			walk.append(p + Vector2(side * (S.river_width / 2.0 + S.promenade_width / 2.0 + 2.0), 0.0))
		_ribbon(walk, S.promenade_width, ROAD_LIFT * 0.5, S.promenade_color)


# --- Roads ---

func _lay_roads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var last_avenue: int = city.AVENUES - 1
	var last_street: int = city.STREETS - 1
	# The avenues carry on north and south and fan out.
	for i in city.AVENUES:
		var x: float = city.intersection(Vector2i(i, 0)).x
		var fan: float = x / city.half_size.x
		_add_road(_wander(Vector2(x, -city.half_size.y), Vector2.UP, S.avenue_reach, fan, i), S.road_width)
		_add_road(_wander(Vector2(x, city.half_size.y), Vector2.DOWN, S.avenue_reach, -fan, i + 50), S.road_width)
	# Side streets run west a little way into the neighbourhoods.
	for j in city.STREETS:
		var z: float = city.intersection(Vector2i(0, j)).z
		var reach := rng.randf_range(S.street_reach.x, S.street_reach.y)
		_add_road(_wander(Vector2(-city.half_size.x, z), Vector2.LEFT, reach, -z / city.half_size.y, j + 100), S.road_width * 0.75)
	# A few cross the river on bridges, then wander off on the far bank.
	for k in S.bridges:
		var j := roundi(float(k + 1) * last_street / (S.bridges + 1))
		var start: Vector3 = city.intersection(Vector2i(last_avenue, j))
		var far_bank := river_x(start.z) + S.river_width / 2.0 + S.promenade_width + 10.0
		var path := PackedVector2Array([Vector2(start.x, start.z), Vector2(far_bank, start.z)])
		path.append_array(_wander(Vector2(far_bank, start.z), Vector2.RIGHT, S.avenue_reach, 0.0, k + 200).slice(1))
		_add_road(path, S.road_width)
		_bridges.append(Vector3(river_x(start.z) - S.river_width / 2.0 - 6.0, far_bank - S.promenade_width, start.z))
	var rings: PackedFloat32Array = S.ring_offsets
	for r in rings:
		_lay_ring(r)


## A road that leaves the grid straight, then bends and fans out the further it goes.
func _wander(start: Vector2, dir: Vector2, length: float, fan: float, seed_value: int) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var p := start
	var travelled := 0.0
	while travelled < length:
		var settle := smoothstep(30.0, 200.0, travelled)
		var turn := fan * S.spread * settle + _noise.get_noise_2d(seed_value * 131.0, travelled) * S.bend * settle
		p += dir.rotated(turn) * ROAD_STEP
		travelled += ROAD_STEP
		if river_distance(p.x, p.y) < S.promenade_width + 4.0 or absf(p.x) > S.reach or absf(p.y) > S.reach:
			break
		points.append(p)
	return points


## A loose ring around the city, broken wherever it would cross the river.
func _lay_ring(offset: float) -> void:
	var piece := PackedVector2Array()
	var a := city_edge + Vector2.ONE * offset
	var steps := 160
	for n in steps + 1:
		var t := TAU * n / steps
		var c := cos(t)
		var s := sin(t)
		var p := Vector2(a.x * signf(c) * sqrt(absf(c)), a.y * signf(s) * sqrt(absf(s)))
		p *= 1.0 + _noise.get_noise_2d(offset, n * 9.0) * 0.25
		if river_distance(p.x, p.y) < S.promenade_width + 4.0:
			_add_road(piece, S.road_width * 0.85)
			piece = PackedVector2Array()
		else:
			piece.append(p)
	_add_road(piece, S.road_width * 0.85)


func _add_road(points: PackedVector2Array, width: float) -> void:
	if points.size() >= 2:
		roads.append(points)
		road_widths.append(width)


func _build_bridges() -> void:
	var st := mesh_tool(S.bridge_color)
	var deck := SharedMeshes.box(Vector3.ONE)
	for b in _bridges:
		var length := b.y - b.x
		var mid := Vector3((b.x + b.y) / 2.0, 0.0, b.z)
		st.append_from(deck, 0, Transform3D(Basis.from_scale(Vector3(length, 1.0, S.road_width + 2.0)), mid - Vector3(0, 0.45, 0)))
		for f: float in [0.28, 0.72]:
			for side: float in [-1.0, 1.0]:
				var foot := Vector3(lerpf(b.x, b.y, f), 0.0, b.z + side * (S.road_width / 2.0 + 0.8))
				st.append_from(deck, 0, Transform3D(Basis.from_scale(Vector3(1.6, 30.0, 1.6)), foot + Vector3(0, 13.0, 0)))
				st.append_from(deck, 0, Transform3D(Basis.from_scale(Vector3(1.6, 8.0, 1.6)), foot + Vector3(0, S.water_level - 2.0, 0)))


# --- Sky ---

## Depth haze in the colour of the horizon: the far land fades into the sky.
func _set_haze(env: Environment) -> void:
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = S.fog_begin
	env.fog_depth_end = S.fog_end
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0


func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var puff := SharedMeshes.unit_sphere(8, 4)
	var mat := _material(S.cloud_color)
	for n in S.cloud_count:
		var st := SurfaceTool.new()
		for k in rng.randi_range(4, 7):
			var r := rng.randf_range(14.0, 26.0)
			var at := Vector3(rng.randf_range(-35.0, 35.0), rng.randf_range(-4.0, 6.0), rng.randf_range(-15.0, 15.0))
			st.append_from(puff, 0, Transform3D(Basis.from_scale(Vector3(r, r * 0.6, r)), at))
		var cloud := MeshInstance3D.new()
		cloud.mesh = st.commit()
		cloud.material_override = mat
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(city_edge.length() + 200.0, S.reach * 0.7)
		cloud.position = Vector3(cos(angle) * radius, rng.randf_range(S.cloud_height.x, S.cloud_height.y), sin(angle) * radius)
		cloud.rotation.y = rng.randf() * TAU
		_clouds.add_child(cloud)
	add_child(_clouds)


# --- Mesh building (shared with outskirts.gd) ---

func mesh_tool(color: Color) -> SurfaceTool:
	if not _tools.has(color):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[color] = st
	return _tools[color]


## A flat band along `points`, draped on the ground (or at `flat_y` if given).
func _ribbon(points: PackedVector2Array, width: float, lift: float, color: Color, flat_y := NAN) -> void:
	var st := mesh_tool(color)
	var pts := resample(points, RIBBON_STEP)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for n in pts.size():
		var ahead := pts[mini(n + 1, pts.size() - 1)] - pts[maxi(n - 1, 0)]
		var across := ahead.normalized().orthogonal() * width / 2.0
		var l := _on_ground(pts[n] + across, lift, flat_y)
		var r := _on_ground(pts[n] - across, lift, flat_y)
		if n > 0:
			_up_tri(st, prev_l, prev_r, r)
			_up_tri(st, prev_l, r, l)
		prev_l = l
		prev_r = r


func _on_ground(p: Vector2, lift: float, flat_y: float) -> Vector3:
	var y := flat_y if not is_nan(flat_y) else maxf(surface_y(p.x, p.y), 0.0)
	return Vector3(p.x, y + lift, p.y)


## One triangle facing up. Godot draws clockwise faces, seen from the front.
func _up_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.y > 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	st.set_normal(-n.normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Every colour's merged mesh becomes one node, styled like the rest of the city.
func _flush() -> void:
	for color: Color in _tools:
		var node := MeshInstance3D.new()
		node.mesh = _tools[color].commit()
		node.material_override = _material(color)
		add_child(node)
	_tools.clear()


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


static func resample(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	var carry := 0.0
	for n in range(1, points.size()):
		var a := points[n - 1]
		var seg := points[n] - a
		var length := seg.length()
		var d := spacing - carry
		while d <= length:
			out.append(a + seg * (d / length))
			d += spacing
		carry = length - (d - spacing)
	if out[out.size() - 1] != points[points.size() - 1]:
		out.append(points[points.size() - 1])
	return out
