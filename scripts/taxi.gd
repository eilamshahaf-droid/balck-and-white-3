extends RigidBody3D
## A yellow cab. Can be picked up and thrown; a tap sets off its alarm, which
## makes people nearby turn to look.

const ALARM_TIME := 3.0
const ALARM_RADIUS := 20.0

var _lights := StandardMaterial3D.new()
var _alarm := 0.0


func build(kind: PropKind) -> void:
	add_to_group("god_grabbable")
	mass = kind.mass
	set_meta("surface", kind.surface)
	var model := PropModel.of(kind)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = model.size
	shape.shape = box
	add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = model.mesh
	mesh.material_override = model.material
	mesh.transform = Transform3D(Basis.IDENTITY, Vector3.DOWN * model.size.y / 2.0) * model.offset
	add_child(mesh)

	_lights.albedo_color = Color(0.9, 0.9, 0.8)
	_lights.emission_enabled = true
	_lights.emission = Color(1.0, 0.85, 0.4)
	_lights.emission_energy_multiplier = 0.0
	# Head and tail lights at the four corners of the bumpers.
	for x: float in [-0.32, 0.32]:
		for z: float in [-0.5, 0.5]:
			var light := MeshInstance3D.new()
			light.mesh = SharedMeshes.box(Vector3(0.4, 0.25, 0.05))
			light.material_override = _lights
			var end := z * model.size.z + signf(z) * 0.03
			light.position = Vector3(x * model.size.x, -0.15 * model.size.y, end)
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
