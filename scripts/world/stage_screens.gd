class_name StageScreens
extends CanvasLayer
## The start and end of the Slums stage: a briefing from the Secretary when the game
## opens (the world waits behind it), and the lose screen when the cult has dissolved
## (it had believers, then none for a while). Winning is DistrictWon's screen.

## The cult has dissolved.
signal lost

const S: DistrictSettings = preload("res://data/districts.tres")

@export var population: Population

var _start: PanelContainer
var _lose: PanelContainer
var _ever_enough := false
var _empty_for := 0.0
var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start = _panel(S.start_title, S.start_briefing, S.start_button, _begin)
	_lose = _panel(S.lose_title, S.lose_line, S.retry_button,
			func() -> void: get_tree().reload_current_scene())
	_lose.visible = false
	if not _wants_briefing():
		_start.visible = false
		return
	# Let the city fill in and the HUD show its numbers before the world waits.
	await get_tree().create_timer(0.5).timeout
	if _start.visible:
		get_tree().paused = true


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or _lose.visible or get_tree().paused:
		return
	_timer = 1.0
	var others := population.believer_count - (1 if population.priest else 0)
	if others >= S.lose_after_believers:
		_ever_enough = true
	if not _ever_enough or others > 0:
		_empty_for = 0.0
		return
	_empty_for += 1.0
	if _empty_for >= S.lose_minutes * 60.0:
		_lose.visible = true
		get_tree().paused = true
		lost.emit()


func _begin() -> void:
	_start.visible = false
	get_tree().paused = false


## No briefing in headless runs (tests, checks) or with --no-briefing.
func _wants_briefing() -> bool:
	return DisplayServer.get_name() != "headless" \
			and not OS.get_cmdline_user_args().has("--no-briefing")


func _panel(title: String, body: String, button_text: String, action: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override(&"font_size", 34)
	head.modulate = S.captured_color
	box.add_child(head)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(600.0, 0.0)
	text.add_theme_font_size_override(&"font_size", 17)
	box.add_child(text)
	var button := Button.new()
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	box.add_child(button)
	return panel
