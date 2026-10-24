extends Node3D
## RTS-style god camera. The rig sits on the ground; the camera orbits it.
## WASD / arrows pan, Q / E or middle-drag rotate, mouse wheel zooms.

const PAN_SPEED := 60.0
const ROTATE_SPEED := 1.5
const ZOOM_MIN := 15.0
const ZOOM_MAX := 400.0
const ZOOM_STEP := 1.15
const PITCH_MIN := -1.45
const PITCH_MAX := -0.25
const DRAG_SENSITIVITY := 0.005

@onready var camera: Camera3D = $Camera3D

var distance := 160.0
var yaw := 0.0
var pitch := -0.9
var _dragging := false


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	if input != Vector2.ZERO:
		var forward := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		position += (right * input.x - forward * input.y).normalized() * PAN_SPEED * (distance / 100.0) * delta

	if Input.is_key_pressed(KEY_Q):
		yaw += ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_E):
		yaw -= ROTATE_SPEED * delta
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(distance / ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(distance * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * DRAG_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * DRAG_SENSITIVITY, PITCH_MIN, PITCH_MAX)


func _apply() -> void:
	rotation = Vector3(pitch, yaw, 0)
	camera.position = Vector3(0, 0, distance)
