class_name ActionTags
extends Control
## The god's choices as kraft paper tags hanging in a column on an arc beside the glove's
## fingertip (the UI brief, in place of the round wheel). Each action keeps its own
## place in the column on every building (`UiSettings.tag_slots`), so the hand learns
## where +Floors is; the column goes to the side with open screen and stays on screen.
## The hand points at a tag, which grows; the tag it points at when the button comes up
## is the choice. Pointing back at the fingertip chooses nothing. A tag that can't be
## had is dimmed and says why in red.
##
## Items: {"id": StringName, "label": String, "color": Color, optional "note": String,
## optional "effect": String (a third line), optional "enabled": bool}.

const S: UiSettings = preload("res://data/ui.tres")
const H: HandSettings = preload("res://data/hand_settings.tres")
const THEME: Theme = preload("res://data/ui_theme.tres")

var items: Array[Dictionary] = []
var center := Vector2.ZERO
var highlighted := -1

var _spots: Array[Vector2] = []   # per item, its tag's middle on screen
var _left := false


func _ready() -> void:
	theme = THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func open(at: Vector2, p_items: Array[Dictionary]) -> void:
	center = at
	items = p_items
	# Cover the whole screen, so the drawing is never culled as off-rect.
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	_lay_out()
	highlighted = -1
	visible = true
	set_process(true)
	queue_redraw()


## Close the tags and return the chosen id (&"" for none).
func close() -> StringName:
	visible = false
	set_process(false)
	if highlighted < 0 or not items[highlighted].get("enabled", true):
		return &""
	return items[highlighted].id


func _process(_delta: float) -> void:
	point_at(get_viewport().get_mouse_position())


## Light the tag nearest `screen_pos`.
func point_at(screen_pos: Vector2) -> void:
	var pick := -1
	if screen_pos.distance_to(center) > H.wheel_dead_zone_px:
		var best := S.tag_size.x * 0.6
		for i in items.size():
			var gap := screen_pos.distance_to(_spots[i])
			if gap < best:
				best = gap
				pick = i
	if pick != highlighted:
		highlighted = pick
		queue_redraw()


## Each item's tag: its slot in the column, from the top down, on the arc on the side
## with more screen, the column moved up or down to stay on screen.
func _lay_out() -> void:
	_left = center.x > size.x / 2.0
	var used := {}
	for item in items:
		if S.tag_slots.has(item.id):
			used[int(S.tag_slots[item.id])] = true
	var next := 0
	var slots: Array[int] = []
	var last := 0
	for item in items:
		var slot := -1
		if S.tag_slots.has(item.id):
			slot = int(S.tag_slots[item.id])
		else:
			while used.has(next):
				next += 1
			slot = next
			used[slot] = true
		slots.append(slot)
		last = maxi(last, slot)
	var top := center.y - last * S.tag_spacing / 2.0
	var margin := S.tag_size.y
	top = clampf(top, margin, maxf(margin, size.y - margin - last * S.tag_spacing))
	_spots.clear()
	for slot in slots:
		var y := top + slot * S.tag_spacing
		var dy := clampf(y - center.y, -S.tag_arc_radius, S.tag_arc_radius)
		var dx := sqrt(S.tag_arc_radius * S.tag_arc_radius - dy * dy) + S.tag_size.x * 0.35
		_spots.append(Vector2(center.x + (-dx if _left else dx), y))


func _draw() -> void:
	var tag_size := S.tag_size
	var paper: Texture2D = S.tag_texture
	var side := -1.0 if _left else 1.0
	for i in items.size():
		var item: Dictionary = items[i]
		var enabled: bool = item.get("enabled", true)
		var mid := _spots[i]
		var grow := S.tag_grow if i == highlighted else 1.0
		# The hole faces the fingertip: on the left the tag hangs the other way round.
		var hole := mid - Vector2(tag_size.x * 0.42 * side, 0.0) * grow
		draw_line(center + (hole - center).normalized() * H.wheel_dead_zone_px * 0.6, hole,
				S.ink.lightened(0.3), 1.5, true)
		var tilt := deg_to_rad(S.tag_tilt_degrees) * clampf((mid.y - center.y) / S.tag_arc_radius,
				-1.0, 1.0) * side
		draw_set_transform(mid, tilt, Vector2(side * grow, grow))
		var shade := Color.WHITE if enabled else Color(0.75, 0.72, 0.68, 0.7)
		draw_texture_rect(paper, Rect2(-tag_size / 2.0, tag_size), false, shade)
		draw_set_transform(mid, tilt, Vector2.ONE * grow)
		var text_x := -tag_size.x * 0.3 if not _left else -tag_size.x * 0.46
		var width := tag_size.x * 0.74
		_text(Vector2(text_x, -5.0), width, item.label, &"Heading", 17,
				S.ink if enabled else S.muted)
		if item.has("note"):
			_text(Vector2(text_x, 12.0), width, item.note, &"Label", 12,
					S.ink if enabled else S.red)
		if item.has("effect"):
			_text(Vector2(text_x, 25.0), width, item.effect, &"Label", 11, S.muted)
	draw_set_transform(Vector2.ZERO)


## `text` at `at`, in the theme's `face` font, as big as `font_size` but small enough to
## fit `width`.
func _text(at: Vector2, width: float, text: String, face: StringName, font_size: int,
		color: Color) -> void:
	var font := get_theme_font(&"font", face)
	var px := font_size
	while px > S.tag_min_font and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
