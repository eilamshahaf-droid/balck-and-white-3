extends Node3D
## The god's hand is the whole interface, as in Black & White.
##
## Left button on the ground or a roof: grab the city and drag it.
## Left button on a person or taxi: pick it up (drag, or hold past a tap).
## Release while still = put down; release while moving = throw.
## Short click without moving = tap. Double-click = fly the camera there.
## Left button held still = ask for a wheel (hand_tools.gd decides which:
## signs on a building, miracles anywhere else). While a wheel is open the
## hand stays at its centre and points where the mouse goes.
## Right button dragged: draw a gesture (a circle = water).
##
## Held things hang from the hand on a damped spring, so heavy things lag and
## swing. Throw speed is the hand's motion averaged over the last moments.
##
## Lifting and throwing are play, not miracles: anything can be lifted, and
## nobody's belief changes from seeing it. Belief comes only from miracles.

const S: HandSettings = preload("res://data/hand_settings.tres")
const Sfx = preload("res://scripts/sfx.gd")
const HandVisual = preload("res://scripts/hand_visual.gd")
const Gesture = preload("res://scripts/gesture.gd")

## The left button was held still on `hit` (a raycast result: position, collider).
signal long_pressed(hit: Dictionary, screen_pos: Vector2)
## A short click on `hit` while the hand carries a tool.
signal tool_clicked(hit: Dictionary)
## A circle was drawn with the right button (`screen_radius` in pixels).
signal circle_drawn(screen_pos: Vector2, screen_radius: float)
## Something was drawn with the right button that isn't a known gesture.
signal gesture_unrecognised
## A right click without drawing anything.
signal right_clicked
const RAY_LENGTH := 3000.0
const RIGID_GRAVITY := 9.8
const LAYER_WORLD := 1
const LAYER_CITIZENS := 2
const LAYER_PROPS := 4
const LAYER_CRITTERS := 8
## Extra reach of the wind query: a tree feels the wind at its crown, above its base.
const WIND_QUERY_MARGIN := 4.0
## Samples kept for throw speed: half a second at up to 120 physics ticks.
const HISTORY_SIZE := 64

enum Press { NONE, PENDING_GROUND, PENDING_OBJECT, DRAG_GROUND, HOLDING }

@onready var rig: Node3D = get_node("../CameraRig")

var held: Node3D = null
var hovered: Node3D = null
## Smoothed hand velocity; drives wind and throws.
var hand_velocity := Vector3.ZERO
## The building the hand is pointing at (kept solid by the camera).
var pointed_building: Node3D = null
## The hand carries a tool (a miracle): it can't pick anything up, and a short
## click uses the tool instead of tapping. Dragging still moves the city.
var carrying_tool := false

var _visual: Node3D
var _shadow: MeshInstance3D
var _shadow_mat := StandardMaterial3D.new()
var _arc_mesh := ImmediateMesh.new()
var _arc_mat := StandardMaterial3D.new()
var _outline_mat := StandardMaterial3D.new()
var _point_outline_mat := StandardMaterial3D.new()

var _press := Press.NONE
var _press_time := 0.0
var _press_pos := Vector2.ZERO
var _press_hit := {}
var _press_target: Node3D = null
var _surface := Vector3.ZERO
# Recent hand samples, oldest first, for throw velocity.
var _history_time := PackedFloat64Array()
var _history_pos := PackedVector3Array()
var _history_mouse := PackedVector2Array()
var _windy := {}           # wind_reactive nodes the wind reached last tick (used as a set)
var _pick_query := PhysicsShapeQueryParameters3D.new()
var _wind_query := PhysicsShapeQueryParameters3D.new()
var _tap_timer := 0.0
var _drawing := false
var _gesture := PackedVector2Array()
var _point_anchor := Vector3.INF   # while a wheel is open: where the hand stays
var _point_from := Vector2.ZERO     # the wheel's centre on screen
var _point_zoom := 1.0              # how much bigger the hand is drawn while pointing
var _trail: Line2D


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

	# The gesture being drawn, on screen.
	var layer := CanvasLayer.new()
	add_child(layer)
	_trail = Line2D.new()
	_trail.width = 6.0
	_trail.default_color = Color(0.7, 0.85, 1.0, 0.8)
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	layer.add_child(_trail)

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
	# A dark rim on the hand while it points at a wheel, so it reads on a white roof.
	_point_outline_mat.albedo_color = Color(0.15, 0.12, 0.2)
	_point_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_point_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_point_outline_mat.grow = true
	_point_outline_mat.grow_amount = 0.06

	# The pick and the wind only look at what is near the hand; the physics
	# engine already knows where everything is.
	_pick_query.shape = SphereShape3D.new()
	_pick_query.collision_mask = LAYER_CITIZENS | LAYER_PROPS
	_wind_query.shape = SphereShape3D.new()
	(_wind_query.shape as SphereShape3D).radius = S.wind_fade_radius + WIND_QUERY_MARGIN
	_wind_query.collision_mask = LAYER_PROPS | LAYER_CRITTERS
	_wind_query.collide_with_areas = true


func _physics_process(delta: float) -> void:
	var hit := _raycast_mouse()
	var first_wall := _raycast_mouse(LAYER_WORLD, false)
	pointed_building = first_wall.collider if first_wall and first_wall.collider.is_in_group("buildings") else null
	# While holding, ride over streets and buildings only: hopping onto every tree
	# crown or taxi roof under the cursor would jerk the held thing (and fling it).
	var surface_hit := _raycast_mouse(LAYER_WORLD) if held else hit
	if surface_hit:
		_surface = surface_hit.position
	_update_press()
	var target: Node3D = null
	if not held and not carrying_tool and _press != Press.DRAG_GROUND and _point_anchor == Vector3.INF:
		target = _pick_target(hit)

	# Sit on the mouse ray, a little in front of the surface, so the fingertip
	# is drawn exactly where the cursor points.
	var camera := get_viewport().get_camera_3d()
	var ray_dir := camera.project_ray_normal(get_viewport().get_mouse_position())
	var lift: float = S.hold_height if held else S.hover_height
	var goal := _surface - ray_dir * clampf(lift / maxf(-ray_dir.y, 0.15), 0.0, 25.0)
	if target and (not hit or hit.collider != target):
		# Lean gently toward a nearby target without jumping onto it.
		goal += (_aim_point(target) - _surface) * S.magnet_strength
	if _point_anchor != Vector3.INF:
		goal = _point_anchor
	global_position = global_position.lerp(goal, 1.0 - exp(-S.follow_rate * delta))
	rotation.y = rig.yaw - _point_angle()
	_update_point_zoom(delta)
	_record_history()
	hand_velocity = _throw_velocity() / S.throw_multiplier if S.throw_multiplier > 0.0 else Vector3.ZERO
	_blow()

	if held:
		if is_instance_valid(held):
			_pull_held(delta)
		else:
			held = null
			_press = Press.NONE
	_update_hover(target)
	_update_shadow()
	_update_arc()
	_update_pose(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_let_go()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drawing = false
			_trail.clear_points()
			_on_press(event)
		else:
			_on_release()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not held:
			_drawing = true
			_gesture = PackedVector2Array([event.position])
		elif not event.pressed and _drawing:
			_drawing = false
			_finish_gesture()
	elif event is InputEventMouseMotion and _drawing:
		if _gesture[-1].distance_to(event.position) > 4.0:
			_gesture.append(event.position)
		_trail.points = _gesture


# --- Pointing at a wheel ---

## Stay where the hand is and point from `screen_pos` toward the mouse.
func start_pointing(screen_pos: Vector2) -> void:
	_point_anchor = global_position
	_point_from = screen_pos
	# Seen from high up the hand is a speck; grow it to fill the wheel's hole.
	var px_per_m := _screen_radius(get_viewport().get_camera_3d(), global_position, 1.0)
	var hand_px := px_per_m * S.hand_scale * HandVisual.LENGTH
	_point_zoom = maxf(1.0, S.wheel_dead_zone_px * 1.3 / maxf(hand_px, 0.01))
	for mesh in _visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _point_outline_mat


func stop_pointing() -> void:
	_point_anchor = Vector3.INF
	_point_zoom = 1.0
	for mesh in _visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = null


## Grow or shrink the drawn hand. While pointing, its middle (not its
## fingertip) sits on the wheel's centre, so the finger reaches out to a slice.
func _update_point_zoom(delta: float) -> void:
	var w := 1.0 - exp(-12.0 * delta)
	var size: float = lerpf(_visual.scale.x, S.hand_scale * _point_zoom, w)
	var offset := HandVisual.FINGERTIP_OFFSET
	if _point_anchor != Vector3.INF:
		offset.z -= HandVisual.LENGTH * 0.5
	_visual.scale = Vector3.ONE * size
	_visual.position = _visual.position.lerp(offset * size, w)


## Clockwise screen angle from straight up to the mouse, while pointing at a wheel.
func _point_angle() -> float:
	if _point_anchor == Vector3.INF:
		return 0.0
	var d := get_viewport().get_mouse_position() - _point_from
	return atan2(d.x, -d.y) if d.length() > S.wheel_dead_zone_px else 0.0


# --- Right button: gestures ---

func _finish_gesture() -> void:
	var points := _gesture
	var tween := create_tween()
	tween.tween_property(_trail, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _trail.clear_points(); _trail.modulate.a = 1.0)
	if Gesture.is_circle(points):
		circle_drawn.emit(Gesture.centroid(points), Gesture.radius(points))
	elif points.size() > 8:
		gesture_unrecognised.emit()
	elif points.size() <= 2:
		right_clicked.emit()


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
	_press_target = null if carrying_tool else _pick_target(hit)
	# Over empty sky the city can still be grabbed: the grip goes on the street plane.
	_press = Press.PENDING_OBJECT if _press_target else Press.PENDING_GROUND


func _on_release() -> void:
	match _press:
		Press.PENDING_OBJECT:
			_tap(_press_target)
		Press.PENDING_GROUND:
			if _time() - _press_time <= S.tap_max_time and not _press_hit.is_empty():
				if carrying_tool:
					tool_clicked.emit(_press_hit)
				else:
					_knock(_press_hit.position, Sfx.surface_of(_press_hit.collider))
		Press.DRAG_GROUND:
			rig.end_ground_drag()
		Press.HOLDING:
			_release()
	_press = Press.NONE


## The window lost focus: the button-up will never arrive, so finish whatever
## the press was doing. A held thing is put down, not thrown.
func _let_go() -> void:
	match _press:
		Press.DRAG_GROUND:
			rig.end_ground_drag()
		Press.HOLDING:
			_release(false)
	_press = Press.NONE
	_drawing = false
	_trail.clear_points()


func _update_press() -> void:
	if _press != Press.PENDING_GROUND and _press != Press.PENDING_OBJECT:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_press = Press.NONE  # both buttons = camera zoom
		return
	var moved := get_viewport().get_mouse_position().distance_to(_press_pos) > S.drag_threshold_px
	var long := _time() - _press_time > S.tap_max_time
	if _press == Press.PENDING_OBJECT and (moved or long):
		if is_instance_valid(_press_target):
			_grab(_press_target)
		else:
			_press = Press.NONE
	elif _press == Press.PENDING_GROUND and moved:
		rig.begin_ground_drag(_press_pos)
		_press = Press.DRAG_GROUND
	elif _press == Press.PENDING_GROUND and _time() - _press_time > S.wheel_hold_time and not _press_hit.is_empty():
		# Holding still: the hand rests on the spot and asks what to do there.
		_press = Press.NONE
		long_pressed.emit(_press_hit, _press_pos)


# --- Holding and throwing ---

func _grab(obj: Node3D) -> void:
	held = obj
	_press = Press.HOLDING
	Sfx.play(get_tree(), obj.global_position, Sfx.surface_of(obj), 0.5)
	if held is RigidBody3D:
		_hold_rigid(held)
	if held.has_method("on_grabbed"):
		held.on_grabbed()


func _hold_rigid(body: RigidBody3D) -> void:
	body.gravity_scale = 0.0
	body.angular_damp = 6.0
	body.sleeping = false


func _pull_held(delta: float) -> void:
	var anchor := global_position - Vector3.UP * 1.2
	if held.has_method("hand_pull"):
		# Rooted things (trees) resist; when they give way they hand back the loose object.
		var loose: Node3D = held.hand_pull(anchor, hand_velocity, delta)
		if loose and loose != held:
			held = loose
			if held is RigidBody3D:
				_hold_rigid(held)
			if held.has_method("on_grabbed"):
				held.on_grabbed()
			Sfx.play(get_tree(), held.global_position, &"earth", 1.0)
		return
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


func _release(allow_throw := true) -> void:
	if not held:
		return
	var v := _throw_velocity() if allow_throw else Vector3.ZERO
	# Intent comes from the mouse: a mouse at rest means "put it down", whatever the hand did.
	if v.length() < S.place_max_speed or _mouse_speed() < S.place_max_mouse_speed:
		v = Vector3.ZERO
	if held is RigidBody3D:
		held.gravity_scale = 1.0
		held.angular_damp = 0.0
		held.linear_velocity = v
	if held.has_method("on_released"):
		held.on_released(v)
	held = null


func _throw_velocity() -> Vector3:
	var oldest := _throw_window_start()
	if oldest < 0:
		return Vector3.ZERO
	var last := _history_time.size() - 1
	var dt := _history_time[last] - _history_time[oldest]
	var v := (_history_pos[last] - _history_pos[oldest]) / dt * S.throw_multiplier
	return v.limit_length(S.throw_max_speed)


func _record_history() -> void:
	var now := _time()
	if _history_time.size() >= HISTORY_SIZE:
		_drop_oldest_sample()
	_history_time.append(now)
	_history_pos.append(global_position)
	_history_mouse.append(get_viewport().get_mouse_position())
	while _history_time.size() > 2 and now - _history_time[0] > 0.5:
		_drop_oldest_sample()


func _drop_oldest_sample() -> void:
	_history_time.remove_at(0)
	_history_pos.remove_at(0)
	_history_mouse.remove_at(0)


## Index of the sample one throw window before the newest, or -1 if there is
## no time span to measure over.
func _throw_window_start() -> int:
	var last := _history_time.size() - 1
	if last < 1:
		return -1
	var i := last - 1
	while i > 0 and _history_time[last] - _history_time[i] < S.throw_window:
		i -= 1
	return i if _history_time[last] > _history_time[i] else -1


## Mouse speed in pixels per second over the throw window.
func _mouse_speed() -> float:
	var oldest := _throw_window_start()
	if oldest < 0:
		return 0.0
	var last := _history_time.size() - 1
	return _history_mouse[last].distance_to(_history_mouse[oldest]) / (_history_time[last] - _history_time[oldest])


func _tap(obj: Node3D) -> void:
	_tap_timer = 0.25
	if not is_instance_valid(obj):
		return
	Sfx.play(get_tree(), obj.global_position, Sfx.surface_of(obj), 0.6)
	if obj is RigidBody3D:
		var away := obj.global_position - global_position
		away.y = 0
		obj.apply_central_impulse((away.normalized() * 0.5 + Vector3.UP * 0.6) * S.tap_impulse * obj.mass)
	if obj.has_method("on_tapped"):
		obj.on_tapped(global_position)


## A tap on a wall or the street: the nearest door swings open and people nearby look.
func _knock(where: Vector3, surface: StringName) -> void:
	_tap_timer = 0.25
	Sfx.play(get_tree(), where, surface, 0.8)
	var best: Node3D = null
	for door in get_tree().get_nodes_in_group("doors"):
		var d: float = door.global_position.distance_to(where)
		if d < S.knock_radius and (best == null or d < best.global_position.distance_to(where)):
			best = door
	if best:
		best.knock()
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.global_position.distance_to(where) < S.notice_radius:
			c.notice(where)


## Tell everything within the wind's reach about it, plus whatever it reached
## last tick, so things that just fell out of reach can settle.
func _blow() -> void:
	_wind_query.transform = Transform3D(Basis.IDENTITY, global_position)
	var reached := {}
	for near in get_world_3d().direct_space_state.intersect_shape(_wind_query, 128):
		var node: Node = near.collider
		if node.is_in_group("wind_reactive"):
			reached[node] = true
	for node: Node in _windy:
		if is_instance_valid(node) and not reached.has(node):
			node.on_hand_wind(self)
	for node: Node in reached:
		node.on_hand_wind(self)
	_windy = reached


## How strongly the hand's wind reaches `p`: full and sharpening inside the
## inner radius, fading smoothly to zero at the outer one; a moving hand blows harder.
func wind_strength(p: Vector3) -> float:
	var d := global_position.distance_to(p)
	var s := 0.0
	if d < S.wind_full_radius:
		s = 0.5 + 0.5 * pow(1.0 - d / S.wind_full_radius, 2.0)
	elif d < S.wind_fade_radius:
		s = 0.5 * (1.0 - smoothstep(S.wind_full_radius, S.wind_fade_radius, d))
	var motion := clampf(hand_velocity.length() / S.wind_speed_full, 0.0, 1.0)
	return s * lerpf(S.wind_idle, 1.0, motion)


# --- Feedback: hover outline, shadow, throw arc, pose ---

## What the hand is reaching for. One rule for everything grabbable, with no
## per-object code: the whole drawn hand is the grab area, and each object
## counts by its real size on screen, so a big tree is as easy to catch as it
## looks and a far-away person still gets a fair margin.
func _pick_target(hit: Dictionary) -> Node3D:
	if hit and _is_grabbable(hit.collider):
		return hit.collider
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var reach := maxf(S.pick_assist_px, _screen_radius(camera, global_position, S.hand_scale)) * S.grab_reach
	var px_per_m := _screen_radius(camera, global_position, 1.0)
	var best: Node3D = null
	var best_score := reach
	# Only things near the hand in the world can be under it on screen.
	(_pick_query.shape as SphereShape3D).radius = reach / maxf(px_per_m, 0.01) * 2.0 + 2.0
	_pick_query.transform = Transform3D(Basis.IDENTITY, global_position)
	var seen := {}
	for near in get_world_3d().direct_space_state.intersect_shape(_pick_query, 64):
		var obj: Node3D = near.collider
		if seen.has(obj) or not _is_grabbable(obj):
			continue
		seen[obj] = true
		var bounds := _pick_bounds(obj)
		var center: Vector3 = obj.global_transform * bounds.position
		var radius: float = bounds.size.x
		if camera.is_position_behind(center):
			continue
		# Size helps only up to the hand's own reach, so a big tree crown can't
		# swallow the people standing under it.
		var score := camera.unproject_position(center).distance_to(mouse) - minf(_screen_radius(camera, center, radius), reach)
		if score < best_score:
			best = obj
			best_score = score
	if best:
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, _aim_point(best), LAYER_WORLD)
		query.exclude = rig.faded_rids()
		if get_world_3d().direct_space_state.intersect_ray(query):
			return null  # hidden behind a building
	return best


## An object's grab sphere, measured once from its meshes: position = centre in
## the object's own space, size.x = radius.
func _pick_bounds(obj: Node3D) -> AABB:
	if obj.has_meta("pick_bounds"):
		return obj.get_meta("pick_bounds")
	var to_local := obj.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mesh in obj.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (to_local * mesh.global_transform) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var bounds := AABB(box.get_center(), Vector3.ONE * box.size.length() * 0.3)
	obj.set_meta("pick_bounds", bounds)
	return bounds


func _screen_radius(camera: Camera3D, at: Vector3, world_radius: float) -> float:
	if camera.is_position_behind(at):
		return 0.0
	var edge := at + camera.global_transform.basis.x * world_radius
	return camera.unproject_position(edge).distance_to(camera.unproject_position(at))


func _aim_point(obj: Node3D) -> Vector3:
	return obj.global_transform * _pick_bounds(obj).position


func _update_hover(h: Node3D) -> void:
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
	if not (held is RigidBody3D or held is Citizen):
		return  # rooted things don't fly
	var g: float = RIGID_GRAVITY if held is RigidBody3D else (held as Citizen).fall_gravity
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
	elif hovered or _point_anchor != Vector3.INF:
		_visual.set_pose(HandVisual.Pose.POINT)
	else:
		_visual.set_pose(HandVisual.Pose.OPEN)


# --- Helpers ---

func _is_grabbable(obj: Object) -> bool:
	return obj != null and obj is Node and obj.is_in_group("god_grabbable")


func _mass(obj: Node3D) -> float:
	if obj is RigidBody3D:
		return (obj as RigidBody3D).mass
	if obj is Citizen:
		return (obj as Citizen).mass
	if obj is SwayingTree:
		return (obj as SwayingTree).mass
	return 1.0


func _time() -> float:
	return Time.get_ticks_msec() / 1000.0


func _raycast_mouse(mask := 0xFFFFFFFF, through_faded := true) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(mouse) * RAY_LENGTH, mask)
	# See-through buildings don't block the hand.
	var exclude: Array[RID] = []
	if through_faded:
		exclude = rig.faded_rids()
	if held is CollisionObject3D:
		exclude.append(held.get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query)
