class_name StageScreens
extends CanvasLayer
## The start of the Slums stage: the opening scene, a few panels of the story, the first
## time the game opens (the world waits, dimmed, behind it). Next steps through it, Skip
## ends it; then the mission card says what to do. Winning is DistrictWon's screen.

const S: DistrictSettings = preload("res://data/districts.tres")
## Written once the opening has been seen or skipped, so it shows on the first run only.
const SEEN := "user://opening_seen"
## Above the HUD and the building card, so nothing shows through.
const OPENING_LAYER := 50

var _root: Control
var _speaker: Label
var _direction: Label
var _line: Label
var _next: Button
var _panel := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = OPENING_LAYER
	_build()
	if not _wants_opening():
		_root.visible = false
		return
	_show(0)
	# The hand is a 3D glove under the dimmed screen: show the system pointer meanwhile.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Let the city fill in and the HUD show its numbers before the world waits.
	await get_tree().create_timer(0.5).timeout
	if _root.visible:
		get_tree().paused = true


## The opening is up.
func is_open() -> bool:
	return _root.visible


func _show(i: int) -> void:
	_panel = i
	_speaker.text = S.opening_speaker(i)
	_direction.text = S.opening_direction(i)
	_direction.visible = _direction.text != ""
	_line.text = S.opening_line(i)
	_next.text = S.opening_done if i == S.opening_count() - 1 else S.opening_next


func _on_next() -> void:
	if _panel + 1 < S.opening_count():
		_show(_panel + 1)
	else:
		_end()


func _end() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var seen := FileAccess.open(SEEN, FileAccess.WRITE)
	if seen:
		seen.store_string("1")


## No opening after the first run, in headless runs (tests, checks) or with
## --no-briefing; --briefing shows it again.
func _wants_opening() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--briefing"):
		return true
	return DisplayServer.get_name() != "headless" and not args.has("--no-briefing") \
			and not FileAccess.file_exists(SEEN)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = S.opening_dim
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = S.opening_panel_color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24.0)
	panel.add_theme_stylebox_override(&"panel", style)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	_speaker = _label(box, 26)
	_speaker.modulate = S.captured_color
	_direction = _label(box, 16)
	_direction.modulate = S.opening_direction_color
	_line = _label(box, 22)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 10)
	box.add_child(buttons)
	var skip := Button.new()
	skip.text = S.opening_skip
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_end)
	buttons.add_child(skip)
	_next = Button.new()
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(_on_next)
	buttons.add_child(_next)


func _label(box: VBoxContainer, size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(620.0, 0.0)
	label.add_theme_font_size_override(&"font_size", size)
	box.add_child(label)
	return label
