class_name StageScreens
extends CanvasLayer
## The start of the Slums stage: a briefing from the Secretary when the game opens (the
## world waits behind it). Winning is DistrictWon's screen; the stage has no way to lose
## until round B brings the danger.

const S: DistrictSettings = preload("res://data/districts.tres")

var _start: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start = _panel(S.start_title, S.start_briefing, S.start_button, _begin)
	if not _wants_briefing():
		_start.visible = false
		return
	# Let the city fill in and the HUD show its numbers before the world waits.
	await get_tree().create_timer(0.5).timeout
	if _start.visible:
		get_tree().paused = true


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
