extends RigidBody3D
## A yellow cab. Can be picked up and thrown; a tap sets off its alarm, which
## makes people nearby turn to look.

const ALARM_TIME := 3.0
const ALARM_RADIUS := 20.0

var _lights := StandardMaterial3D.new()
var _alarm := 0.0


func build(body_mat: Material) -> void:
	add_to_group("god_grabbable")
	mass = 4.0
	set_meta("surface", &"metal")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.5, 4.5)
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.material_override = body_mat
	add_child(mesh)

	_lights.albedo_color = Color(0.9, 0.9, 0.8)
	_lights.emission_enabled = true
	_lights.emission = Color(1.0, 0.85, 0.4)
	_lights.emission_energy_multiplier = 0.0
	for x in [-0.65, 0.65]:
		for z in [-2.26, 2.26]:
			var light := MeshInstance3D.new()
			var light_mesh := BoxMesh.new()
			light_mesh.size = Vector3(0.4, 0.25, 0.05)
			light.mesh = light_mesh
			light.material_override = _lights
			light.position = Vector3(x, 0.1, z)
			add_child(light)
	set_process(false)


## Tapped by the hand: the alarm goes off.
func on_tapped(_from: Vector3) -> void:
	_alarm = ALARM_TIME
	set_process(true)
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.global_position.distance_to(global_position) < ALARM_RADIUS:
			c.notice(global_position)


func _process(delta: float) -> void:
	_alarm -= delta
	var on := _alarm > 0.0 and fmod(_alarm, 0.4) > 0.2
	_lights.emission_energy_multiplier = 4.0 if on else 0.0
	if _alarm <= 0.0:
		set_process(false)
