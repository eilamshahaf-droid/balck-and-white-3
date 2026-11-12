class_name City
extends Node3D
## The city of the current stage, built from its map (CityPlan, made in the Map Lab:
## data/maps/<stage>/map.json): streets, buildings grouped into the units the player
## takes, trees, taxis to throw around, litter and pigeons, and the street graph
## residents walk (see people/population.gd). What lies beyond the map is surroundings.gd.

const GROUND_MARGIN := Vector2(8.0, 8.0)   # asphalt past the edge of the map

# Physics layers: 1 = world, 2 = citizens, 3 = props, 4 = critters (pigeons).
const LAYER_WORLD := 1
const LAYER_CITIZENS := 2
const LAYER_PROPS := 4
const LAYER_CRITTERS := 8

const S: CitySettings = preload("res://data/city.tres")
const TaxiScript := preload("res://scripts/taxi.gd")
const LitterScript := preload("res://scripts/litter.gd")
const PigeonScript := preload("res://scripts/pigeon.gd")
const PROPS_SETTINGS := "res://data/city_props.tres"   # load() at run time: typed PropKind arrays

## Debug view: tint residents by their hidden belief.
var show_belief := false

var rng := RandomNumberGenerator.new()
var env: Environment
var sun: DirectionalLight3D
var half_size := Vector2.ZERO
## The stage's map.
var plan: CityPlan
## Every building's node, by CityPlan building index.
var building_nodes: Array[StaticBody3D] = []
var _sky_mat: ProceduralSkyMaterial
var _builder: PlanBuilder


func _ready() -> void:
	rng.seed = 3
	plan = CityPlan.load_file(S.map_path)
	half_size = plan.size / 2.0
	_build_environment()
	_builder = PlanBuilder.new(self, plan, S)
	_build_ground()
	_builder.build(LAYER_WORLD, LAYER_PROPS)
	building_nodes = _builder.building_nodes
	_spawn_taxis()
	_spawn_litter()
	_spawn_pigeons()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		show_belief = not show_belief


# --- The street graph (used by citizens) ---

## Where walking node `n` stands, on the ground.
func node_position(n: int) -> Vector3:
	var p := plan.nodes[n]
	return Vector3(p.x, 0.0, p.y)


## The walking node nearest `p`.
func nearest_node(p: Vector3) -> int:
	return plan.nearest_node(Vector2(p.x, p.z))


## A node next to `n` along a street, other than `back` when there is a choice.
func random_neighbor(n: int, back := -1) -> int:
	var options := plan.neighbours[n]
	if options.is_empty():
		return n
	if options.size() == 1:
		return options[0]
	var pick := options[rng.randi_range(0, options.size() - 1)]
	while pick == back:
		pick = options[rng.randi_range(0, options.size() - 1)]
	return pick


## The nodes of a walk of up to `steps` steps along the streets from `n`, `n` first.
func walk_from(n: int, steps: int) -> PackedInt32Array:
	var path := PackedInt32Array([n])
	var back := -1
	for k in steps:
		var next := random_neighbor(path[path.size() - 1], back)
		if next in path:
			break
		back = path[path.size() - 1]
		path.append(next)
	return path


func random_node() -> int:
	return rng.randi_range(0, plan.nodes.size() - 1)


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


## 0 = night, 1 = full day.
func set_daylight(t: float) -> void:
	var horizon := Color(0.1, 0.1, 0.18).lerp(Color(0.74, 0.86, 0.97), t)
	_sky_mat.sky_top_color = Color(0.03, 0.04, 0.1).lerp(Color(0.22, 0.5, 0.92), t)
	_sky_mat.sky_horizon_color = horizon
	# Below the horizon the sky matches the fog, so the land melts into it with no edge.
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon
	env.fog_light_color = horizon
	env.ambient_light_energy = lerpf(0.4, 0.5, t)
	sun.light_energy = lerpf(0.3, 0.9, t)
	sun.light_color = Color(0.6, 0.7, 1.0).lerp(Color.WHITE, t)


func _build_ground() -> void:
	var size := Vector3((half_size.x + GROUND_MARGIN.x) * 2.0, 0.5, (half_size.y + GROUND_MARGIN.y) * 2.0)
	_make_box(size, Vector3(0, -0.25, 0), _mat(S.asphalt_color), true).set_meta("surface", &"asphalt")


## Taxis parked along the wider streets, nose along the street, on their side of it.
func _spawn_taxis() -> void:
	var taxi_kind := (load(PROPS_SETTINGS) as CityPropsSettings).taxi
	var wide: Array[CityPlan.Road] = []
	for road in plan.roads:
		if road.tier != &"street":
			wide.append(road)
	if wide.is_empty():
		wide = plan.roads
	for n in S.taxi_count:
		var road: CityPlan.Road = wide[rng.randi_range(0, wide.size() - 1)]
		var i := rng.randi_range(0, road.points.size() - 2)
		var a := road.points[i]
		var b := road.points[i + 1]
		var along := (b - a).normalized()
		var p := a.lerp(b, rng.randf()) + Vector2(-along.y, along.x) * S.taxi_lane * (1.0 if rng.randf() < 0.5 else -1.0)
		var taxi: RigidBody3D = TaxiScript.new()
		taxi.collision_layer = LAYER_PROPS
		taxi.collision_mask = LAYER_WORLD | LAYER_PROPS
		taxi.build(taxi_kind)
		taxi.position = Vector3(p.x, 1.0, p.y)
		taxi.rotation.y = -along.angle()
		add_child(taxi)


func _spawn_litter() -> void:
	var paper := _mat(Color(0.85, 0.84, 0.78))
	for n in S.litter_count:
		var sheet: RigidBody3D = LitterScript.new()
		sheet.collision_layer = LAYER_PROPS
		sheet.collision_mask = LAYER_WORLD | LAYER_PROPS
		sheet.build(paper)
		var corner := node_position(random_node())
		sheet.position = corner + Vector3(rng.randf_range(-3, 3), 0.4, rng.randf_range(-3, 3))
		sheet.rotation.y = rng.randf() * TAU
		add_child(sheet)


func _spawn_pigeons() -> void:
	var grey := _mat(Color(0.5, 0.52, 0.58))
	for f in S.pigeon_flocks:
		var center := node_position(random_node())
		for n in rng.randi_range(4, 7):
			var bird: Area3D = PigeonScript.new()
			bird.collision_layer = LAYER_CRITTERS
			bird.collision_mask = 0
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
	return _builder.material(color)
