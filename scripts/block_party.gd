extends Node3D
## The Block Party miracle: a disco ball comes down out of a clear sky over a
## street, coloured lights sweep the pavement and confetti falls. Everyone
## near drops what they are doing to dance (miracles.gd calls them over).

const M: MiracleSettings = preload("res://data/miracles.tres")
const Sfx := preload("res://scripts/sfx.gd")

const HANG := 9.0          # metres above the street the ball hangs
const DROP_FROM := 40.0    # metres above the street it comes down from
const DROP_SPEED := 18.0   # metres per second
const SPIN := 1.5          # radians per second, the ball
const SWEEP := 2.2         # radians per second, the lights
const COLORS: Array[Color] = [Color(1.0, 0.3, 0.8), Color(0.3, 0.9, 1.0), Color(1.0, 0.9, 0.3)]

static var _ball_mesh: SphereMesh
static var _confetti_mesh: QuadMesh

var _time_left := 0.0
var _radius := 1.0
var _t := 0.0
var _ball: MeshInstance3D
var _lights: Array[OmniLight3D] = []
var _confetti: CPUParticles3D


## Throw the party on `ground`; `size` scales the dance floor, `length` how long.
func start(ground: Vector3, size := 1.0, length := 1.0) -> void:
	position = ground
	_time_left = M.party_time * length
	_radius = M.party_radius * size
	if _ball_mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.88, 0.95)
		mat.metallic = 1.0
		mat.roughness = 0.15
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 1.2
		_ball_mesh.height = 2.4
		_ball_mesh.radial_segments = 12
		_ball_mesh.rings = 6
		_ball_mesh.material = mat
		var paper := StandardMaterial3D.new()
		paper.vertex_color_use_as_albedo = true
		paper.cull_mode = BaseMaterial3D.CULL_DISABLED
		paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_confetti_mesh = QuadMesh.new()
		_confetti_mesh.size = Vector2(0.25, 0.15)
		_confetti_mesh.material = paper
	_ball = MeshInstance3D.new()
	_ball.mesh = _ball_mesh
	_ball.position.y = DROP_FROM
	add_child(_ball)
	for col in COLORS:
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 4.0
		light.omni_range = _radius * 0.8
		add_child(light)
		_lights.append(light)
	_confetti = CPUParticles3D.new()
	_confetti.mesh = _confetti_mesh
	_confetti.amount = roundi(120 * size)
	_confetti.lifetime = 3.0
	_confetti.position.y = HANG
	_confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_confetti.emission_sphere_radius = 1.5
	_confetti.spread = 180.0
	_confetti.initial_velocity_min = 2.0
	_confetti.initial_velocity_max = 5.0
	_confetti.gravity = Vector3.DOWN * 2.0
	_confetti.angular_velocity_min = -400.0
	_confetti.angular_velocity_max = 400.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	ramp.colors = PackedColorArray([COLORS[0], COLORS[1], COLORS[2], COLORS[0]])
	_confetti.color_initial_ramp = ramp
	add_child(_confetti)
	Sfx.play(get_tree(), ground, &"shimmer", 1.0)
	Sfx.play(get_tree(), ground, &"chime", 0.8)


## Where witnesses look: the disco ball.
func aim_point() -> Vector3:
	return _ball.global_position if _ball else global_position


## A spot on the dance floor for dancer number `i` of `count`, in a ring.
func dance_spot(i: int, count: int) -> Vector3:
	var a := TAU * i / maxf(count, 1.0) + randf_range(-0.2, 0.2)
	var r := _radius * randf_range(0.25, 0.6)
	return global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _process(delta: float) -> void:
	_t += delta
	_time_left -= delta
	# Down at the start; back up into the sky when the party is over.
	var goal := HANG if _time_left > 0.0 else DROP_FROM + 10.0
	_ball.position.y = move_toward(_ball.position.y, goal, DROP_SPEED * delta)
	_ball.rotation.y += SPIN * delta
	_confetti.emitting = _time_left > 0.0 and _ball.position.y < HANG + 1.0
	for i in _lights.size():
		var a := _t * SWEEP + TAU * i / _lights.size()
		_lights[i].position = Vector3(cos(a), 0.0, sin(a)) * _radius * 0.45 + Vector3.UP * 2.0
		_lights[i].visible = _time_left > 0.0
	if _time_left <= 0.0 and _ball.position.y >= DROP_FROM:
		queue_free()
