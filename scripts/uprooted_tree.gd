extends RigidBody3D
## A tree pulled out by the roots. It can be thrown like any heavy object.
## Put down gently, with its roots still on, it takes root again where it lands.
## Throwing it or holding it too long makes the roots fall off for good.

const S = preload("res://data/hand_settings.tres")
const LAYER_WORLD := 1

var trunk_mat: Material
var crown_mat: Material
var crown_radius := 2.0
var roots_intact := true

var _roots: MeshInstance3D
var _held_time := 0.0


func build(p_trunk: Material, p_crown: Material, radius: float) -> void:
	var tree_script = load("res://scripts/swaying_tree.gd")
	trunk_mat = p_trunk
	crown_mat = p_crown
	crown_radius = radius
	add_to_group("god_grabbable")
	mass = 3.0
	tree_script.add_tree_shapes(self, radius)
	tree_script.add_tree_visuals(self, p_trunk, p_crown, radius)
	_roots = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.7
	ball.height = 1.0
	_roots.mesh = ball
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.3, 0.22, 0.15)
	_roots.material_override = dirt
	add_child(_roots)


func aim_point() -> Vector3:
	return to_global(Vector3.UP * 3.5)


func on_released(v: Vector3) -> void:
	if v.length() > S.place_max_speed:
		_lose_roots()
	elif roots_intact:
		_replant()


func _physics_process(delta: float) -> void:
	if gravity_scale == 0.0:   # in the hand
		_held_time += delta
		if _held_time > S.roots_hold_time:
			_lose_roots()
	else:
		_held_time = 0.0


func _lose_roots() -> void:
	if not roots_intact:
		return
	roots_intact = false
	_roots.queue_free()


func _replant() -> void:
	var from := global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 500.0, LAYER_WORLD)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit:
		return
	var tree: StaticBody3D = load("res://scripts/swaying_tree.gd").new()
	tree.build(trunk_mat, crown_mat, crown_radius)
	tree.collision_layer = collision_layer
	get_parent().add_child(tree)
	tree.global_position = hit.position
	queue_free()
