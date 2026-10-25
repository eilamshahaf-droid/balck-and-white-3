extends Node3D
## The lightning miracle: a bolt out of a clear sky. People close by are
## thrown off their feet, cars nearby jump and their alarms go off.

const M = preload("res://data/miracles.tres")
const Sfx = preload("res://scripts/sfx.gd")

const SKY_HEIGHT := 140.0
const SEGMENTS := 9
const FLASH_TIME := 0.6
const LIFE := 2.0

var _flash: OmniLight3D
var _bolt: Node3D
var _t := 0.0
var _frames := 0


## Strike the spot `ground`.
func strike(ground: Vector3) -> void:
	position = ground
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.6, 1.0)
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(0.45, 0.5, 1.0, 0.35)
	_bolt = Node3D.new()
	add_child(_bolt)
	# A jagged line from the sky down to the spot, one thin box per segment.
	var prev := Vector3.UP * SKY_HEIGHT
	for i in range(1, SEGMENTS + 1):
		var t := float(i) / SEGMENTS
		var next := Vector3(randf_range(-6, 6) * (1.0 - t), SKY_HEIGHT * (1.0 - t), randf_range(-6, 6) * (1.0 - t))
		for layer in [[0.8, mat], [2.4, halo]]:
			var seg := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(layer[0], layer[0], prev.distance_to(next))
			seg.mesh = box
			seg.material_override = layer[1]
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_bolt.add_child(seg)
			seg.look_at_from_position(ground + (prev + next) / 2.0, ground + next, Vector3.RIGHT)
		prev = next
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.8, 0.85, 1.0)
	_flash.omni_range = 70.0
	_flash.light_energy = 16.0
	_flash.position = Vector3.UP * 6.0
	add_child(_flash)
	Sfx.play(get_tree(), ground, &"zap", 1.0)
	Sfx.play(get_tree(), ground + Vector3.UP * 20.0, &"thunder", 1.0)
	_blast(ground)


func _blast(ground: Vector3) -> void:
	for c in get_tree().get_nodes_in_group("citizens"):
		var away: Vector3 = c.global_position - ground
		away.y = 0.0
		if away.length() < M.lightning_radius:
			var push := (away.normalized() + Vector3.UP * 0.8) * M.lightning_push * (1.0 - away.length() / M.lightning_radius * 0.5)
			c.knock_over(push)
	for obj in get_tree().get_nodes_in_group("god_grabbable"):
		if obj is RigidBody3D and obj.global_position.distance_to(ground) < M.lightning_radius * 1.5:
			obj.apply_central_impulse(Vector3.UP * obj.mass * 4.0)
			if obj.has_method("on_tapped"):
				obj.on_tapped(ground)


## Where witnesses look: up the bolt, not at the ground behind parked cars.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * 10.0


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	# The bolt flickers a couple of times, then only the afterglow fades. It is
	# always drawn for the first frames, so a slow frame can't swallow it.
	_bolt.visible = _frames <= 2 or (_t < 0.35 and fmod(_t, 0.12) < 0.08)
	_flash.light_energy = 16.0 * maxf(1.0 - _t / FLASH_TIME, 0.0)
	if _t > LIFE:
		queue_free()
