class_name StrikeLabel
extends Label
## A label a red pen strikes through: `strike` from 0 (none) to 1 (the whole line).

const S: UiSettings = preload("res://data/ui.tres")

var strike := 0.0:
	set(v):
		strike = v
		queue_redraw()


func _draw() -> void:
	if strike <= 0.0 or text == "":
		return
	var font := get_theme_font(&"font")
	var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_theme_font_size(&"font_size")).x, size.x)
	var y := size.y * 0.55
	draw_line(Vector2(0.0, y), Vector2(w * strike, y - 1.0), S.red, 2.0, true)
