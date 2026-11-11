class_name ConversionNotes
extends Node3D
## Shows the player who just joined or rose in the cult: "+ Believer",
## "+ Missionary" and so on float up over the person (the rank's name from
## UnitSettings), and "Lost a believer" when one leaves. Only people on the
## street (with a body) get a note, and only so many a second.

const M: MiracleSettings = preload("res://data/miracles.tres")
const U: UnitSettings = preload("res://data/units.tres")
const ABOVE := Vector3(0, 2.6, 0)
const LOST_COLOR := Color(0.7, 0.7, 0.75)

@export var population: Population

var _budget := 0.0


func _ready() -> void:
	population.rank_changed.connect(_on_rank_changed)


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
