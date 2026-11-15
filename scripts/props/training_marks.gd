class_name TrainingMarks
extends Node3D
## A meter over the Office while someone trains there (who, how far, how long still),
## and a badge over the head of every Rep and the Fixer out in the street, so the player
## can tell them from the crowd.

const U: UnitSettings = preload("res://data/units.tres")
const TICK := 0.5   # seconds; the text and the badges don't need every frame
const LIFT := 6.0
const BADGE := &"RankBadge"

@export var population: Population
@export var districts: Districts

var _meter: Label3D
var _timer := 0.0


func _ready() -> void:
	population.rank_changed.connect(_on_rank_changed)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = TICK
	var lines := PackedStringArray()
	for r in population.residents:
		if r.job == Resident.Job.TRAIN:
			var full := U.missionary_time if r.training_for == Resident.Rank.MISSIONARY \
					else U.agent_time
			lines.append(U.training_line % [U.title(r.training_for),
					roundi((1.0 - r.training_left / full) * 100.0), ceili(r.training_left)])
		elif U.badge(r.rank) != "" and is_instance_valid(r.body) \
				and r.body.get_node_or_null(NodePath(BADGE)) == null:
			_add_badge(r)
	_show_meter("\n".join(lines))


func _show_meter(text: String) -> void:
	if _meter == null:
		var office := districts.start_building()
		if office == null:
			return
		_meter = _label(U.training_font_size, U.training_pixel_size, U.training_color)
		add_child(_meter)
		_meter.global_position = office.global_position \
				+ Vector3.UP * (BuildingBox.size_of(office).y / 2.0 + LIFT)
	if _meter.text != text:
		_meter.text = text


## A new rank takes the old badge off; the next tick gives the new one, if any.
func _on_rank_changed(r: Resident, _old: Resident.Rank, _new: Resident.Rank) -> void:
	if is_instance_valid(r.body):
		var old := r.body.get_node_or_null(NodePath(BADGE))
		if old:
			old.free()


func _add_badge(r: Resident) -> void:
	var badge := _label(U.badge_font_size, U.badge_pixel_size, U.badge_color)
	badge.name = BADGE
	badge.text = U.badge(r.rank)
	badge.position = Vector3.UP * U.badge_lift
	r.body.add_child(badge)


func _label(size: int, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = pixel
	label.font_size = size
	label.outline_size = 10
	label.modulate = color
	return label
