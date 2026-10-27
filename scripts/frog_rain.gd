extends Node3D
## The Rain of Frogs miracle: frogs pour out of a clear sky onto a few blocks
## and hop about the street. What it does to people is up to miracles.gd;
## this is only the frogs.

const M: MiracleSettings = preload("res://data/miracles.tres")
const Sfx := preload("res://scripts/sfx.gd")

const FALL_FROM := 30.0    # metres above the street

static var _mesh: BoxMesh

var _time_left := 0.0
var _falling: CPUParticles3D
var _hopping: CPUParticles3D


## Rain frogs on `ground`; `size` scales the area, `length` how long it lasts.
func start(ground: Vector3, size := 1.0, length := 1.0) -> void:
	position = ground
	_time_left = M.frog_time * length
	if _mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.75, 0.25)
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.45, 0.3, 0.55)
		_mesh.material = mat
	var radius := M.frog_radius * size
	var count := roundi(M.frog_count * size)
	# Out of the sky...
	_falling = _frogs(count, Vector3(radius, 1.0, radius), FALL_FROM)
	_falling.direction = Vector3.DOWN
	_falling.spread = 10.0
	_falling.gravity = Vector3.DOWN * 20.0
	_falling.initial_velocity_min = 2.0
	_falling.initial_velocity_max = 6.0
	_falling.lifetime = 1.6
	# ...and hopping all over the street.
	_hopping = _frogs(count, Vector3(radius, 0.0, radius), 0.2)
	_hopping.direction = Vector3.UP
	_hopping.spread = 40.0
	_hopping.gravity = Vector3.DOWN * 14.0
	_hopping.initial_velocity_min = 3.0
	_hopping.initial_velocity_max = 5.5
	_hopping.lifetime = 0.75
	Sfx.play(get_tree(), ground, &"strain", 1.0)
	Sfx.play(get_tree(), ground, &"earth", 0.8)


## Where witnesses look: the frogs coming down.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * 6.0


func _frogs(count: int, extents: Vector3, y: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh
	p.amount = maxi(count, 8)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.particle_flag_rotate_y = true
	p.position.y = y
	add_child(p)
	return p


func _process(delta: float) -> void:
	_time_left -= delta
	_falling.emitting = _time_left > 0.0
	_hopping.emitting = _time_left > -1.0  # the last frogs land and hop on a little
	if _time_left < -3.0:
		queue_free()
