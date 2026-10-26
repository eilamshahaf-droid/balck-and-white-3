extends RigidBody3D
## The demolition crew's bulldozer. It drives up the avenue to the building on
## the notice and slowly pushes it into the ground, unless something stops it:
## a shield over it, believers standing at the building, or lightning nearby.
## The hand can also just pick it up, and after that the crew won't get back in.
## Either way it stays behind as one more thing to throw around.

signal finished(demolished: bool)

enum Mode { DRIVING, WORKING, DONE }

const G = preload("res://data/government.tres")
const B = preload("res://data/balance.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")
const RIDE_HEIGHT := 1.1
const LINES := {
	&"shield": ["Is that... weather?", "Nobody said anything about a force field."],
	&"believers": ["Folks, please step away from the building.", "I just drive the thing, lady."],
}

## True while the god's hand holds it.
var held := false

var _mode := Mode.DRIVING
var _route: Array[Vector3] = []
var _building: Node3D
var _building_y := 0.0
var _building_height := 0.0
var _progress := 0.0
var _blocked_for := 0.0
var _blocker := &""
var _check := 0.0
var _bubble: Label3D
var _bubble_left := 0.0
var _say_next := 0.0


## Drive along `route` (world points on the road), then knock down `building`.
func build(route: Array[Vector3], building: Node3D, body_mat: Material, dark_mat: Material) -> void:
	add_to_group("god_grabbable")
	mass = G.bulldozer_mass
	set_meta("surface", &"metal")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true  # driven by script until the hand or lightning sets it loose
	_route = route
	_building = building
	position = route[0] + Vector3.UP * RIDE_HEIGHT

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.2, 4.6)
	shape.shape = box
	add_child(shape)
	# Blade at the front (-Z), cab at the back.
	_add_box(Vector3(2.6, 1.4, 3.4), Vector3(0, -0.3, 0.2), body_mat)
	_add_box(Vector3(1.9, 1.3, 1.6), Vector3(0, 1.0, 0.8), body_mat)
	_add_box(Vector3(3.2, 1.2, 0.3), Vector3(0, -0.5, -2.1), dark_mat)
	for x in [-1.35, 1.35]:
		_add_box(Vector3(0.5, 0.8, 4.0), Vector3(x, -0.7, 0.2), dark_mat)

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position.y = 3.0
	_bubble.font_size = 40
	_bubble.fixed_size = true
	_bubble.pixel_size = 0.0011
	_bubble.outline_size = 12
	_bubble.no_depth_test = true
	_bubble.modulate = Color(1.0, 0.85, 0.3)
	_bubble.visible = false
	add_child(_bubble)


## For the HUD: what the crew is doing.
func status_text() -> String:
	match _mode:
		Mode.DRIVING:
			return "a bulldozer is on its way"
		Mode.WORKING:
			if _blocker == &"shield":
				return "the bulldozer is stuck at a shield"
			if _blocker == &"believers":
				return "believers are blocking the bulldozer"
			return "demolishing (%d%%)" % roundi(_progress * 100.0)
	return "the crew went home"


## Lightning nearby: the crew bails out and the bulldozer jumps.
func scare() -> void:
	if _mode == Mode.DONE:
		return
	freeze = false
	apply_central_impulse(Vector3.UP * mass * G.scare_hop)
	_give_up("The crew remembered a dentist appointment.")


func on_grabbed() -> void:
	held = true
	freeze = false
	if _mode != Mode.DONE:
		_give_up("Nope. Nope. Nope.")


func on_released(_throw_velocity: Vector3) -> void:
	held = false


func _physics_process(delta: float) -> void:
	_bubble_left -= delta
	_bubble.visible = _bubble_left > 0.0
	match _mode:
		Mode.DRIVING:
			_drive(delta)
		Mode.WORKING:
			_work(delta)


func _drive(delta: float) -> void:
	var to_point := _route[0] - global_position
	to_point.y = 0.0
	if to_point.length() < 0.3:
		_route.pop_front()
		if _route.is_empty():
			_mode = Mode.WORKING
			# Measured now, not when sent: a +3 Floors decree may have grown it meanwhile.
			_building_y = _building.position.y
			_building_height = DivineSign.building_size(_building).y
			var to_building := _building.global_position - global_position
			to_building.y = 0.0
			global_basis = Basis.looking_at(to_building.normalized())  # blade to the wall
		return
	var dir := to_point.normalized()
	global_basis = Basis.looking_at(dir)
	global_position += dir * minf(G.bulldozer_speed * delta, to_point.length())


func _work(delta: float) -> void:
	if not is_instance_valid(_building):
		return
	_check -= delta
	if _check <= 0.0:
		_check = G.check_interval
		_blocker = _what_blocks()
	if _blocker != &"":
		_blocked_for += delta
		_say_next -= delta
		if _say_next <= 0.0:
			_say_next = randf_range(4.0, 6.0)
			_say(LINES[_blocker][randi() % LINES[_blocker].size()], 3.0)
		if _blocked_for >= G.give_up_time:
			_give_up("We'll be back with a court order.")
		return
	_progress = minf(_progress + delta / G.demolish_time, 1.0)
	_building.position.y = _building_y - _progress * _building_height
	if _progress >= 1.0:
		_mode = Mode.DONE
		_say("Another one for the archive.", 3.0)
		finished.emit(true)


## Why the crew can't work right now, or &"" if nothing stops them.
func _what_blocks() -> StringName:
	for shield in get_tree().get_nodes_in_group("shields"):
		if shield.covers(global_position):
			return &"shield"
	var guards := 0
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.errand_arrived and c.belief > B.believer_threshold \
				and c.global_position.distance_to(global_position) < G.guard_radius:
			guards += 1
	return &"believers" if guards >= G.guards_to_block else &""


func _give_up(line: String) -> void:
	_mode = Mode.DONE
	if is_instance_valid(_building):
		_building.position.y = _building_y
	_say(line, 4.0)
	finished.emit(false)


func _say(text: String, seconds: float) -> void:
	_bubble.text = text
	_bubble_left = seconds


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)
