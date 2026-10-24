extends Node3D
## God camera in the spirit of Black & White. The hand grabs the city and drags
## it, double-click flies to a point, middle-drag orbits around the point under
## the cursor, and the wheel zooms toward the cursor. The keyboard stays as a
## full alternative (WASD pan, Q/E rotate, R/F tilt).
##
## Input only changes the target pose; the rendered pose glides toward it, so
## the response is instant while the motion stays smooth.

const S = preload("res://data/hand_settings.tres")
const LAYER_WORLD := 1
const RAY_LENGTH := 3000.0

@onready var camera: Camera3D = $Camera3D
@onready var city: Node3D = get_parent()

# Target pose (what input changes). Pitch is measured downward from the horizon.
var target_pivot := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := deg_to_rad(50.0)
var target_distance := 160.0

# Current pose (what is rendered).
var pivot := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var distance := 0.0

var _ground_drag := false
var _grab_point := Vector3.ZERO
var _orbiting := false
var _orbit_point := Vector3.ZERO
var _flying := false
var _fly_t := 0.0
var _fly_from_pivot := Vector3.ZERO
var _fly_to_pivot := Vector3.ZERO
var _fly_from_distance := 0.0
var _fly_to_distance := 0.0


func _ready() -> void:
	pivot = target_pivot
	yaw = target_yaw
	pitch = target_pitch
	distance = target_distance
	_place_camera()


func _process(delta: float) -> void:
	_keyboard(delta)
	if _flying:
		_update_fly(delta)
	_clamp_targets()

	var w := 1.0 - exp(-S.smoothing * delta)
	pivot = pivot.lerp(target_pivot, w)
	yaw = lerpf(yaw, target_yaw, w)
	pitch = lerpf(pitch, target_pitch, w)
	distance = lerpf(distance, target_distance, w)

	# Ground drag skips smoothing: the grabbed point must stay exactly under the hand.
	if _ground_drag:
		_update_ground_drag()
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_toward(cursor_point(), 1.0 / S.zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_toward(cursor_point(), S.zoom_step)
			MOUSE_BUTTON_MIDDLE:
				_orbiting = event.pressed
				if _orbiting:
					_orbit_point = cursor_point()
					_flying = false
	elif event is InputEventMouseMotion:
		if _orbiting:
			var dyaw: float = -event.relative.x * S.orbit_sensitivity
			target_pivot = _orbit_point + (target_pivot - _orbit_point).rotated(Vector3.UP, dyaw)
			target_yaw += dyaw
			target_pitch += event.relative.y * S.orbit_sensitivity
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			zoom_toward(_screen_center_point(), exp(event.relative.y * S.zoom_drag_sensitivity))


# --- API used by the hand ---

func begin_ground_drag(point: Vector3) -> void:
	_ground_drag = true
	_grab_point = point
	_flying = false


func end_ground_drag() -> void:
	_ground_drag = false


func is_ground_dragging() -> bool:
	return _ground_drag


func fly_to(point: Vector3, close: bool) -> void:
	_flying = true
	_fly_t = 0.0
	_fly_from_pivot = target_pivot
	_fly_to_pivot = point
	_fly_from_distance = target_distance
	_fly_to_distance = S.fly_distance_object if close else minf(target_distance, S.fly_distance_ground)


## Zoom by ratio while keeping `point` fixed on screen.
func zoom_toward(point: Vector3, ratio: float) -> void:
	var new_distance := clampf(target_distance * ratio, S.distance_min, S.distance_max)
	var r := new_distance / target_distance
	target_pivot = point + (target_pivot - point) * r
	target_distance = new_distance
	_flying = false


## The world point under the mouse cursor (falls back to street level).
func cursor_point() -> Vector3:
	return _point_under(get_viewport().get_mouse_position())


# --- Internals ---

func _keyboard(delta: float) -> void:
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
		var forward := Vector3(-sin(target_yaw), 0, -cos(target_yaw))
		var right := Vector3(cos(target_yaw), 0, -sin(target_yaw))
		target_pivot += (right * input.x - forward * input.y).normalized() * S.pan_key_speed * (target_distance / 100.0) * delta
		_flying = false

	if Input.is_key_pressed(KEY_Q):
		target_yaw += S.rotate_key_speed * delta
	if Input.is_key_pressed(KEY_E):
		target_yaw -= S.rotate_key_speed * delta
	if Input.is_key_pressed(KEY_R):
		target_pitch -= S.tilt_key_speed * delta
	if Input.is_key_pressed(KEY_F):
		target_pitch += S.tilt_key_speed * delta


func _update_fly(delta: float) -> void:
	_fly_t = minf(_fly_t + delta / S.fly_duration, 1.0)
	var e := smoothstep(0.0, 1.0, _fly_t)
	target_pivot = _fly_from_pivot.lerp(_fly_to_pivot, e)
	target_distance = lerpf(_fly_from_distance, _fly_to_distance, e)
	if _fly_t >= 1.0:
		_flying = false


func _update_ground_drag() -> void:
	var mouse := get_viewport().get_mouse_position()
	var hit = _ray_plane(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse), _grab_point.y)
	if hit == null:
		return
	var shift: Vector3 = _grab_point - hit
	shift.y = 0
	target_pivot += shift
	_clamp_targets()
	pivot.x = target_pivot.x
	pivot.z = target_pivot.z


func _clamp_targets() -> void:
	target_pitch = clampf(target_pitch, deg_to_rad(S.pitch_min_deg), deg_to_rad(S.pitch_max_deg))
	target_distance = clampf(target_distance, S.distance_min, S.distance_max)
	var limit: Vector2 = city.half_size + Vector2.ONE * S.bounds_margin
	target_pivot.x = clampf(target_pivot.x, -limit.x, limit.x)
	target_pivot.z = clampf(target_pivot.z, -limit.y, limit.y)
	target_pivot.y = clampf(target_pivot.y, 0.0, 300.0)


func _place_camera() -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var desired := pivot + dir * distance
	var space := get_world_3d().direct_space_state

	# Never pass through a building: pull in along the arm if something is in the way.
	var arm := PhysicsRayQueryParameters3D.create(pivot + Vector3.UP * 0.5, desired, LAYER_WORLD)
	var blocked := space.intersect_ray(arm)
	if blocked:
		desired = blocked.position + blocked.normal * 0.5

	# Stay clear of whatever is below, rooftops included.
	var down := PhysicsRayQueryParameters3D.create(desired + Vector3.UP * 500.0, desired - Vector3.UP * 500.0, LAYER_WORLD)
	var below := space.intersect_ray(down)
	if below:
		desired.y = maxf(desired.y, below.position.y + S.min_clearance)

	camera.global_position = desired
	if not desired.is_equal_approx(pivot):
		camera.look_at(pivot, Vector3.UP)


func _point_under(screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * RAY_LENGTH)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		return hit.position
	var ground = _ray_plane(from, dir, 0.0)
	return ground if ground != null else target_pivot


func _screen_center_point() -> Vector3:
	return _point_under(get_viewport().get_visible_rect().size / 2.0)


func _ray_plane(origin: Vector3, dir: Vector3, height: float):
	if dir.y > -0.001:
		return null
	return origin + dir * ((height - origin.y) / dir.y)
