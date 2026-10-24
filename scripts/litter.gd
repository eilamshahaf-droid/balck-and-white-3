extends RigidBody3D
## A newspaper sheet on the sidewalk. The hand's wind lifts it and blows it away.

const S = preload("res://data/hand_settings.tres")
const WIND_LIFT := 1.6


func build(mat: Material) -> void:
	add_to_group("wind_reactive")
	set_meta("surface", &"paper")
	mass = 0.05
	linear_damp = 2.5
	angular_damp = 1.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.03, 0.38)
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.material_override = mat
	add_child(mesh)


func on_hand_wind(hand: Node3D) -> void:
	var s: float = hand.wind_strength(global_position)
	if s < 0.05:
		return
	var away := global_position - hand.global_position
	away.y = 0
	var dir: Vector3 = away.normalized() + Vector3.UP * WIND_LIFT + hand.hand_velocity * 0.05
	sleeping = false
	apply_central_force(dir * s * S.wind_force * mass)
	apply_torque(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * s * 0.02)
