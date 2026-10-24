extends Node3D
## The god's hand is the whole interface, as in Black & White.
##
## Left button on the ground or a roof: grab the city and drag it.
## Left button on a person or taxi: pick it up (drag, or hold past a tap).
## Release while still = put down; release while moving = throw.
## Short click without moving = tap. Double-click = fly the camera there.
##
## Held things hang from the hand on a damped spring, so heavy things lag and
## swing. Throw speed is the hand's motion averaged over the last moments.

const S = preload("res://data/hand_settings.tres")
const HandVisual = preload("res://scripts/hand_visual.gd")
const RAY_LENGTH := 3000.0
const RIGID_GRAVITY := 9.8
const LAYER_WORLD := 1
const LAYER_PROPS := 4

enum Press { NONE, PENDING_GROUND, PENDING_OBJECT, DRAG_GROUND, HOLDING }

@onready var rig: Node3D = get_node("../CameraRig")

var held: Node3D = null
var hovered: Node3D = null

var _visual: Node3D
var _shadow: MeshInstance3D
var _shadow_mat := StandardMaterial3D.new()
var _arc_mesh := ImmediateMesh.new()
var _arc_mat := StandardMaterial3D.new()
var _outline_mat := StandardMaterial3D.new()

var _press := Press.NONE
var _press_time := 0.0
var _press_pos := Vector2.ZERO
var _press_hit := {}
var _surface := Vector3.ZERO
var _history: Array = []   # [time, position] samples, for throw velocity
var _tap_timer := 0.0


func _ready() -> void:
	# The hand replaces the mouse cursor; its index fingertip is the hotspot.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_visual = HandVisual.new()
	_visual.scale = Vector3.ONE * S.hand_scale
	_visual.position = HandVisual.FINGERTIP_OFFSET * S.hand_scale
	add_child(_visual)

	# Soft round shadow under the hand: the main depth cue.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.7))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_shadow_mat.albedo_texture = tex
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var plane := PlaneMesh.new()
	plane.size = Vector2(3, 3)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = plane
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)

	_arc_mat.albedo_color = Color(1, 1, 1, 0.6)
	_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arc := MeshInstance3D.new()
	arc.mesh = _arc_mesh
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc.top_level = true
	add_child(arc)

	_outline_mat.albedo_color = Color(1.0, 0.9, 0.5)
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_mat.grow = true
	_outline_mat.grow_amount = 0.08


func _physics_process(delta: float) -> void:
	var hit := _raycast_mouse()
	if hit:
		_surface = hit.position
	_update_press()

	# Sit on the mouse ray, a little in front of the surface, so the fingertip
	# is drawn exactly where the cursor points.
	var camera := get_viewport().get_camera_3d()
	var ray_dir := camera.project_ray_normal(get_viewport().get_mouse_position())
	var lift: float = S.hold_height if held else S.hover_height
	var goal := _surface - ray_dir * clampf(lift / maxf(-ray_dir.y, 0.15), 0.0, 25.0)
	global_position = global_position.lerp(goal, 1.0 - exp(-S.follow_rate * delta))
	rotation.y = rig.yaw
	_record_history()

	if held:
		if is_instance_valid(held):
			_pull_held(delta)
		else:
			held = null
			_press = Press.NONE
	_update_hover(hit)
	_update_shadow()
	_update_arc()
	_update_pose(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event)
		else:
			_on_release()


# --- Press handling: drag the city, pick up, tap, or fly ---

func _on_press(event: InputEventMouseButton) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	var hit := _raycast_mouse()
	if event.double_click:
		_press = Press.NONE
		if hit:
			rig.fly_to(hit.position, _is_grabbable(hit.collider))
		return
	_press_time = _time()
	_press_pos = event.position
	_press_hit = hit
	if hit.is_empty():
		_press = Press.NONE
	elif _is_grabbable(hit.collider):
		_press = Press.PENDING_OBJECT
	else:
		_press = Press.PENDING_GROUND


func _on_release() -> void:
	match _press:
		Press.PENDING_OBJECT:
			_tap(_press_hit.collider)
		Press.DRAG_GROUND:
			rig.end_ground_drag()
		Press.HOLDING:
			_release()
	_press = Press.NONE


func _update_press() -> void:
	if _press != Press.PENDING_GROUND and _press != Press.PENDING_OBJECT:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_press = Press.NONE  # both buttons = camera zoom
		return
	var moved := get_viewport().get_mouse_position().distance_to(_press_pos) > S.drag_threshold_px
	var long := _time() - _press_time > S.tap_max_time
	if _press == Press.PENDING_OBJECT and (moved or long):
		if is_instance_valid(_press_hit.collider):
			_grab(_press_hit.collider)
		else:
			_press = Press.NONE
	elif _press == Press.PENDING_GROUND and moved:
		rig.begin_ground_drag(_press_hit.position)
		_press = Press.DRAG_GROUND


# --- Holding and throwing ---

func _grab(obj: Node3D) -> void:
	held = obj
	_press = Press.HOLDING
	if held is RigidBody3D:
		held.gravity_scale = 0.0
		held.angular_damp = 6.0
		held.sleeping = false
	elif held.has_method("on_grabbed"):
		held.on_grabbed()
		_notify_witnesses(held.global_position, held)


func _pull_held(delta: float) -> void:
	var anchor := global_position - Vector3.UP * 1.2
	var to_anchor := anchor - held.global_position
	if to_anchor.length() > 40.0:
		held.global_position = anchor  # stuck behind something; don't stretch forever
		to_anchor = Vector3.ZERO
	var m := _mass(held)
	var k: float = S.spring_stiffness
	var c := 2.0 * S.spring_damping * sqrt(k * m)
	if held is RigidBody3D:
		held.apply_central_force(k * to_anchor - c * held.linear_velocity)
	else:
		held.velocity += (k * to_anchor - c * held.velocity) / m * delta


func _release() -> void:
	if not held:
		return
	var v := _throw_velocity()
	if v.length() < S.place_max_speed:
		v = Vector3.ZERO
	if held is RigidBody3D:
		held.gravity_scale = 1.0
		held.angular_damp = 0.0
		held.linear_velocity = v
	elif held.has_method("on_released"):
		held.on_released(v)
	held = null


func _throw_velocity() -> Vector3:
	if _history.size() < 2:
		return Vector3.ZERO
	var newest: Array = _history[-1]
	var oldest: Array = _history[0]
	for i in range(_history.size() - 1, -1, -1):
		oldest = _history[i]
		if newest[0] - oldest[0] >= S.throw_window:
			break
	var dt: float = newest[0] - oldest[0]
	if dt <= 0.0:
		return Vector3.ZERO
	var v: Vector3 = (newest[1] - oldest[1]) / dt * S.throw_multiplier
	return v.limit_length(S.throw_max_speed)


func _record_history() -> void:
	var now := _time()
	_history.append([now, global_position])
	while _history.size() > 2 and now - _history[0][0] > 0.5:
		_history.pop_front()


func _tap(obj: Node3D) -> void:
	_tap_timer = 0.25
	if not is_instance_valid(obj):
		return
	if obj is RigidBody3D:
		var away := obj.global_position - global_position
		away.y = 0
		obj.apply_central_impulse((away.normalized() * 0.5 + Vector3.UP * 0.6) * S.tap_impulse * obj.mass)
	elif obj.has_method("on_tapped"):
		obj.on_tapped(global_position)


# --- Feedback: hover outline, shadow, throw arc, pose ---

func _update_hover(hit: Dictionary) -> void:
	var h: Node3D = null
	if not held and _press != Press.DRAG_GROUND and hit and _is_grabbable(hit.collider):
		h = hit.collider
	if h == hovered:
		return
	if hovered and is_instance_valid(hovered):
		_set_outline(hovered, false)
	hovered = h
	if hovered:
		_set_outline(hovered, true)


func _set_outline(node: Node, on: bool) -> void:
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _outline_mat if on else null


func _update_shadow() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position - Vector3.UP * 500.0, LAYER_WORLD | LAYER_PROPS)
	if held is CollisionObject3D:
		query.exclude = [held.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit:
		_shadow.visible = false
		return
	_shadow.visible = true
	var height: float = global_position.y - hit.position.y
	_shadow.global_position = hit.position + Vector3.UP * 0.05
	_shadow.scale = Vector3.ONE * clampf(0.8 + height * 0.08, 0.8, 3.0)
	_shadow_mat.albedo_color.a = clampf(1.0 - height / 25.0, 0.25, 1.0)


func _update_arc() -> void:
	_arc_mesh.clear_surfaces()
	if not held or not S.show_arc:
		return
	var v := _throw_velocity()
	if v.length() < S.arc_min_speed:
		return
	var g: float = RIGID_GRAVITY if held is RigidBody3D else held.fall_gravity
	var space := get_world_3d().direct_space_state
	var p: Vector3 = held.global_position
	var step := 0.05
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _arc_mat)
	for i in 80:
		var next := p + v * step
		v.y -= g * step
		var query := PhysicsRayQueryParameters3D.create(p, next, LAYER_WORLD)
		var hit := space.intersect_ray(query)
		if hit:
			next = hit.position
		if i % 2 == 0 or hit:
			_arc_mesh.surface_add_vertex(p)
			_arc_mesh.surface_add_vertex(next)
		if hit:
			break
		p = next
	_arc_mesh.surface_end()


func _update_pose(delta: float) -> void:
	_tap_timer -= delta
	if _tap_timer > 0.0:
		_visual.set_pose(HandVisual.Pose.TAP)
	elif held or _press == Press.DRAG_GROUND:
		_visual.set_pose(HandVisual.Pose.GRAB)
	elif hovered:
		_visual.set_pose(HandVisual.Pose.POINT)
	else:
		_visual.set_pose(HandVisual.Pose.OPEN)


# --- Helpers ---

func _notify_witnesses(where: Vector3, subject: Node) -> void:
	for c in get_tree().get_nodes_in_group("citizens"):
		if c != subject and c.global_position.distance_to(where) < 25.0:
			c.react_to_miracle(0.1, 0.0)


func _is_grabbable(obj: Object) -> bool:
	return obj != null and obj is Node and obj.is_in_group("god_grabbable")


func _mass(obj: Node3D) -> float:
	if obj is RigidBody3D:
		return obj.mass
	var m = obj.get("mass")
	return m if m != null else 1.0


func _time() -> float:
	return Time.get_ticks_msec() / 1000.0


func _raycast_mouse() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(mouse) * RAY_LENGTH)
	if held is CollisionObject3D:
		query.exclude = [held.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)
