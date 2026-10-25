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
##
## The hand is as strong as the believers around it (see faith.gd). Anything
## can still be lifted, but past the local strength it is an effort: the thing
## sags and lags unless the hand heaves, it burns belief from the pool, and it
## draws more attention. Everything the hand does in plain sight is reported
## to the witnesses.

const S = preload("res://data/hand_settings.tres")
const B = preload("res://data/balance.tres")
const Sfx = preload("res://scripts/sfx.gd")
const HandVisual = preload("res://scripts/hand_visual.gd")
const RAY_LENGTH := 3000.0
const RIGID_GRAVITY := 9.8
const LAYER_WORLD := 1
const LAYER_PROPS := 4

enum Press { NONE, PENDING_GROUND, PENDING_OBJECT, DRAG_GROUND, HOLDING }

@onready var rig: Node3D = get_node("../CameraRig")
@onready var faith: Node = get_node("../Faith")

var held: Node3D = null
var hovered: Node3D = null
## Smoothed hand velocity; drives wind and throws.
var hand_velocity := Vector3.ZERO
## The building the hand is pointing at (kept solid by the camera).
var pointed_building: Node3D = null
## How much mass the hand can lift where it is now.
var strength_here := 1.0
## 0..1: how well the held thing follows the hand (1 = within the local strength).
var grip := 1.0

var _visual: Node3D
var _shadow: MeshInstance3D
var _shadow_mat := StandardMaterial3D.new()
var _arc_mesh := ImmediateMesh.new()
var _arc_mat := StandardMaterial3D.new()
var _outline_mat := StandardMaterial3D.new()
var _ring: MeshInstance3D
var _ring_mat := StandardMaterial3D.new()
var _power := 0.0

var _press := Press.NONE
var _press_time := 0.0
var _press_pos := Vector2.ZERO
var _press_hit := {}
var _press_target: Node3D = null
var _surface := Vector3.ZERO
var _history: Array = []   # [time, position, mouse] samples, for throw velocity
var _tap_timer := 0.0
var _strength_timer := 0.0


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

	# A ring of light on the ground under the hand, like the influence ring of
	# the original: wide and warm among believers, small and grey elsewhere.
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	add_child(_ring)

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
	var first_wall := _raycast_mouse(LAYER_WORLD, false)
	pointed_building = first_wall.collider if first_wall and first_wall.collider.is_in_group("buildings") else null
	# While holding, ride over streets and buildings only: hopping onto every tree
	# crown or taxi roof under the cursor would jerk the held thing (and fling it).
	var surface_hit := _raycast_mouse(LAYER_WORLD) if held else hit
	if surface_hit:
		_surface = surface_hit.position
	_update_press()
	var target: Node3D = null
	if not held and _press != Press.DRAG_GROUND:
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
	global_position = global_position.lerp(goal, 1.0 - exp(-S.follow_rate * delta))
	rotation.y = rig.yaw
	_record_history()
	hand_velocity = _throw_velocity() / S.throw_multiplier if S.throw_multiplier > 0.0 else Vector3.ZERO
	get_tree().call_group("wind_reactive", "on_hand_wind", self)

	_strength_timer -= delta
	if _strength_timer <= 0.0:
		_strength_timer = 0.25
		strength_here = faith.strength_at(_surface)
		_power = clampf((strength_here - B.base_strength) / 5.0, 0.0, 1.0)
		_visual.set_power(_power)
	if held:
		if is_instance_valid(held):
			_report_held()
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
	_press_target = _pick_target(hit)
	# Over empty sky the city can still be grabbed: the grip goes on the street plane.
	_press = Press.PENDING_OBJECT if _press_target else Press.PENDING_GROUND


func _on_release() -> void:
	match _press:
		Press.PENDING_OBJECT:
			_tap(_press_target)
		Press.PENDING_GROUND:
			if _time() - _press_time <= S.tap_max_time and not _press_hit.is_empty():
				_knock(_press_hit.position, Sfx.surface_of(_press_hit.collider))
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
		if is_instance_valid(_press_target):
			_grab(_press_target)
		else:
			_press = Press.NONE
	elif _press == Press.PENDING_GROUND and moved:
		rig.begin_ground_drag(_press_pos)
		_press = Press.DRAG_GROUND


# --- Holding and throwing ---

func _grab(obj: Node3D) -> void:
	strength_here = faith.strength_at(obj.global_position)
	if _mass(obj) > strength_here and faith.belief_pool <= 0.0:
		_strain(obj)  # too heavy here, and no belief left to force it
		return
	grip = 1.0
	held = obj
	_press = Press.HOLDING
	Sfx.play(get_tree(), obj.global_position, Sfx.surface_of(obj), 0.5)
	if held is RigidBody3D:
		_hold_rigid(held)
	if held.has_method("on_grabbed"):
		held.on_grabbed()


## Too heavy for the hand here and nothing left to pay with: it trembles and the thing only shudders.
func _strain(obj: Node3D) -> void:
	_press = Press.NONE
	_visual.strain()
	Sfx.play(get_tree(), obj.global_position, &"strain", 0.8)
	if obj is RigidBody3D:
		obj.apply_central_impulse(Vector3.UP * obj.mass * 0.8)


## Tell the witnesses what the hand is doing in plain sight.
func _report_held() -> void:
	if held.has_method("hand_pull"):
		return  # a tree straining in the hand looks like the wind
	if held.is_in_group("citizens"):
		faith.report(held, &"see_lift", B.lift_intensity, B.spectacle_situation, 0.5, false)
	else:
		faith.report(held, &"see_float", _float_intensity(held), B.spectacle_situation, 0.5, false)


func _float_intensity(obj: Node3D) -> float:
	# A cab floating where the god has no believers is far more remarkable.
	var overload := maxf(_mass(obj) - strength_here, 0.0) / _mass(obj)
	return B.float_intensity * clampf(_mass(obj) / 2.0, 0.2, 1.5) * (1.0 + B.overload_exposure * overload)


## Past the local strength the hand pays belief to keep hold. Returns false
## when the pool runs dry and the hand has to let go.
func _pay_for_weight(delta: float) -> bool:
	var excess := _mass(held) - strength_here
	if excess <= 0.0:
		grip = 1.0
		return true
	var heave := hand_velocity.length() * B.overload_wiggle
	grip = clampf(strength_here / _mass(held) + heave, B.overload_min_grip, 1.0)
	return faith.spend(excess * B.overload_cost * delta)


func _hold_rigid(body: RigidBody3D) -> void:
	body.gravity_scale = 0.0
	body.angular_damp = 6.0
	body.sleeping = false


func _pull_held(delta: float) -> void:
	if not _pay_for_weight(delta):
		var dropped := held
		_release()
		_press = Press.NONE
		_strain(dropped)
		return
	var anchor := global_position - Vector3.UP * 1.2
	if held.has_method("hand_pull"):
		# Rooted things (trees) resist; when they give way they hand back the loose object.
		var loose: Node3D = held.hand_pull(anchor, hand_velocity, strength_here, delta)
		if loose and loose != held:
			held = loose
			if held is RigidBody3D:
				_hold_rigid(held)
			if held.has_method("on_grabbed"):
				held.on_grabbed()
			Sfx.play(get_tree(), held.global_position, &"earth", 1.0)
			faith.report(held, &"see_uproot", B.uproot_intensity, B.spectacle_situation, 2.0)
		return
	var to_anchor := anchor - held.global_position
	if to_anchor.length() > 40.0:
		held.global_position = anchor  # stuck behind something; don't stretch forever
		to_anchor = Vector3.ZERO
	# Too heavy for this spot: a weaker spring and some of its weight left on,
	# so it sags below the hand and swings slowly.
	var m := _mass(held)
	var k: float = S.spring_stiffness * grip
	var c := 2.0 * S.spring_damping * sqrt(k * m)
	if held is RigidBody3D:
		held.gravity_scale = 1.0 - grip
		held.apply_central_force(k * to_anchor - c * held.linear_velocity)
	else:
		held.velocity += (k * to_anchor - c * held.velocity) / m * delta
		held.velocity.y -= RIGID_GRAVITY * (1.0 - grip) * delta


func _release() -> void:
	if not held:
		return
	var v := _throw_velocity()
	# Intent comes from the mouse: a mouse at rest means "put it down", whatever the hand did.
	if v.length() < S.place_max_speed or _mouse_speed() < S.place_max_mouse_speed:
		v = Vector3.ZERO
	if held is RigidBody3D:
		held.gravity_scale = 1.0
		held.angular_damp = 0.0
		held.linear_velocity = v
	if held.has_method("on_released"):
		held.on_released(v)
	if v == Vector3.ZERO:
		faith.end_report(held)
	elif held.is_in_group("citizens"):
		faith.report(held, &"see_throw", B.throw_intensity, B.thrown_situation, B.flight_report_time)
	elif not held.has_method("hand_pull"):
		faith.report(held, &"see_float", _float_intensity(held), B.spectacle_situation, B.flight_report_time)
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
	_history.append([now, global_position, get_viewport().get_mouse_position()])
	while _history.size() > 2 and now - _history[0][0] > 0.5:
		_history.pop_front()


## Mouse speed in pixels per second over the throw window.
func _mouse_speed() -> float:
	if _history.size() < 2:
		return 0.0
	var newest: Array = _history[-1]
	var oldest: Array = _history[0]
	for i in range(_history.size() - 1, -1, -1):
		oldest = _history[i]
		if newest[0] - oldest[0] >= S.throw_window:
			break
	var dt: float = newest[0] - oldest[0]
	return newest[2].distance_to(oldest[2]) / dt if dt > 0.0 else 0.0


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
	for obj in get_tree().get_nodes_in_group("god_grabbable"):
		var bounds := _pick_bounds(obj)
		var center: Vector3 = obj.global_transform * bounds.position
		var radius: float = bounds.size.x
		# Cheap cull: nowhere near the hand in the world.
		if center.distance_to(global_position) > radius + reach / maxf(px_per_m, 0.01) * 2.0 + 2.0:
			continue
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
		_ring.visible = false
		return
	_shadow.visible = true
	_ring.visible = true
	_ring.global_position = hit.position + Vector3.UP * 0.08
	_ring.scale = Vector3(1.0, 0.05, 1.0) * lerpf(1.5, 5.0, _power)
	var weak := Color(0.7, 0.75, 0.85, 0.25)
	var strong := Color(1.0, 0.8, 0.4, 0.7)
	_ring_mat.albedo_color = weak.lerp(strong, _power)
	if held and grip < 1.0:
		_ring_mat.albedo_color = Color(1.0, 0.35, 0.25, 0.7)  # overloaded: paying belief
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
	if not (held is RigidBody3D) and held.get("fall_gravity") == null:
		return  # rooted things don't fly
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

func _is_grabbable(obj: Object) -> bool:
	return obj != null and obj is Node and obj.is_in_group("god_grabbable")


func _mass(obj: Node3D) -> float:
	if obj is RigidBody3D:
		return obj.mass
	var m = obj.get("mass")
	return m if m != null else 1.0


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
