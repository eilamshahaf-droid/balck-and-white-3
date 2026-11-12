extends Label
## The controls, folded away to one hint line until the player asks for them (H),
## so the screen is not covered in text from the first second.

@export var hint := "H: how to play"

var _full := ""


func _ready() -> void:
	_full = text
	text = hint


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		text = _full if text == hint else hint
