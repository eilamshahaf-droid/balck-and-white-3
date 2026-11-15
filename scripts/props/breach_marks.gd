class_name BreachMarks
extends Node3D
## A line of text over a key building the Fixer has been at: which action he is on, what
## holds him up, or that it is open and waits for a Rep. One label a building.

const S: DistrictSettings = preload("res://data/districts.tres")
const LIFT := 9.0

@export var breaches: Breaches
@export var districts: Districts

var _labels := {}   # building -> Label3D


func _ready() -> void:
	breaches.changed.connect(_refresh)
	breaches.action_started.connect(func(b: Node3D, _step: int) -> void: _refresh(b))
	breaches.opened.connect(_refresh)
	districts.building_changed.connect(func(i: int, _yours: bool) -> void:
		_refresh(districts.buildings[i]))


func _refresh(building: Node3D) -> void:
	if building == null:
		return
	var i := districts.index_of(building)
	var text := ""
	if i >= 0 and districts.is_key(i) and not districts.is_yours(i):
		var done := breaches.actions_done(building)
		if districts.is_key_open(i):
			text = S.breach_open_note
		elif breaches.target == building:
			text = "Fixer: %s (%d of %d)" % [S.breach_action(done), done + 1, S.breach_actions]
			if breaches.stalled != "":
				text += "\n" + breaches.stalled
		elif done > 0:
			text = "Fixer left: %d of %d done" % [done, S.breach_actions]
	var label: Label3D = _labels.get(building)
	if text == "":
		if label:
			label.queue_free()
			_labels.erase(building)
		return
	if label == null:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = S.breach_label_pixel_size
		label.font_size = S.breach_label_font_size
		label.outline_size = 12
		label.modulate = S.breach_line_color
		add_child(label)
		label.global_position = building.global_position \
				+ Vector3.UP * (BuildingBox.size_of(building).y / 2.0 + LIFT)
		_labels[building] = label
	label.text = text
