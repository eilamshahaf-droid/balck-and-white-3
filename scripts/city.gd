extends Node3D
## Builds a simple procedural Manhattan-style city: a grid of avenues and
## streets, blocks of towers that grow taller toward midtown, a park,
## taxis to throw around, and residents who walk the grid.

const AVENUES := 7            # north-south roads
const STREETS := 14           # east-west roads
const AVENUE_SPACING := 80.0
const STREET_SPACING := 28.0
const AVENUE_WIDTH := 14.0
const STREET_WIDTH := 9.0
const SIDEWALK := 2.5
const CITIZEN_COUNT := 60
const TAXI_COUNT := 30

# Physics layers: 1 = world, 2 = citizens, 3 = props.
const LAYER_WORLD := 1
const LAYER_CITIZENS := 2
const LAYER_PROPS := 4

const CitizenScript := preload("res://scripts/citizen.gd")

## Debug view: tint residents by their hidden belief.
var show_belief := false

var rng := RandomNumberGenerator.new()
var half_size := Vector2.ZERO
var _materials := {}


func _ready() -> void:
	rng.seed = 3
	half_size = Vector2((AVENUES - 1) * AVENUE_SPACING, (STREETS - 1) * STREET_SPACING) / 2.0
	_build_environment()
	_build_ground()
	_build_blocks()
	_spawn_taxis()
	_spawn_citizens()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		show_belief = not show_belief


# --- Grid helpers (used by citizens) ---

func intersection(g: Vector2i) -> Vector3:
	return Vector3(g.x * AVENUE_SPACING - half_size.x, 0.0, g.y * STREET_SPACING - half_size.y)


func nearest_grid(p: Vector3) -> Vector2i:
	var gx := clampi(roundi((p.x + half_size.x) / AVENUE_SPACING), 0, AVENUES - 1)
	var gz := clampi(roundi((p.z + half_size.y) / STREET_SPACING), 0, STREETS - 1)
	return Vector2i(gx, gz)


func random_neighbor(g: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = g + d
		if n.x >= 0 and n.x < AVENUES and n.y >= 0 and n.y < STREETS:
			options.append(n)
	return options[rng.randi_range(0, options.size() - 1)]


func random_grid() -> Vector2i:
	return Vector2i(rng.randi_range(0, AVENUES - 1), rng.randi_range(0, STREETS - 1))


# --- Construction ---

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.75, 0.8, 0.88)
	sky_mat.ground_horizon_color = Color(0.6, 0.6, 0.62)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.8, 0.88)
	env.fog_density = 0.0008
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	add_child(sun)


func _build_ground() -> void:
	var size := Vector3(half_size.x * 2 + 200, 1.0, half_size.y * 2 + 200)
	_make_box(size, Vector3(0, -0.5, 0), _mat(Color(0.18, 0.18, 0.2)), true)


func _build_blocks() -> void:
	var max_dist := half_size.length()
	for i in AVENUES - 1:
		for j in STREETS - 1:
			var a := intersection(Vector2i(i, j))
			var b := intersection(Vector2i(i + 1, j + 1))
			var x0 := a.x + AVENUE_WIDTH / 2.0
			var x1 := b.x - AVENUE_WIDTH / 2.0
			var z0 := a.z + STREET_WIDTH / 2.0
			var z1 := b.z - STREET_WIDTH / 2.0
			var center := Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0)
			var size := Vector2(x1 - x0, z1 - z0)

			# Sidewalk slab under the whole block.
			_make_box(Vector3(size.x, 0.2, size.y), center + Vector3(0, 0.1, 0), _mat(Color(0.55, 0.55, 0.55)), true)

			if i == 3 and j >= 9:
				_build_park(center, size)
			else:
				# Midtown sits a little south of the middle, like Manhattan.
				var dist := Vector2(center.x, center.z + half_size.y * 0.25).length()
				_build_towers(center, size, 1.0 - clampf(dist / max_dist, 0.0, 1.0))


func _build_towers(center: Vector3, size: Vector2, midtown: float) -> void:
	var inner := size - Vector2.ONE * SIDEWALK * 2
	var x := center.x - inner.x / 2.0
	var end := center.x + inner.x / 2.0
	var palette := [
		Color(0.62, 0.6, 0.57), Color(0.5, 0.42, 0.36), Color(0.7, 0.68, 0.62),
		Color(0.36, 0.45, 0.55), Color(0.45, 0.47, 0.5), Color(0.58, 0.5, 0.42),
	]
	while x < end - 4.0:
		var width := minf(rng.randf_range(8.0, 16.0), end - x)
		var height := rng.randf_range(8.0, 22.0) + pow(midtown, 2.5) * rng.randf_range(30.0, 160.0)
		var depth := inner.y
		var pos := Vector3(x + width / 2.0, 0.2 + height / 2.0, center.z)
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]
		_make_box(Vector3(width - 0.6, height, depth), pos, _mat(color), true)
		x += width


func _build_park(center: Vector3, size: Vector2) -> void:
	_make_box(Vector3(size.x - 1.0, 0.1, size.y - 1.0), center + Vector3(0, 0.25, 0), _mat(Color(0.25, 0.5, 0.22)), false)
	for n in 14:
		var p := center + Vector3(rng.randf_range(-size.x, size.x) * 0.42, 0, rng.randf_range(-size.y, size.y) * 0.35)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.25
		trunk_mesh.bottom_radius = 0.35
		trunk_mesh.height = 3.0
		trunk.mesh = trunk_mesh
		trunk.material_override = _mat(Color(0.35, 0.25, 0.15))
		trunk.position = p + Vector3(0, 1.5, 0)
		add_child(trunk)
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = rng.randf_range(1.6, 2.6)
		crown_mesh.height = crown_mesh.radius * 2.0
		crown.mesh = crown_mesh
		crown.material_override = _mat(Color(0.2, 0.42, 0.18))
		crown.position = p + Vector3(0, 4.0, 0)
		add_child(crown)


func _spawn_taxis() -> void:
	for n in TAXI_COUNT:
		var taxi := RigidBody3D.new()
		taxi.add_to_group("god_grabbable")
		taxi.collision_layer = LAYER_PROPS
		taxi.collision_mask = LAYER_WORLD | LAYER_PROPS
		taxi.mass = 2.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 1.5, 4.5)
		shape.shape = box
		taxi.add_child(shape)
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box.size
		mesh.mesh = box_mesh
		mesh.material_override = _mat(Color(0.95, 0.75, 0.1))
		taxi.add_child(mesh)
		var avenue := intersection(Vector2i(rng.randi_range(0, AVENUES - 1), 0))
		taxi.position = Vector3(avenue.x + rng.randf_range(-4.0, 4.0), 1.0, rng.randf_range(-half_size.y, half_size.y))
		add_child(taxi)


func _spawn_citizens() -> void:
	for n in CITIZEN_COUNT:
		var c: CharacterBody3D = CitizenScript.new()
		c.city = self
		c.grid = random_grid()
		c.collision_layer = LAYER_CITIZENS
		c.collision_mask = LAYER_WORLD
		add_child(c)


func _make_box(size: Vector3, pos: Vector3, material: Material, collide: bool) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	if not collide:
		mesh.position = pos
		add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mesh)
	add_child(body)
	return body


func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[color] = m
	return _materials[color]
