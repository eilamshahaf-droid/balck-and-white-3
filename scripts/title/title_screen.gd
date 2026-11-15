class_name TitleScreen
extends CanvasLayer
## The title screen (Eilam, 2026-11-15: everything easy to reach): New Game, the Room
## Designer, Settings, Credits, and the version. It applies the player's settings at
## start. Headless, or with --shot, it goes straight into the game, so the checks and the
## screenshot in CLAUDE.md still run the game.

const GAME := "res://scenes/main.tscn"
const DESIGNER := "res://scenes/room_designer.tscn"
const GAP := 10

var player: PlayerSettings

# Loaded at run time: the credits array is not stored in the .tres, and a const preload
# folds it to null in the parser.
var _s: TitleSettings = load("res://data/title.tres")

var _menu: VBoxContainer
var _settings: VBoxContainer
var _credits: VBoxContainer


func _ready() -> void:
	layer = 2   # above the art style's screen layer
	player = PlayerSettings.new(_s.settings_path)
	player.apply()
	if DisplayServer.get_name() == "headless" or _has_shot_arg():
		get_tree().change_scene_to_file.call_deferred(GAME)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func _build() -> void:
	var back := ColorRect.new()
	back.color = _s.background_color
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", GAP)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	var title := Label.new()
	title.text = str(ProjectSettings.get_setting("application/config/name"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", _s.title_size)
	title.add_theme_color_override(&"font_color", _s.title_color)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _s.subtitle
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	column.add_child(subtitle)
	column.add_child(_spacer())
	_menu = VBoxContainer.new()
	_settings = VBoxContainer.new()
	_credits = VBoxContainer.new()
	for box: VBoxContainer in [_menu, _settings, _credits]:
		box.add_theme_constant_override(&"separation", GAP)
		box.custom_minimum_size.x = _s.button_width
		column.add_child(box)
	_button(_menu, "New Game", func() -> void: get_tree().change_scene_to_file(GAME))
	_button(_menu, "Room Designer", func() -> void: get_tree().change_scene_to_file(DESIGNER))
	_button(_menu, "Settings", _show.bind(_settings))
	_button(_menu, "Credits", _show.bind(_credits))
	if not OS.has_feature("web"):
		_button(_menu, "Quit", func() -> void: get_tree().quit())
	_build_settings()
	_build_credits()
	_show(_menu)
	var version := Label.new()
	version.text = "%s %s" % [ProjectSettings.get_setting("application/config/release_stage"),
			ProjectSettings.get_setting("application/config/version")]
	version.modulate = Color(1, 1, 1, 0.5)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_left = -12.0
	version.offset_top = -8.0
	add_child(version)


func _build_settings() -> void:
	var volume_label := Label.new()
	volume_label.text = "Sound volume"
	_settings.add_child(volume_label)
	var volume := HSlider.new()
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = player.volume
	volume.value_changed.connect(func(v: float) -> void:
		player.volume = v
		_changed())
	_settings.add_child(volume)
	if not OS.has_feature("web"):
		_toggle("Full screen", player.fullscreen, func(on: bool) -> void:
			player.fullscreen = on
			_changed())
	_toggle("Art style (tilt-shift and soft shading; V in the game)", player.art_style,
			func(on: bool) -> void:
				player.art_style = on
				_changed())
	_button(_settings, "Show the opening scene again", func() -> void:
		DirAccess.remove_absolute(StageScreens.SEEN))
	_button(_settings, "Back", _show.bind(_menu))


func _build_credits() -> void:
	for line in _s.credits:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_credits.add_child(label)
	_button(_credits, "Back", _show.bind(_menu))


func _show(box: VBoxContainer) -> void:
	for b: VBoxContainer in [_menu, _settings, _credits]:
		b.visible = b == box


func _changed() -> void:
	player.apply()
	player.save()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40.0
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _toggle(text: String, on: bool, action: Callable) -> void:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.toggled.connect(action)
	_settings.add_child(check)


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 24.0
	return c


static func _has_shot_arg() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot"):
			return true
	return false
