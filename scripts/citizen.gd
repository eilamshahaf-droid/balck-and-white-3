extends CharacterBody3D
## A city resident who walks between intersections.
##
## Belief is hidden from the player. A miracle can push it toward faith or
## toward skepticism, depending on what the miracle did to this person and on
## a personal coefficient (faith_bias) the player never sees.

enum State { WALKING, HELD, FALLING }

const GRAVITY := 20.0
const HARD_LANDING_SPEED := 14.0

var city: Node3D
## Used by the god's hand: heavier things lag and swing more when held.
var mass := 1.0
var fall_gravity := GRAVITY
var grid := Vector2i.ZERO
var state := State.WALKING
var speed := 3.0
var target := Vector3.ZERO
var lane_offset := Vector3.ZERO

## Hidden: -1 = total skeptic, +1 = devoted believer.
var belief := 0.0
## Hidden personal coefficient: > 0 reads the supernatural as faith,
## < 0 looks for a rational explanation.
var faith_bias := 0.0

var _body: MeshInstance3D
var _own_mat := StandardMaterial3D.new()
var _debug_mat := StandardMaterial3D.new()
var _fall_speed := 0.0
var _pause := 0.0


func _ready() -> void:
	add_to_group("citizens")
	add_to_group("god_grabbable")

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	_body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.8
	_body.mesh = mesh
	_body.position.y = 0.9
	_own_mat.albedo_color = Color.from_hsv(randf(), 0.45, 0.85)
	_body.material_override = _own_mat
	add_child(_body)

	speed = randf_range(2.0, 4.0)
	belief = randf_range(-0.6, 0.2)
	faith_bias = randf_range(-1.0, 1.0)
	lane_offset = Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
	position = city.intersection(grid) + lane_offset + Vector3.UP * 0.1
	_pick_next_target()


func _physics_process(delta: float) -> void:
	match state:
		State.HELD:
			move_and_slide()  # The god's hand drives our velocity through a spring.
		State.FALLING:
			velocity.y -= fall_gravity * delta
			_fall_speed = maxf(_fall_speed, -velocity.y)
			move_and_slide()
			if is_on_floor():
				_land()
			elif global_position.y < -30.0:
				_respawn()
		State.WALKING:
			if _pause > 0.0:
				_pause -= delta
				return
			var to_target := target - global_position
			to_target.y = 0
			if to_target.length() < 0.6:
				_pick_next_target()
			else:
				var dir := to_target.normalized()
				velocity = Vector3(dir.x * speed, -1.0, dir.z * speed)
				rotation.y = atan2(dir.x, dir.z)
				move_and_slide()


func _process(_delta: float) -> void:
	if city.show_belief:
		# Red = skeptic, white = undecided, gold = believer.
		var c := Color.WHITE
		if belief < 0:
			c = Color.WHITE.lerp(Color(0.9, 0.15, 0.1), -belief)
		else:
			c = Color.WHITE.lerp(Color(1.0, 0.8, 0.1), belief)
		_debug_mat.albedo_color = c
		_body.material_override = _debug_mat
	else:
		_body.material_override = _own_mat


## Shift belief after witnessing or experiencing a miracle.
## kindness: +1 the miracle helped this person, 0 a neutral spectacle, -1 it hurt them.
func react_to_miracle(intensity: float, kindness: float) -> void:
	var reading := faith_bias * 0.5 + kindness * 0.7 + belief * 0.3 + randf_range(-0.3, 0.3)
	belief = clampf(belief + reading * intensity, -1.0, 1.0)


func on_grabbed() -> void:
	state = State.HELD
	velocity = Vector3.ZERO
	react_to_miracle(0.3, 0.0)


## Tapped by the hand: stop and turn toward where it came from.
func on_tapped(from: Vector3) -> void:
	_pause = 1.2
	var d := from - global_position
	rotation.y = atan2(d.x, d.z)


func on_released(throw_velocity: Vector3) -> void:
	state = State.FALLING
	velocity = throw_velocity
	_fall_speed = 0.0


func _land() -> void:
	if _fall_speed > HARD_LANDING_SPEED:
		react_to_miracle(0.5, -1.0)
	state = State.WALKING
	grid = city.nearest_grid(global_position)
	target = city.intersection(grid) + lane_offset


func _respawn() -> void:
	state = State.WALKING
	grid = city.random_grid()
	global_position = city.intersection(grid) + lane_offset + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	_pick_next_target()


func _pick_next_target() -> void:
	grid = city.random_neighbor(grid)
	target = city.intersection(grid) + lane_offset
