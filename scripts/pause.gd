class_name Pause
extends CanvasLayer
## The player's own pause (Space): the city stands still, but the hand, the camera, the
## wheels and the room editor go on working, so a building can be planned in peace. The
## game never pauses by itself when a menu opens.

## What keeps working while the player has the game paused.
@export var keep_awake: Array[Node] = []
## The briefing pauses the whole tree itself; Space does nothing until it is closed.
@export var screens: StageScreens
@export var text := "PAUSED  (Space)"

var _label := Label.new()
var _on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label.text = text
	_label.visible = false
	_label.add_theme_font_size_override(&"font_size", 26)
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -14.0
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE \
			and not screens.is_open():
		set_paused(not _on)
		get_viewport().set_input_as_handled()


func set_paused(on: bool) -> void:
	_on = on
	for node in keep_awake:
		node.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	get_tree().paused = on
	_label.visible = on
