extends Label
## The controls, folded away to one strip of tape with the few that matter now until
## the player asks for them all (H), which opens them on an index card.

@export var hint := "HOLD on a building for its tags · LIFT Reps and inspectors · H all controls"

var _full := ""


func _ready() -> void:
	_full = text
	_fold(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_fold(text != hint)


func _fold(on: bool) -> void:
	text = hint if on else _full
	theme_type_variation = &"HintTape" if on else &"SlipLabel"
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
