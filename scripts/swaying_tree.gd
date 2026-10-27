class_name SwayingTree
extends StaticBody3D
## A rooted tree. It bends away from the god's hand's wind. The hand doesn't
## pick trees up.

const MAX_TILT := 0.5
const STIFFNESS := 30.0
const DAMPING := 5.0

var _tilt := Vector2.ZERO       # x = lean toward +X, y = lean toward +Z
var _tilt_vel := Vector2.ZERO
var _push := Vector2.ZERO
var _phase := randf() * TAU


func build(p_trunk: Material, p_crown: Material, radius: float) -> void:
	add_to_group("wind_reactive")
	set_meta("surface", &"wood")
	_add_shapes(radius)
	_add_visuals(p_trunk, p_crown, radius)


func _add_visuals(p_trunk: Material, p_crown: Material, radius: float) -> void:
	var trunk := MeshInstance3D.new()
	trunk.mesh = SharedMeshes.cylinder(0.25, 0.35, 3.0)
	trunk.material_override = p_trunk
	trunk.position.y = 1.5
	add_child(trunk)
	var crown := MeshInstance3D.new()
	crown.mesh = SharedMeshes.unit_sphere()
	crown.scale = Vector3.ONE * radius
	crown.material_override = p_crown
	crown.position.y = 4.0
	add_child(crown)


func _add_shapes(radius: float) -> void:
	var trunk := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 3.0
	trunk.shape = cyl
	trunk.position.y = 1.5
	add_child(trunk)
	var crown := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	crown.shape = sphere
	crown.position.y = 4.0
	add_child(crown)


func aim_point() -> Vector3:
	return global_position + Vector3.UP * 3.5


func on_hand_wind(hand: Node3D) -> void:
	var s: float = hand.wind_strength(global_position + Vector3.UP * 3.0)
	if s <= 0.0:
		_push = Vector2.ZERO
		return
	var away := global_position - hand.global_position
	var dir: Vector2 = Vector2(away.x, away.z).normalized() + Vector2(hand.hand_velocity.x, hand.hand_velocity.z) * 0.03
	_push = dir.limit_length(1.0) * s * MAX_TILT


func _physics_process(delta: float) -> void:
	_phase += delta
	var breeze := Vector2(sin(_phase * 0.9), cos(_phase * 0.7)) * 0.015
	var accel := (_push + breeze - _tilt) * STIFFNESS - _tilt_vel * DAMPING
	_tilt_vel += accel * delta
	_tilt += _tilt_vel * delta
	rotation = Vector3(_tilt.y, 0, -_tilt.x)
