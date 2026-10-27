extends Node3D
## The money miracle: banknotes flutter down out of a clear sky onto one spot.

const M: MiracleSettings = preload("res://data/miracles.tres")
const Sfx := preload("res://scripts/sfx.gd")

static var _mesh: QuadMesh

var _time_left := 0.0
var _notes: CPUParticles3D


## Rain banknotes on `ground`; `size` scales the patch, `length` how long it lasts.
func start(ground: Vector3, size := 1.0, length := 1.0) -> void:
	position = ground + Vector3.UP * 22.0
	_time_left = M.money_time * length
	if _mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.8, 0.45)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(0.6, 0.3)
		_mesh.material = mat
	var radius := M.money_radius * size
	_notes = CPUParticles3D.new()
	_notes.mesh = _mesh
	_notes.amount = roundi(260 * size * size)
	_notes.lifetime = 4.0
	_notes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_notes.emission_box_extents = Vector3(radius, 0.5, radius)
	_notes.direction = Vector3.DOWN
	_notes.spread = 25.0
	_notes.gravity = Vector3.DOWN * 2.5
	_notes.initial_velocity_min = 2.0
	_notes.initial_velocity_max = 4.0
	_notes.angular_velocity_min = -360.0
	_notes.angular_velocity_max = 360.0
	_notes.particle_flag_rotate_y = true
	add_child(_notes)
	Sfx.play(get_tree(), ground, &"paper", 1.0)
	Sfx.play(get_tree(), ground, &"chime", 0.6)


## Where witnesses look: the notes coming down.
func aim_point() -> Vector3:
	return global_position + Vector3.DOWN * 12.0


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_notes.emitting = _time_left > 0.0
	if _time_left < -4.0:
		queue_free()
