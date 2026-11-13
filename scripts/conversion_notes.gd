class_name ConversionNotes
extends Node3D
## Shows the player who just joined or rose in the cult: "+ Believer",
## "+ Missionary" and so on float up over the person (the rank's name from
## UnitSettings), and "Lost a believer" when one leaves. Only people on the
## street (with a body) get a note, and only so many a second.

const M: MiracleSettings = preload("res://data/miracles.tres")
const U: UnitSettings = preload("res://data/units.tres")
const I: InspectorSettings = preload("res://data/inspectors.tres")
const ABOVE := Vector3(0, 2.6, 0)
const LOST_COLOR := Color(0.7, 0.7, 0.75)

@export var population: Population
@export var campaigns: Campaigns
@export var inspectors: Inspectors

var _budget := 0.0


func _ready() -> void:
	population.rank_changed.connect(_on_rank_changed)
	campaigns.mark_refused.connect(_on_mark_refused)
	inspectors.sent.connect(func(_inspector: Inspector, from: Node3D) -> void:
		_over(from, I.sent_note, I.bad_color))
	inspectors.papers_shown.connect(func(b: Node3D, cost: float) -> void:
		_over(b, I.papers_note % roundi(cost), I.good_color))
	inspectors.rep_sent_home.connect(func(b: Node3D, _rep: Resident) -> void:
		_over(b, I.rep_lost_note, I.bad_color))
	inspectors.audit_passed.connect(func(b: Node3D, cost: float) -> void:
		_over(b, I.audit_note % roundi(cost), I.good_color))
	inspectors.turned_back.connect(func(b: Node3D) -> void:
		_over(b, I.turned_back_note, I.bad_color))
	inspectors.gave_up.connect(func(at: Vector3) -> void:
		FloatingNote.pop(self, at + ABOVE, I.gave_up_note, I.good_color))


func _physics_process(delta: float) -> void:
	_budget = minf(_budget + M.notes_per_second * delta, M.notes_per_second)


func _on_rank_changed(r: Resident, old: Resident.Rank, new: Resident.Rank) -> void:
	if r.body == null or not is_instance_valid(r.body) or _budget < 1.0:
		return
	var text := "+ " + U.title(new)
	var color := U.color(new)
	if new < old:
		text = "Lost a " + U.title(old).to_lower()
		color = LOST_COLOR
	_budget -= 1.0
	FloatingNote.pop(self, r.body.global_position + ABOVE, text, color)


func _on_mark_refused(building: Node3D, why: String) -> void:
	_over(building, why, LOST_COLOR)


func _over(building: Node3D, line: String, color: Color) -> void:
	var top := BuildingBox.size_of(building).y / 2.0
	FloatingNote.pop(self, building.global_position + Vector3.UP * top + ABOVE, line, color)
