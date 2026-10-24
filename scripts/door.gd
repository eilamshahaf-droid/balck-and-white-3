extends Node3D
## A building's street door. Knocking on it with the hand swings it open for a moment.
## Local +Z faces the street; the door swings inward.

const OPEN_ANGLE := 1.6
const OPEN_TIME := 2.5
const SPEED := 6.0

var _hinge := Node3D.new()
var _open_timer := 0.0


func build(mat: Material) -> void:
	add_to_group("doors")
	add_child(_hinge)
	var leaf := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 2.4, 0.12)
	leaf.mesh = box
	leaf.material_override = mat
	leaf.position = Vector3(0.7, 1.2, 0)   # hinge on the left edge
	_hinge.add_child(leaf)
	set_physics_process(false)


func knock() -> void:
	_open_timer = OPEN_TIME
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_open_timer -= delta
	var goal := OPEN_ANGLE if _open_timer > 0.0 else 0.0
	_hinge.rotation.y = lerpf(_hinge.rotation.y, goal, 1.0 - exp(-SPEED * delta))
	if _open_timer <= 0.0 and _hinge.rotation.y < 0.01:
		_hinge.rotation.y = 0.0
		set_physics_process(false)
