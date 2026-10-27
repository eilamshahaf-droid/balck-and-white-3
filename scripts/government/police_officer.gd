class_name PoliceOfficer
extends RigidBody3D
## One officer of an arrest squad: a blocky policeman the hand can pick up and
## throw away, which is how the player frees the arrested priest.

const BODY := Vector3(0.6, 1.0, 0.4)
const HEAD := Vector3(0.38, 0.38, 0.38)
const CAP := Vector3(0.46, 0.14, 0.46)
const HEIGHT := 1.8


func build(uniform: Material, skin: Material, mass_kg: float) -> void:
	add_to_group("god_grabbable")
	set_meta("surface", &"flesh")
	mass = mass_kg
	collision_layer = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BODY.x, HEIGHT, BODY.z)
	shape.shape = box
	shape.position.y = HEIGHT / 2.0
	add_child(shape)
	_part(BODY, Vector3(0.0, 0.5 + BODY.y / 2.0, 0.0), uniform)
	_part(HEAD, Vector3(0.0, 0.5 + BODY.y + HEAD.y / 2.0, 0.0), skin)
	_part(CAP, Vector3(0.0, 0.5 + BODY.y + HEAD.y + CAP.y / 2.0, 0.0), uniform)
	_part(Vector3(BODY.x * 0.8, 0.5, BODY.z), Vector3(0.0, 0.25, 0.0), uniform)


func _part(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SharedMeshes.box(Vector3.ONE)
	mesh.material_override = material
	mesh.scale = size
	mesh.position = at
	add_child(mesh)
