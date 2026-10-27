class_name ConversionNotes
extends Node3D
## Shows the player who just came to believe: "+ Believer" or "Zealot!" floats
## up over the person, and "Lost a believer" when one drifts away. Only people
## on the street (with a body) get a note, and only so many a second.

const M: MiracleSettings = preload("res://data/miracles.tres")
const ABOVE := Vector3(0, 2.6, 0)

@export var population: Population

var _budget := 0.0


func _ready() -> void:
	population.stage_changed.connect(_on_stage_changed)


func _physics_process(delta: float) -> void:
	_budget = minf(_budget + M.notes_per_second * delta, M.notes_per_second)


func _on_stage_changed(r: Resident, old: int, new: int) -> void:
	if r.body == null or not is_instance_valid(r.body) or _budget < 1.0:
		return
	var text := ""
	var color := Color.WHITE
	if new == Resident.Stage.ZEALOT and old < new:
		text = "Zealot!"
		color = Color(1.0, 0.5, 0.2)
	elif new == Resident.Stage.BELIEVER and old < new:
		text = "+ Believer"
		color = Color(1.0, 0.85, 0.3)
	elif old >= Resident.Stage.BELIEVER and new < Resident.Stage.BELIEVER:
		text = "Lost a believer"
		color = Color(0.7, 0.7, 0.75)
	if text != "":
		_budget -= 1.0
		FloatingNote.pop(self, r.body.global_position + ABOVE, text, color)
