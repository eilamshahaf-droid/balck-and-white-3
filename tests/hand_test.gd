extends Node
## Drives the god's hand in the real main scene with simulated mouse input and
## checks that the basics still work: hover, pick up, throw, tap, knock, wind,
## the wheel, and letting go when the window loses focus.
##
## Run headless (the mouse can only be simulated without a real window):
##   godot --headless --path . res://tests/hand_test.tscn
## Prints one line per check and exits with code 1 if any failed.

const MAIN := preload("res://scenes/main.tscn")
const S: HandSettings = preload("res://data/hand_settings.tres")

var _main: Node3D
var _hand: Node3D
var _tools: Node
var _camera: Camera3D
var _failures := 0


func _ready() -> void:
	# A headless window has no real size; give it the game's.
	get_window().size = Vector2i(1600, 900)
	_main = MAIN.instantiate()
	add_child(_main)
	_hand = _main.get_node("GodHand")
	_tools = _main.get_node("HandTools")
	_camera = get_viewport().get_camera_3d()
	await _frames(30)
	await _test_pick_and_throw()
	await _test_focus_loss_while_holding()
	await _test_tap_taxi()
	await _test_knock()
	await _test_wind()
	await _test_wind_target_freed()
	await _test_trees_stay_rooted()
	await _test_pigeons()
	await _test_wheel_focus_loss()
	print("HAND TEST: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_pick_and_throw() -> void:
	var person := await _hover_one_of(get_tree().get_nodes_in_group("citizens"))
	_check(person != null, "hover a person")
	if person == null:
		return
	await _press()
	await _drag(Vector2(0, -30), 6)
	_check(_hand.held == person, "drag picks the person up")
	await _drag(Vector2(220, -60), 4)
	await _release()
	_check(_hand.held == null, "release lets go")
	_check(person.velocity.length() > 1.0, "a fast release throws")
	await _frames(240)


func _test_focus_loss_while_holding() -> void:
	var standing := get_tree().get_nodes_in_group("citizens").filter(
			func(c: Node) -> bool: return c.velocity.length() < 5.0)
	var person := await _hover_one_of(standing)
	if person == null:
		_check(false, "hover a person to hold")
		return
	await _press()
	await _drag(Vector2(0, -30), 6)
	_check(_hand.held == person, "holding before focus loss")
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_check(_hand.held == null, "focus loss puts the held person down")
	await _release()  # the real button-up arrives later; it must do nothing
	_check(_hand.held == null, "late button-up is harmless")
	await _frames(120)


func _test_tap_taxi() -> void:
	var taxi := await _hover_one_of(_parked_taxis())
	_check(taxi != null, "hover a taxi")
	if taxi == null:
		return
	await _press()
	await _release()
	_check(taxi.is_processing(), "a tap sets off the taxi alarm")


func _test_knock() -> void:
	var doors := get_tree().get_nodes_in_group("doors")
	for door: Node3D in doors:
		var at := door.global_position + Vector3.UP * 1.2
		if not _on_screen(at):
			continue
		_move(_camera.unproject_position(at))
		await _physics(3)
		if _hand.hovered != null:
			continue
		await _press()
		await _release()
		for d: Node3D in doors:
			if d.is_physics_processing():
				_check(true, "a tap on a wall opens a door")
				return
	_check(false, "a tap on a wall opens a door")


func _test_wind() -> void:
	var tree := await _point_at_a_tree()
	_check(tree != null, "a tree on screen")
	if tree == null:
		return
	# The wind comes from a moving hand: wave it around the crown.
	# Next to a wall the hand climbs it and leaves the tree behind, so any bend counts.
	var centre := get_viewport().get_mouse_position()
	var bent := false
	for i in 12:
		_move(centre + Vector2(30.0, 0.0).rotated(i * 1.2))
		await _physics(1)
		bent = bent or tree.get("_push") != Vector2.ZERO
	_check(bent, "the hand's wind bends a nearby tree")
	_move(Vector2(5, 5))
	await _physics(10)
	_check(tree.get("_push") == Vector2.ZERO, "the tree stops bending once the hand is gone")


## A tree in the wind can be freed (demolished with its block) between two ticks.
func _test_wind_target_freed() -> void:
	var tree := await _point_at_a_tree()
	if tree == null:
		_check(false, "hover a tree to free")
		return
	var centre := get_viewport().get_mouse_position()
	for i in 6:
		_move(centre + Vector2(30.0, 0.0).rotated(i * 1.2))
		await _physics(1)
	tree.free()
	_move(Vector2(5, 5))
	await _physics(5)
	var windy: Dictionary = _hand.get("_windy")
	_check(windy.keys().all(func(n: Variant) -> bool: return is_instance_valid(n)),
			"the wind survives a tree freed while it blows on it")


func _test_pigeons() -> void:
	var birds := get_tree().get_nodes_in_group("wind_reactive").filter(
			func(n: Node) -> bool: return n.has_method("_flap") and n.state == 0)
	if birds.is_empty():
		_check(false, "a resting pigeon")
		return
	var bird: Node3D = birds[0]
	# Pigeons sit on the street, often hidden by towers: go down to them first.
	_main.get_node("CameraRig").fly_to(bird.global_position, true)
	await get_tree().create_timer(2.0).timeout
	_move(_camera.unproject_position(bird.global_position))
	await _physics(10)
	_check(bird.state != 0, "pigeons fly off when the hand comes close")


func _test_wheel_focus_loss() -> void:
	# A busy street: a taxi or a person can pass under the hand as it presses,
	# so try spots until the press lands on bare ground or a wall.
	for spot: Vector2 in [Vector2(0.5, 0.5), Vector2(0.5, 0.95), Vector2(0.3, 0.8),
			Vector2(0.7, 0.8), Vector2(0.2, 0.5), Vector2(0.8, 0.5)]:
		_move(get_viewport().get_visible_rect().size * spot)
		await _physics(3)
		if _hand.hovered != null:
			continue
		await _press()
		await get_tree().create_timer(S.wheel_hold_time + 0.3).timeout
		if _hand.held == null:
			break
		await _release()
	_check(_hand.get("_point_anchor") != Vector3.INF, "holding still opens a wheel")
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_check(_hand.get("_point_anchor") == Vector3.INF, "focus loss closes the wheel")
	await _release()


func _test_trees_stay_rooted() -> void:
	var tree := await _point_at_a_tree()
	if tree == null:
		_check(false, "a tree on screen to grab")
		return
	await _press()
	await _drag(Vector2(0, -60), 6)
	_check(_hand.held != tree, "the hand doesn't pick up trees")
	await _release()


# --- Helpers ---

## Points the mouse at a tree the hand can get close to (not one behind a
## building). Trees aren't hovered: the hand doesn't lift them.
func _point_at_a_tree() -> SwayingTree:
	for n in get_tree().get_nodes_in_group("wind_reactive"):
		if n is SwayingTree and _on_screen(n.aim_point()):
			_move(_camera.unproject_position(n.aim_point()))
			await _physics(3)
			if _hand.global_position.distance_to(n.aim_point()) < 6.0:
				return n
	return null


## Points the mouse at each candidate in turn; returns the first one the hand highlights.
func _hover_one_of(candidates: Array) -> Node3D:
	for c: Node3D in candidates:
		var at: Vector3 = c.aim_point() if c.has_method("aim_point") else c.global_position
		if not _on_screen(at):
			continue
		_move(_camera.unproject_position(at))
		await _physics(3)
		if _hand.hovered == c:
			return c
	return null


func _parked_taxis() -> Array:
	return get_tree().get_nodes_in_group("god_grabbable").filter(
			func(n: Node) -> bool: return n is RigidBody3D and n.has_method("on_tapped"))


func _on_screen(at: Vector3) -> bool:
	if _camera.is_position_behind(at):
		return false
	var p := _camera.unproject_position(at)
	return get_viewport().get_visible_rect().grow(-40.0).has_point(p)


func _move(to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = to - get_viewport().get_mouse_position()
	e.position = to
	e.global_position = to
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
	Input.parse_input_event(e)


func _drag(by: Vector2, steps: int) -> void:
	var start := get_viewport().get_mouse_position()
	for i in steps:
		_move(start + by * float(i + 1) / steps)
		await _physics(1)


func _press() -> void:
	await _button(true)


func _release() -> void:
	await _button(false)


func _button(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = get_viewport().get_mouse_position()
	e.global_position = e.position
	Input.parse_input_event(e)
	await _physics(2)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
