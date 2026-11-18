class_name Desk
extends Control
## The interface's table top: holds every piece of the HUD under one Theme
## (data/ui_theme.tres), dims the paper while the game is paused, and writes the
## version in the corner and the window title.

const S: UiSettings = preload("res://data/ui.tres")

var _corner := Label.new()
var _paused := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var version := "%s %s" % [ProjectSettings.get_setting("application/config/release_stage"),
			ProjectSettings.get_setting("application/config/version")]
	DisplayServer.window_set_title("%s %s" % [ProjectSettings.get_setting("application/config/name"), version])
	_corner.text = version
	_corner.theme_type_variation = &"Caption"
	_corner.modulate.a = S.version_alpha
	add_child(_corner)
	_corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_corner.offset_left = -8.0
	_corner.offset_top = -6.0


func _process(_delta: float) -> void:
	if get_tree().paused != _paused:
		_paused = get_tree().paused
		modulate = Color.WHITE * S.pause_dim if _paused else Color.WHITE
		modulate.a = 1.0
