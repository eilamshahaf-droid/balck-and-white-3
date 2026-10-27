extends Control
## A ring menu around the hand. The hand sits in the hole in the middle and
## points at a slice, which lights up; the slice it points at when the button
## comes up is the choice. Releasing in the middle chooses nothing.
##
## Items: {"id": StringName, "label": String, "color": Color,
## optional "note": String, optional "effect": String (a third line), optional
## "enabled": bool}.

const S = preload("res://data/hand_settings.tres")

var items: Array[Dictionary] = []
var center := Vector2.ZERO
var highlighted := -1

var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false
	set_process(false)


func open(at: Vector2, p_items: Array[Dictionary]) -> void:
	center = at
	items = p_items
	# Cover the whole screen, so the drawing is never culled as off-rect.
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	highlighted = -1
	visible = true
	set_process(true)
	queue_redraw()


## Close the wheel and return the chosen id (&"" for none).
func close() -> StringName:
	visible = false
	set_process(false)
	if highlighted < 0 or not items[highlighted].get("enabled", true):
		return &""
	return items[highlighted].id


func _process(_delta: float) -> void:
	point_at(get_viewport().get_mouse_position())


## Highlight the slice in the direction of `screen_pos`.
func point_at(screen_pos: Vector2) -> void:
	var offset := screen_pos - center
	var pick := -1
	if offset.length() > S.wheel_dead_zone_px:
		var step := TAU / items.size()
		# Slice 0 is at the top, then clockwise.
		pick = posmod(roundi(wrapf(offset.angle() + PI / 2.0, 0.0, TAU) / step), items.size())
	if pick != highlighted:
		highlighted = pick
		queue_redraw()


func _draw() -> void:
	var n := items.size()
	var step := TAU / n
	var outer: float = S.wheel_radius_px
	var inner: float = S.wheel_dead_zone_px
	draw_arc(center, (outer + inner) * 0.5, 0.0, TAU, 64, Color(0.05, 0.05, 0.08, 0.4), outer - inner + 10.0, true)
	for i in n:
		var item: Dictionary = items[i]
		var enabled: bool = item.get("enabled", true)
		var mid := -PI / 2.0 + i * step
		var col: Color = item.color.lightened(0.45) if i == highlighted else item.color.darkened(0.15)
		col.a = 0.95 if i == highlighted else 0.55
		if not enabled:
			col = Color(0.4, 0.4, 0.4, 0.35)
		var points := PackedVector2Array()
		var arc_steps := 16
		for k in arc_steps + 1:
			var a := mid - step / 2.0 + step * k / arc_steps
			points.append(center + Vector2.from_angle(a) * (outer if i != highlighted else outer + 8.0))
		for k in range(arc_steps, -1, -1):
			var a := mid - step / 2.0 + step * k / arc_steps
			points.append(center + Vector2.from_angle(a) * inner)
		draw_colored_polygon(points, col)
		draw_polyline(points, Color(1, 1, 1, 0.35), 1.5, true)
		var at := center + Vector2.from_angle(mid) * (inner + outer) * 0.5
		_text(at + Vector2(0, -2), item.label, 17, Color.WHITE if enabled else Color(1, 1, 1, 0.5))
		if item.has("note"):
			_text(at + Vector2(0, 16), item.note, 12, Color(1, 1, 1, 0.8 if enabled else 0.4))
		if item.has("effect"):
			_text(at + Vector2(0, 30), item.effect, 12, Color(0.75, 1.0, 0.7, 0.85 if enabled else 0.4))


func _text(at: Vector2, text: String, font_size: int, col: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string_outline(_font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.6))
	draw_string(_font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
