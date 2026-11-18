class_name ExposureDial
extends Control
## Top right, a round paper dial with a red rim: a red wedge grows with the exposure,
## and under the percentage the time to the next inspector, or ON HIS WAY while one
## is out (the UI brief).

const S: UiSettings = preload("res://data/ui.tres")
const SEGMENTS := 48

@export var faith: Faith
@export var inspectors: Inspectors

var _timer := 0.0
var _share := 0.0
var _line := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * S.dial_size
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -S.dial_size - S.dial_margin
	offset_right = -S.dial_margin
	offset_top = S.dial_margin
	offset_bottom = S.dial_margin + S.dial_size


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.refresh
	var share := clampf(faith.exposure, 0.0, 1.0)
	var line := "ON HIS WAY" if not inspectors.out.is_empty() \
			else "INSPECTOR %d:%02d" % [floori(inspectors.next_in / 60.0), ceili(inspectors.next_in) % 60]
	if not is_equal_approx(share, _share) or line != _line:
		_share = share
		_line = line
		queue_redraw()


func _draw() -> void:
	var half := S.dial_size / 2.0
	var mid := Vector2.ONE * half
	var paper := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in SEGMENTS:
		var p := mid + Vector2.from_angle(TAU * i / SEGMENTS) * half
		paper.append(p)
		uvs.append(p / S.dial_size)
	draw_colored_polygon(paper, Color.WHITE, uvs, S.dial_paper)
	if _share > 0.0:
		var wedge := PackedVector2Array([mid])
		var steps := maxi(2, ceili(SEGMENTS * _share))
		for i in steps + 1:
			wedge.append(mid + Vector2.from_angle(-PI / 2.0 + TAU * _share * i / steps) * (half - S.dial_rim))
		var red := S.red
		red.a = S.dial_wedge_alpha
		draw_colored_polygon(wedge, red)
	draw_arc(mid, half - S.dial_rim / 2.0, 0.0, TAU, SEGMENTS, S.red, S.dial_rim, true)
	for i in SEGMENTS:
		if i % 2 == 0:
			draw_arc(mid, half - S.dial_rim * 2.2, TAU * i / SEGMENTS, TAU * (i + 1) / SEGMENTS, 3,
					S.red, 1.0, true)
	_centred(&"Label", &"Caption", "EXPOSURE", half - 22.0, S.ink)
	_centred(&"Number", &"Number", "%d%%" % roundi(_share * 100.0), half + 8.0, S.ink)
	_centred(&"Label", &"Caption", _line, half + 28.0, S.red)


## `text` centred across the dial with its baseline at `y`, in the font of the theme's
## `face` type at the size of its `sized` type.
func _centred(face: StringName, sized: StringName, text: String, y: float, color: Color) -> void:
	var font := get_theme_font(&"font", face)
	var size_px := get_theme_font_size(&"font_size", sized)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(font, Vector2((S.dial_size - w) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size_px, color)
