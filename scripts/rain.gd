extends Node3D
## The water miracle: a small cloud gathers out of a clear sky and rains on
## one spot for a few seconds, putting out any fire under it.

const M = preload("res://data/miracles.tres")
const Sfx = preload("res://scripts/sfx.gd")

var _time_left := 0.0
var _rain: CPUParticles3D
var _cloud: Node3D
var _sound := 0.0
## The building the rain falls on. Witnesses in the street see the cloud over
## it, so it doesn't block their view (see faith.gd).
var see_through: Array[RID] = []


## Rain on `ground` (the point the god drew over); the cloud sits above it.
func start(ground: Vector3) -> void:
	position = ground + Vector3.UP * 14.0
	var query := PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 1.0, ground - Vector3.UP * 2.0, 1)
	var under := get_world_3d().direct_space_state.intersect_ray(query)
	if under and under.collider.is_in_group("buildings"):
		see_through.append(under.rid)
	_time_left = M.rain_time
	_cloud = Node3D.new()
	add_child(_cloud)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.55, 0.57, 0.62)
	# Faintly lit, so it reads against the night sky.
	grey.emission_enabled = true
	grey.emission = Color(0.35, 0.38, 0.45)
	for n in 9:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := randf_range(2.0, 3.5)
		sphere.radius = r
		sphere.height = r * 1.6
		puff.mesh = sphere
		puff.material_override = grey
		puff.position = Vector3(randf_range(-1, 1) * M.rain_radius * 0.7, randf_range(-0.5, 0.8), randf_range(-1, 1) * M.rain_radius * 0.7)
		_cloud.add_child(puff)
	_cloud.scale = Vector3.ONE * 0.1

	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.albedo_color = Color(0.7, 0.8, 1.0, 0.6)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.05, 0.9, 0.05)
	streak.material = drop_mat
	_rain = CPUParticles3D.new()
	_rain.mesh = streak
	_rain.amount = 500
	_rain.lifetime = 0.6
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(M.rain_radius, 0.2, M.rain_radius)
	_rain.direction = Vector3.DOWN
	_rain.spread = 2.0
	_rain.gravity = Vector3.DOWN * 20.0
	_rain.initial_velocity_min = 18.0
	_rain.initial_velocity_max = 22.0
	_rain.position.y = -1.0
	add_child(_rain)


## Where witnesses look: the cloud.
func aim_point() -> Vector3:
	return global_position


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_cloud.scale = _cloud.scale.lerp(Vector3.ONE if _time_left > 0.5 else Vector3.ONE * 0.05, 1.0 - exp(-3.0 * delta))
	_rain.emitting = _time_left > 0.5
	_sound -= delta
	if _time_left > 0.5 and _sound <= 0.0:
		_sound = 0.9
		Sfx.play(get_tree(), global_position + Vector3.DOWN * 12.0, &"rain", 0.7)
	if _time_left > 0.5:
		for fire in get_tree().get_nodes_in_group("fires"):
			var d := Vector2(fire.global_position.x - global_position.x, fire.global_position.z - global_position.z).length()
			if d < M.rain_radius + 6.0:
				fire.douse(M.douse_rate * delta)
	if _time_left < -2.0:
		queue_free()


## The people helped: everyone endangered by a fire under this rain.
func helped() -> Array:
	var out := []
	for fire in get_tree().get_nodes_in_group("fires"):
		var d := Vector2(fire.global_position.x - global_position.x, fire.global_position.z - global_position.z).length()
		if d < M.rain_radius + 6.0:
			out.append_array(fire.endangered)
	return out
