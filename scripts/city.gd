extends Node3D
## Builds a simple procedural Manhattan-style city: a grid of avenues and
## streets, blocks of towers that grow taller toward midtown, a park,
## taxis to throw around, and the grid that residents walk (see people/population.gd).

const AVENUES := 7            # north-south roads
const STREETS := 14           # east-west roads
const AVENUE_SPACING := 80.0
const STREET_SPACING := 28.0
const AVENUE_WIDTH := 14.0
const STREET_WIDTH := 9.0
const SIDEWALK := 2.5
const TAXI_COUNT := 30
const LITTER_COUNT := 160
const PIGEON_FLOCKS := 8

# Physics layers: 1 = world, 2 = citizens, 3 = props.
const LAYER_WORLD := 1
const LAYER_CITIZENS := 2
const LAYER_PROPS := 4

const TaxiScript := preload("res://scripts/taxi.gd")
const TreeScript := preload("res://scripts/swaying_tree.gd")
const DoorScript := preload("res://scripts/door.gd")
const LitterScript := preload("res://scripts/litter.gd")
const PigeonScript := preload("res://scripts/pigeon.gd")
const BuildingVisual := preload("res://scripts/building_visual.gd")

## Debug view: tint residents by their hidden belief.
var show_belief := false

var rng := RandomNumberGenerator.new()
var env: Environment
var sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var half_size := Vector2.ZERO
var _materials := {}


func _ready() -> void:
	rng.seed = 3
	half_size = Vector2((AVENUES - 1) * AVENUE_SPACING, (STREETS - 1) * STREET_SPACING) / 2.0
	_build_environment()
	_build_ground()
	_build_blocks()
	_spawn_taxis()
	_spawn_litter()
	_spawn_pigeons()


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
	_sky_mat = sky_mat
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.fog_enabled = true
	env.fog_density = 0.0008
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	add_child(sun)
	set_daylight(1.0)


## 0 = night, 1 = full day. The opening starts at night.
func set_daylight(t: float) -> void:
	_sky_mat.sky_top_color = Color(0.03, 0.04, 0.1).lerp(Color(0.35, 0.55, 0.85), t)
	_sky_mat.sky_horizon_color = Color(0.1, 0.1, 0.18).lerp(Color(0.75, 0.8, 0.88), t)
	_sky_mat.ground_horizon_color = Color(0.06, 0.06, 0.08).lerp(Color(0.6, 0.6, 0.62), t)
	env.fog_light_color = Color(0.08, 0.08, 0.14).lerp(Color(0.75, 0.8, 0.88), t)
	env.ambient_light_energy = lerpf(0.4, 0.5, t)
	sun.light_energy = lerpf(0.3, 0.9, t)
	sun.light_color = Color(0.6, 0.7, 1.0).lerp(Color.WHITE, t)


func _build_ground() -> void:
	var size := Vector3(half_size.x * 2 + 200, 1.0, half_size.y * 2 + 200)
	_make_box(size, Vector3(0, -0.5, 0), _mat(Color(0.18, 0.18, 0.2)), true).set_meta("surface", &"asphalt")


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
				_line_street_trees(center, size)
				# Midtown sits a little south of the middle, like Manhattan.
				var dist := Vector2(center.x, center.z + half_size.y * 0.25).length()
				_build_towers(center, size, 1.0 - clampf(dist / max_dist, 0.0, 1.0))


func _line_street_trees(center: Vector3, size: Vector2) -> void:
	# A few trees along the sidewalk on the long sides of the block, NYC style.
	for side in [-1.0, 1.0]:
		var z: float = center.z + side * (size.y / 2.0 - SIDEWALK / 2.0)
		var x := center.x - size.x / 2.0 + rng.randf_range(4.0, 9.0)
		while x < center.x + size.x / 2.0 - 4.0:
			if rng.randf() < 0.5:
				_plant_tree(Vector3(x, 0.2, z), rng.randf_range(1.1, 1.6))
			x += rng.randf_range(9.0, 16.0)


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
		var building := _make_box(Vector3(width - 0.6, height, depth), pos, _mat(color), true)
		building.add_to_group("buildings")
		# Dress the box in Kenney's modular facades; the collision box stays as it was.
		for child in building.get_children():
			if child is MeshInstance3D:
				child.free()
		building.add_child(BuildingVisual.build(Vector3(width - 0.6, height, depth), hash(pos), height > 60.0))
		# Tall towers are glass curtain walls; the rest is stone and brick.
		building.set_meta("surface", &"glass" if height > 60.0 else &"concrete")
		_add_door(Vector3(pos.x, 0.2, center.z), depth)
		x += width


func _build_park(center: Vector3, size: Vector2) -> void:
	_make_box(Vector3(size.x - 1.0, 0.1, size.y - 1.0), center + Vector3(0, 0.25, 0), _mat(Color(0.25, 0.5, 0.22)), true).set_meta("surface", &"grass")
	for n in 14:
		var p := center + Vector3(rng.randf_range(-size.x, size.x) * 0.42, 0, rng.randf_range(-size.y, size.y) * 0.35)
		_plant_tree(p + Vector3.UP * 0.3, rng.randf_range(1.6, 2.6))


func _plant_tree(pos: Vector3, crown_radius: float) -> void:
	var tree: StaticBody3D = TreeScript.new()
	tree.collision_layer = LAYER_PROPS
	tree.collision_mask = 0
	tree.build(_mat(Color(0.35, 0.25, 0.15)), _mat(Color(0.2, 0.42, 0.18)), crown_radius)
	tree.position = pos
	add_child(tree)


func _spawn_taxis() -> void:
	for n in TAXI_COUNT:
		var taxi: RigidBody3D = TaxiScript.new()
		taxi.collision_layer = LAYER_PROPS
		taxi.collision_mask = LAYER_WORLD | LAYER_PROPS
		taxi.build(_mat(Color(0.95, 0.75, 0.1)))
		var avenue := intersection(Vector2i(rng.randi_range(0, AVENUES - 1), 0))
		taxi.position = Vector3(avenue.x + rng.randf_range(-4.0, 4.0), 1.0, rng.randf_range(-half_size.y, half_size.y))
		add_child(taxi)


func _add_door(base: Vector3, depth: float) -> void:
	# A door on one of the two street-facing walls of the building.
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var door: Node3D = DoorScript.new()
	door.build(_mat(Color(0.3, 0.2, 0.14)))
	door.position = base + Vector3(-0.7 * side, 0, side * (depth / 2.0 + 0.07))
	door.rotation.y = 0.0 if side > 0 else PI
	add_child(door)


func _spawn_litter() -> void:
	var paper := _mat(Color(0.85, 0.84, 0.78))
	for n in LITTER_COUNT:
		var sheet: RigidBody3D = LitterScript.new()
		sheet.collision_layer = LAYER_PROPS
		sheet.collision_mask = LAYER_WORLD | LAYER_PROPS
		sheet.build(paper)
		var corner := intersection(random_grid())
		sheet.position = corner + Vector3(rng.randf_range(-12, 12), 0.4, rng.randf_range(-6, 6))
		sheet.rotation.y = rng.randf() * TAU
		add_child(sheet)


func _spawn_pigeons() -> void:
	var grey := _mat(Color(0.5, 0.52, 0.58))
	for f in PIGEON_FLOCKS:
		var center := intersection(random_grid())
		for n in rng.randi_range(4, 7):
			var bird: Node3D = PigeonScript.new()
			bird.city = self
			bird.build(grey)
			bird.position = center + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			bird.rotation.y = rng.randf() * TAU
			add_child(bird)


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
