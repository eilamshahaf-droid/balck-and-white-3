extends Node3D
## The shield miracle: a glowing dome for a while. Nothing harmful gets in:
## fire and lightning can't be cast inside, and fires under it go out.

const M = preload("res://data/miracles.tres")
const Sfx = preload("res://scripts/sfx.gd")

const DOUSE_RATE := 0.5   # fire heat put out per second under the dome

var _time_left := 0.0
var radius := M.shield_radius
var _dome: MeshInstance3D
var _mat := StandardMaterial3D.new()


## `size` and `length` scale its radius and time (the miracle's power).
func raise(ground: Vector3, size := 1.0, length := 1.0) -> void:
	position = ground
	radius = M.shield_radius * size
	add_to_group("shields")
	_time_left = M.shield_time * length
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.3)
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius
	sphere.is_hemisphere = true
	_dome = MeshInstance3D.new()
	_dome.mesh = sphere
	_dome.material_override = _mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.scale = Vector3.ONE * 0.05
	add_child(_dome)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.6
	torus.outer_radius = radius
	rim.mesh = torus
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.albedo_color = Color(0.4, 0.9, 1.0)
	rim.material_override = rim_mat
	rim.scale = Vector3(1.0, 0.3, 1.0)
	_dome.add_child(rim)
	Sfx.play(get_tree(), ground, &"hum", 0.9)


func covers(p: Vector3) -> bool:
	return _time_left > 0.0 and p.distance_to(global_position) < radius


## The people saved: everyone endangered by a fire under the dome.
func helped() -> Array:
	var out := []
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire.is_burning() and covers(fire.global_position):
			out.append_array(fire.endangered)
	return out


## Where witnesses look: the top of the dome.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * radius * 0.8


func _physics_process(delta: float) -> void:
	_time_left -= delta
	var goal := 1.0 if _time_left > 0.0 else 0.05
	_dome.scale = _dome.scale.lerp(Vector3.ONE * goal, 1.0 - exp(-4.0 * delta))
	_mat.albedo_color.a = 0.26 + 0.06 * sin(_time_left * 3.0)
	if _time_left > 0.0:
		for fire in get_tree().get_nodes_in_group("fires"):
			if covers(fire.global_position):
				fire.douse(DOUSE_RATE * delta)
	elif _time_left < -1.5:
		queue_free()
