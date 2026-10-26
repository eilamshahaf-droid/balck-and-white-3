extends Node3D
## The healing miracle: golden light falls on a spot. Anyone lying hurt gets
## up, and burnt buildings and fires there are made whole again.

const M = preload("res://data/miracles.tres")
const Sfx = preload("res://scripts/sfx.gd")

var _t := 0.0
var _light: OmniLight3D
var _sparks: CPUParticles3D
var radius := M.heal_radius
var duration := M.heal_time


## Heal around `ground`. Returns the people it helped. `size` and `length`
## scale its radius and time (the miracle's power).
func bless(ground: Vector3, size := 1.0, length := 1.0) -> Array:
	position = ground
	radius = M.heal_radius * size
	duration = M.heal_time * length
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	var dot := SphereMesh.new()
	dot.radius = 0.12
	dot.height = 0.24
	dot.material = mat
	_sparks = CPUParticles3D.new()
	_sparks.mesh = dot
	_sparks.amount = roundi(160 * size * size)
	_sparks.lifetime = 1.6
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = radius * 0.7
	_sparks.position = Vector3.UP * 10.0
	_sparks.direction = Vector3.DOWN
	_sparks.gravity = Vector3.DOWN * 3.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 5.0
	add_child(_sparks)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.45)
	_light.omni_range = radius * 2.0
	_light.position = Vector3.UP * 4.0
	add_child(_light)
	Sfx.play(get_tree(), ground, &"shimmer", 0.9)

	var helped := []
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.global_position.distance_to(ground) < radius and c.heal():
			helped.append(c)
	for fire in get_tree().get_nodes_in_group("fires"):
		var p: Vector3 = fire.building.global_position if fire.building else fire.global_position
		if Vector2(p.x - ground.x, p.z - ground.z).length() < radius:
			helped.append_array(fire.endangered)
			fire.restore()
	return helped


## Where witnesses look: the falling light.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * 5.0


func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = 4.0 * sin(clampf(_t / duration, 0.0, 1.0) * PI)
	_sparks.emitting = _t < duration - 1.0
	if _t > duration + 1.0:
		queue_free()
