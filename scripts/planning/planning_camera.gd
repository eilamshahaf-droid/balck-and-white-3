extends Node3D
## A plain planner's camera for the city-planning scene: no hand, just look.
## WASD / arrows or right-drag to move, wheel to zoom, Q/E to turn, R/F to tilt.

@export var distance := 400.0
@export var min_distance := 60.0
@export var max_distance := 1100.0
@export var pitch := 55.0
@export var yaw := 20.0
@export var pan_speed := 1.2       # screen fraction of the view per second

var _dragging := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply()


## 0 when close, 1 when zoomed all the way out.
func zoom_t() -> float:
	return inverse_lerp(min_distance, max_distance, distance)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = maxf(distance * 0.88, min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(distance / 0.88, max_distance)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		_apply()
	elif event is InputEventMouseMotion and _dragging:
		var metres_per_pixel := distance / get_viewport().get_visible_rect().size.y * 1.6
		_pan(Vector2(-event.relative.x, -event.relative.y) * metres_per_pixel)


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1
	if move != Vector2.ZERO:
		_pan(move * distance * pan_speed * delta)
	if Input.is_key_pressed(KEY_Q):
		yaw += 70.0 * delta
	if Input.is_key_pressed(KEY_E):
		yaw -= 70.0 * delta
	if Input.is_key_pressed(KEY_R):
		pitch = minf(pitch + 40.0 * delta, 88.0)
	if Input.is_key_pressed(KEY_F):
		pitch = maxf(pitch - 40.0 * delta, 25.0)
	_apply()


## Move along the ground, in screen directions.
func _pan(screen: Vector2) -> void:
	var right := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
	var forward := Vector3(-sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
	position += right * screen.x - forward * screen.y
	position.x = clampf(position.x, -400.0, 400.0)
	position.z = clampf(position.z, -300.0, 300.0)


func _apply() -> void:
	rotation_degrees = Vector3(0, yaw, 0)
	camera.position = Vector3(0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))) * distance
	camera.rotation_degrees = Vector3(-pitch, 0, 0)
