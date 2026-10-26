extends Area3D
## A street pigeon. Pecks around until the god's hand comes close or its wind
## blows, then flies off and lands somewhere else a few seconds later.
## An Area3D only so the hand's wind query can find it; it watches nothing.

enum State { IDLE, FLEE, LAND }

const FLEE_SPEED := 9.0
const SCARE_DISTANCE := 7.0
const SCARE_WIND := 0.12

var city: Node3D
var state := State.IDLE
var _velocity := Vector3.ZERO
var _timer := 0.0
var _landing := Vector3.ZERO
var _wings: Array[Node3D] = []
var _t := randf() * 10.0


func build(body_mat: Material) -> void:
	add_to_group("wind_reactive")
	monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	shape.position.y = 0.2
	add_child(shape)
	set_meta("surface", &"feathers")
	var body := MeshInstance3D.new()
	body.mesh = SharedMeshes.box(Vector3(0.22, 0.2, 0.36))
	body.material_override = body_mat
	body.position.y = 0.16
	add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = SharedMeshes.unit_sphere(8, 4)
	head.scale = Vector3.ONE * 0.08
	head.material_override = body_mat
	head.position = Vector3(0, 0.3, -0.18)
	add_child(head)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(0.11 * side, 0.22, 0)
		add_child(hinge)
		var wing := MeshInstance3D.new()
		wing.mesh = SharedMeshes.box(Vector3(0.3, 0.02, 0.22))
		wing.material_override = body_mat
		wing.position.x = 0.15 * side
		hinge.add_child(wing)
		_wings.append(hinge)


func on_hand_wind(hand: Node3D) -> void:
	if state != State.IDLE:
		return
	var d := global_position.distance_to(hand.global_position)
	if d < SCARE_DISTANCE or hand.wind_strength(global_position) > SCARE_WIND:
		var away := global_position - hand.global_position
		away.y = 0
		_velocity = (away.normalized() * 0.8 + Vector3.UP).normalized() * FLEE_SPEED
		_timer = randf_range(2.5, 4.5)
		state = State.FLEE


func _physics_process(delta: float) -> void:
	_t += delta
	match state:
		State.IDLE:
			# Peck: a little bob and an occasional turn.
			position.y = absf(sin(_t * 3.0)) * 0.02
			if randf() < 0.005:
				rotation.y += randf_range(-1.5, 1.5)
			_flap(0.0)
		State.FLEE:
			_velocity.y = maxf(_velocity.y - 2.0 * delta, 1.0)
			position += _velocity * delta
			_face(_velocity)
			_flap(1.0)
			_timer -= delta
			if _timer <= 0.0:
				var g: Vector2i = city.random_grid()
				_landing = city.intersection(g) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
				state = State.LAND
		State.LAND:
			var to := _landing - position
			if to.length() < 0.3:
				position = _landing
				state = State.IDLE
			else:
				var v := to.normalized() * FLEE_SPEED
				position += v * delta
				_face(v)
				_flap(0.6)


func _face(v: Vector3) -> void:
	if Vector2(v.x, v.z).length() > 0.01:
		rotation.y = atan2(-v.x, -v.z)


func _flap(amount: float) -> void:
	var angle := sin(_t * 30.0) * 0.9 * amount
	_wings[0].rotation.z = -angle
	_wings[1].rotation.z = angle
