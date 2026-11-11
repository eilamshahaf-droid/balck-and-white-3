class_name DistrictWon
extends CanvasLayer
## The screen that says a district is yours, with one line from the Secretary's
## meeting minutes. The slice ends here: the next stage is not built yet, so the
## player can only keep playing in the district they have.

const S: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts

var _panel: PanelContainer
var _title: Label
var _minute: Label


func _ready() -> void:
	_build()
	districts.district_controlled.connect(_on_district_controlled)


func _on_district_controlled(d: int) -> void:
	_title.text = S.captured_title % districts.district_name(d)
	_minute.text = S.minute_for(d)
	_panel.visible = true


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 14)
	_panel.add_child(box)
	_title = _label(36, S.captured_color)
	box.add_child(_title)
	_minute = _label(18, Color(1, 1, 1, 0.9))
	_minute.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_minute.custom_minimum_size = Vector2(520.0, 0.0)
	box.add_child(_minute)
	var next := _label(14, Color(1, 1, 1, 0.6))
	next.text = S.next_stage_note
	box.add_child(next)
	var button := Button.new()
	button.text = S.keep_playing_label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: _panel.visible = false)
	box.add_child(button)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.modulate = color
	return l
