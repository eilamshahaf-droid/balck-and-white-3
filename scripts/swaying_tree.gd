extends StaticBody3D
## A rooted tree. It bends away from the god's hand's wind, and the hand can
## grab it and pull: the tree resists, leans and shakes after the hand, and
## when the pull has gone on long enough it comes out by the roots, if the
## hand is strong enough here to lift it.

const UprootedTree = preload("res://scripts/uprooted_tree.gd")
const S = preload("res://data/hand_settings.tres")

const MAX_TILT := 0.5
const PULL_TILT := 0.45
const STIFFNESS := 30.0
const DAMPING := 5.0

var trunk_mat: Material
var crown_mat: Material
var crown_radius := 2.0

var _tilt := Vector2.ZERO       # x = lean toward +X, y = lean toward +Z
var _tilt_vel := Vector2.ZERO
var _push := Vector2.ZERO
var _phase := randf() * TAU
var _gripped := false
var _tension := 0.0


func build(p_trunk: Material, p_crown: Material, radius: float) -> void:
	trunk_mat = p_trunk
	crown_mat = p_crown
	crown_radius = radius
	add_to_group("wind_reactive")
	add_to_group("god_grabbable")
	set_meta("surface", &"wood")
	add_tree_shapes(self, radius)
	add_tree_visuals(self, p_trunk, p_crown, radius)


## Shared with the uprooted tree so both look and collide the same.
static func add_tree_visuals(parent: Node3D, p_trunk: Material, p_crown: Material, radius: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 3.0
	trunk.mesh = trunk_mesh
	trunk.material_override = p_trunk
	trunk.position.y = 1.5
	parent.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = radius
	crown_mesh.height = radius * 2.0
	crown.mesh = crown_mesh
	crown.material_override = p_crown
	crown.position.y = 4.0
	parent.add_child(crown)


static func add_tree_shapes(parent: Node3D, radius: float) -> void:
	var trunk := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 3.0
	trunk.shape = cyl
	trunk.position.y = 1.5
	parent.add_child(trunk)
	var crown := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	crown.shape = sphere
	crown.position.y = 4.0
	parent.add_child(crown)


func aim_point() -> Vector3:
	return global_position + Vector3.UP * 3.5


func on_hand_wind(hand: Node3D) -> void:
	if _gripped:
		return
	var s: float = hand.wind_strength(global_position + Vector3.UP * 3.0)
	if s <= 0.0:
		_push = Vector2.ZERO
		return
	var away := global_position - hand.global_position
	var dir: Vector2 = Vector2(away.x, away.z).normalized() + Vector2(hand.hand_velocity.x, hand.hand_velocity.z) * 0.03
	_push = dir.limit_length(1.0) * s * MAX_TILT


func on_grabbed() -> void:
	_gripped = true
	_tension = 0.0


func on_released(_v: Vector3) -> void:
	_gripped = false
	_tension = 0.0
	_push = Vector2.ZERO


## Called by the hand every physics frame while it grips this tree. Returns the
## loose tree once the roots give way, otherwise null.
## `strength` is how much mass the hand can lift here: too weak and the tree
## only leans and shudders; stronger than needed and it comes out faster.
func hand_pull(anchor: Vector3, hand_velocity: Vector3, strength: float, delta: float) -> Node3D:
	var pull := anchor - (global_position + Vector3.UP * 3.0)
	var stretch := maxf(pull.length() - S.uproot_slack, 0.0)
	var power := minf(strength / UprootedTree.MASS, 2.0) if strength >= UprootedTree.MASS else 0.0
	# Pulling far builds tension; wiggling the hand (as in the original) helps more.
	_tension += (stretch + hand_velocity.length() * S.uproot_speed_bonus) * S.hand_strength * power * delta
	var effort: float = S.uproot_effort * crown_radius / 2.0
	var lean := Vector2(pull.x, pull.z).limit_length(1.0)
	var strain := clampf(_tension / effort, 0.0, 1.0) if power > 0.0 else 0.6
	_push = lean * PULL_TILT * (0.4 + 0.6 * strain)
	_push += Vector2(randf() - 0.5, randf() - 0.5) * 0.08 * strain   # shudder
	if _tension >= effort:
		return _uproot()
	return null


func _uproot() -> Node3D:
	var loose: RigidBody3D = UprootedTree.new()
	loose.build(trunk_mat, crown_mat, crown_radius)
	loose.collision_layer = collision_layer
	loose.collision_mask = 1 | collision_layer
	get_parent().add_child(loose)
	loose.global_transform = global_transform
	loose.global_position += Vector3.UP * 0.3

	# Leave a hole of turned-up earth behind.
	var hole := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.9
	disk.bottom_radius = 0.9
	disk.height = 0.04
	hole.mesh = disk
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.28, 0.2, 0.13)
	hole.material_override = dirt
	get_parent().add_child(hole)
	hole.global_position = global_position + Vector3.UP * 0.32

	queue_free()
	return loose


func _physics_process(delta: float) -> void:
	_phase += delta
	var breeze := Vector2(sin(_phase * 0.9), cos(_phase * 0.7)) * 0.015
	var accel := (_push + breeze - _tilt) * STIFFNESS - _tilt_vel * DAMPING
	_tilt_vel += accel * delta
	_tilt += _tilt_vel * delta
	rotation = Vector3(_tilt.y, 0, -_tilt.x)
