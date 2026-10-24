extends Node3D
## The god's hand: follows the cursor over the city, picks up taxis and
## people with the left mouse button, and throws them on release.
## Anyone nearby who sees a person lifted by an invisible force reacts to it.

const HOVER_HEIGHT := 1.5
const HOLD_HEIGHT := 6.0
const RAY_LENGTH := 3000.0
const MAX_THROW_SPEED := 60.0
const WITNESS_RADIUS := 25.0

var held: Node3D = null
var _cursor := Vector3.ZERO
var _velocity := Vector3.ZERO


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _physics_process(delta: float) -> void:
	var hit := _raycast()
	if hit:
		_cursor = hit.position
	var goal := _cursor + Vector3.UP * (HOLD_HEIGHT if held else HOVER_HEIGHT)
	var new_pos := global_position.lerp(goal, clampf(delta * 20.0, 0.0, 1.0))
	_velocity = _velocity.lerp((new_pos - global_position) / delta, 0.3)
	global_position = new_pos

	if held:
		held.global_position = global_position - Vector3.UP
		if held is RigidBody3D:
			held.linear_velocity = Vector3.ZERO
			held.angular_velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_grab()
		else:
			_release()


func _grab() -> void:
	var hit := _raycast()
	if not hit or not hit.collider.is_in_group("god_grabbable"):
		return
	held = hit.collider
	if held is RigidBody3D:
		held.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		held.freeze = true
	elif held.has_method("on_grabbed"):
		held.on_grabbed()
		_notify_witnesses(held.global_position, held)


func _release() -> void:
	if not held:
		return
	var throw := _velocity.limit_length(MAX_THROW_SPEED)
	if held is RigidBody3D:
		held.freeze = false
		held.linear_velocity = throw
	elif held.has_method("on_released"):
		held.on_released(throw)
	held = null


func _notify_witnesses(where: Vector3, subject: Node) -> void:
	for c in get_tree().get_nodes_in_group("citizens"):
		if c != subject and c.global_position.distance_to(where) < WITNESS_RADIUS:
			c.react_to_miracle(0.1, 0.0)


func _raycast() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if held is CollisionObject3D:
		query.exclude = [held.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)
