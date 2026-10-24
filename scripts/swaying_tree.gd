extends Node3D
## A park tree that bends away from the god's hand and springs back.

const MAX_TILT := 0.5
const STIFFNESS := 30.0
const DAMPING := 5.0

var _tilt := Vector2.ZERO       # x = lean toward +X, y = lean toward +Z
var _tilt_vel := Vector2.ZERO
var _push := Vector2.ZERO
var _phase := randf() * TAU


func build(trunk_mat: Material, crown_mat: Material, crown_radius: float) -> void:
	add_to_group("wind_reactive")
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 3.0
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = 1.5
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = crown_radius
	crown_mesh.height = crown_radius * 2.0
	crown.mesh = crown_mesh
	crown.material_override = crown_mat
	crown.position.y = 4.0
	add_child(crown)


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
