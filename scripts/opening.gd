extends Node
## The opening scene from the design doc: "the burning building".
##
## Night. An old apartment building is burning, the fire trucks are stuck, a
## tenant is trapped on the roof. The Keepers of the Hand, the secret
## community that kept the god's tradition and has just called Him back,
## teach the water miracle; the player draws it; witnesses each pick an
## explanation; the one the miracle saved becomes the first believer outside
## the Keepers. The strategist sets the next task, and the morning paper
## calls it a localised weather event.
##
## Tab skips the story and starts the sandbox with a ready congregation.
## The first believer and one filming skeptic are scripted; every other
## witness reacts through the belief formula.

const FireScript = preload("res://scripts/fire.gd")
const Sfx = preload("res://scripts/sfx.gd")

const KEEPER := ["Old Nadia, Keeper of the Hand", Color(0.55, 0.9, 0.6)]
const STRATEGIST := ["Victor (strategist)", Color(0.95, 0.7, 0.45)]
const CROWD_SIZE := 14

@export var enabled := true

@onready var city: Node3D = get_parent()
@onready var rig: Node3D = get_node("../CameraRig")
@onready var hand: Node3D = get_node("../GodHand")
@onready var faith: Node = get_node("../Faith")
@onready var miracles: Node = get_node("../Miracles")
@onready var population: Node = get_node("../Population")

var running := false
var fire: Node3D
var survivor: Node3D             # the tenant trapped on the roof
var skeptic: Node3D
var crowd: Array = []

var _ui: CanvasLayer
var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _hint: Label
var _paper: PanelContainer
var _advance := false
var _skipped := false


func _ready() -> void:
	_build_ui()
	if enabled:
		_begin.call_deferred()
	else:
		population.found_congregation.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
		_advance = true
	elif event.keycode == KEY_TAB:
		_skip()


func _begin() -> void:
	running = true
	_set_help_visible(false)
	city.set_daylight(0.05)
	var building := _pick_building()
	var size := _box_size(building)
	fire = FireScript.new()
	city.add_child(fire)
	fire.ignite(building, size)
	_stage_people(building, size)

	# Start high over the night city and come down to the fire.
	rig.target_pivot = building.position
	rig.target_distance = 420.0
	rig.target_pitch = deg_to_rad(65.0)
	await _wait(1.0)
	if _skipped: return
	# Frame the roof and the street in front from above: in a dense city a low
	# view across the street would only show the next block.
	rig.target_yaw = deg_to_rad(20.0)
	rig.fly_to(Vector3(building.position.x, size.y * 0.75, building.position.z + size.z / 2.0 + 3.0), false, 60.0)
	rig.target_pitch = deg_to_rad(48.0)
	await _wait(2.0)
	if _skipped: return

	await _say(KEEPER, "Meeting 2,847 of the Keepers of the Hand. Last week's prayer: no answer... Wait. Did the dryer just stop? It's Him. Somebody write it in the minutes.")
	if _skipped: return
	await _say(KEEPER, "And look out the window: the old building on the corner is on fire. The fire trucks are stuck in traffic. Again. There's someone on the roof.")
	if _skipped: return
	await _say(KEEPER, "The old stories say You brought rain. Hold the RIGHT mouse button and draw a circle over the burning building.")
	if _skipped: return

	# Wait for a water miracle that actually lands on the fire.
	_show(KEEPER, "Hold the RIGHT mouse button and draw a circle over the fire.", false)
	while fire.is_burning():
		var outcome = await _next_miracle_attempt()
		if _skipped: return
		if outcome == &"missed":
			_show(KEEPER, "Closer! Right over the flames. My eyes are old, but even I can see You missed.", false)
		elif outcome == &"unknown_gesture":
			_show(KEEPER, "Almost. Keep the right button down and draw one round loop, like stirring soup.", false)
		elif outcome == &"no_belief":
			faith.belief_pool = maxf(faith.belief_pool, 20.0)  # the story never strands you here
			_show(KEEPER, "Try once more. We waited three hundred years; we can wait a minute.", false)
		elif outcome == &"hit":
			_show(KEEPER, "Yes! Keep it coming...", false)
			var t := 0.0
			while fire.is_burning() and t < 8.0 and not _skipped:
				await get_tree().process_frame
				t += get_process_delta_time()
			if _skipped: return
			if fire.is_burning():
				_show(KEEPER, "It's not out yet. Once more!", false)

	await _wait(1.5)
	if _skipped: return
	# The crowd decides what it saw.
	_hide()
	rig.fly_to(_crowd_center(), false, 22.0)
	rig.target_pitch = deg_to_rad(25.0)
	await _wait(4.5)
	if _skipped: return
	await _say(KEEPER, "Listen to them. Everyone explains it their own way: luck, a hoax, a miracle. And that one is filming.")
	if _skipped: return

	# The first believer.
	survivor.idle = true
	rig.fly_to(survivor.global_position, false, 18.0)
	await _wait(2.0)
	if _skipped: return
	_show_belief_meter(survivor)
	Sfx.play(get_tree(), survivor.global_position, &"chime", 0.8)
	var count: int = faith.believers
	var line := "Him. You saved him, and he knows it. Your first believer outside our basement." if count <= 1 \
			else "Him. You saved him, and he knows it. That's %d believers outside our basement." % count
	await _say(KEEPER, line + "  (This is the only time you'll see his belief. From now on, read people by how they act.)")
	if _skipped: return
	await _say(STRATEGIST, "Charming. But one believer fades fast if he has nobody to talk to. And that video already has more views than your whole tradition.")
	if _skipped: return

	# Morning.
	_hide()
	var tween := create_tween()
	tween.tween_method(city.set_daylight, 0.05, 1.0, 3.0)
	await tween.finished
	if _skipped: return
	_bring_people_down()
	_paper.visible = true
	_advance = false
	await _wait_advance(8.0)
	_paper.visible = false
	if _skipped: return
	await _say(KEEPER, "Your first job: help him tell his family. People believe the people they love, not miracles.")
	if _skipped: return
	await _say(STRATEGIST, "Until then, the city is yours. Every miracle in front of a camera brings the government closer.")
	_finish()


# --- Staging ---

## An older mid-rise in a low part of town, so the fire can be seen from above
## without towers in the way.
func _pick_building() -> Node3D:
	var all := get_tree().get_nodes_in_group("buildings")
	var best: Node3D = null
	var best_score := INF
	for b in all:
		var h: float = _box_size(b).y
		if h < 16.0 or h > 32.0:
			continue
		var tallest := 0.0
		for other in all:
			if other != b and other.position.distance_to(b.position) < 60.0:
				tallest = maxf(tallest, _box_size(other).y)
		var score: float = tallest + b.position.length() * 0.02
		if score < best_score:
			best_score = score
			best = b
	return best


func _box_size(building: Node3D) -> Vector3:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape.size
	return Vector3.ONE * 10.0


func _stage_people(building: Node3D, size: Vector3) -> void:
	var people := get_tree().get_nodes_in_group("citizens")
	var roof: float = building.position.y + size.y / 2.0
	survivor = people[0]
	survivor.global_position = Vector3(building.position.x, roof + 0.2, building.position.z)
	survivor.idle = true
	survivor.belief = 0.1
	survivor.skepticism = 0.05
	survivor._look_at_target = building.position + Vector3(0, roof, size.z)
	fire.endangered = [survivor]

	# A crowd in the street in front of the building, all looking up at it.
	var street_z: float = building.position.z + size.z / 2.0 + 5.5
	for n in range(1, CROWD_SIZE + 1):
		var c: Node3D = people[n]
		c.global_position = Vector3(building.position.x + randf_range(-10, 10), 0.3, street_z + randf_range(-1.5, 2.5))
		c.idle = true
		c._look_at_target = building.position + Vector3.UP * roof * 0.5
		crowd.append(c)
	skeptic = crowd[0]
	skeptic.skepticism = 0.95
	skeptic.has_phone = true


func _crowd_center() -> Vector3:
	var sum := Vector3.ZERO
	for c in crowd:
		sum += c.global_position
	return sum / crowd.size()


## Morning: the survivor has come down, the crowd goes home.
func _bring_people_down() -> void:
	if survivor:
		survivor.global_position = _crowd_center() + Vector3(2, 0.3, 0)
		survivor.resume_walking()
	for c in crowd:
		c.resume_walking()


func _next_miracle_attempt() -> StringName:
	var result := [&""]
	var on_cast := func(kind: StringName, miracle: Node3D):
		var d := Vector2(miracle.global_position.x - fire.global_position.x, miracle.global_position.z - fire.global_position.z).length()
		result[0] = &"hit" if kind == &"water" and d < 14.0 else &"missed"
	var on_fail := func(reason: StringName): result[0] = reason
	var on_scribble := func(): result[0] = &"unknown_gesture"
	miracles.miracle_cast.connect(on_cast)
	miracles.miracle_failed.connect(on_fail)
	hand.gesture_unrecognised.connect(on_scribble)
	while result[0] == &"" and not _skipped:
		await get_tree().process_frame
	miracles.miracle_cast.disconnect(on_cast)
	miracles.miracle_failed.disconnect(on_fail)
	hand.gesture_unrecognised.disconnect(on_scribble)
	return result[0]


func _show_belief_meter(person: Node3D) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.pixel_size = 0.01
	label.outline_size = 14
	label.modulate = Color(1.0, 0.85, 0.35)
	var filled := roundi(clampf(person.belief, 0.0, 1.0) * 10.0)
	label.text = "Belief  " + "#".repeat(filled) + "-".repeat(10 - filled) + "  %d%%" % roundi(person.belief * 100.0)
	label.position.y = 3.4
	person.add_child(label)
	get_tree().create_timer(9.0).timeout.connect(label.queue_free)


# --- Flow helpers ---

func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	if fire and fire.is_burning():
		fire.douse(1.0)
	city.set_daylight(1.0)
	_bring_people_down()
	_paper.visible = false
	population.found_congregation()
	_finish()


func _finish() -> void:
	running = false
	_hide()
	_set_help_visible(true)


func _set_help_visible(on: bool) -> void:
	var help := get_node_or_null("../HUD/Help")
	if help:
		help.visible = on

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skipped:
		await get_tree().process_frame
		t += get_process_delta_time()


func _wait_advance(timeout: float) -> void:
	var t := 0.0
	_advance = false
	while not _advance and t < timeout and not _skipped:
		await get_tree().process_frame
		t += get_process_delta_time()


## Show a line and wait for Space (or long enough to read it).
func _say(who: Array, text: String) -> void:
	_show(who, text, true)
	await _wait_advance(4.0 + text.length() * 0.06)


func _show(who: Array, text: String, can_advance: bool) -> void:
	_panel.visible = true
	_speaker.text = who[0]
	_speaker.modulate = who[1]
	_line.text = text
	_hint.text = "Space: continue    Tab: skip the story" if can_advance else "Tab: skip the story"


func _hide() -> void:
	_panel.visible = false


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(anchor)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -420
	_panel.offset_right = 420
	_panel.offset_top = -150
	_panel.offset_bottom = -24
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 20)
	box.add_child(_speaker)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 18)
	_line.custom_minimum_size = Vector2(800, 0)
	box.add_child(_line)
	_hint = Label.new()
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.add_theme_font_size_override("font_size", 13)
	box.add_child(_hint)
	_panel.visible = false
	anchor.add_child(_panel)

	_paper = PanelContainer.new()
	_paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_paper.offset_left = -330
	_paper.offset_right = 330
	_paper.offset_top = -120
	_paper.offset_bottom = 120
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.91, 0.85)
	style.set_content_margin_all(24)
	_paper.add_theme_stylebox_override("panel", style)
	var paper_box := VBoxContainer.new()
	_paper.add_child(paper_box)
	for line in [["THE CITY HERALD", 34], ["Morning edition", 14], ["\"LOCALISED WEATHER EVENT\" SAVES TENANT IN BLAZE", 22],
			["City spokesperson: \"A localised weather event.\" She added that the building's roof garden has no permit. Residents describe rain from a clear sky.", 15],
			["Space: continue", 12]]:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(600, 0)
		paper_box.add_child(l)
	_paper.visible = false
	anchor.add_child(_paper)
