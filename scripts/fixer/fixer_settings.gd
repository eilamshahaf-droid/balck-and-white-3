class_name FixerSettings
extends Resource
## The Fixer at a key building (breaches.gd): what his quiet and loud actions cost and
## bring, when exposure stops him, and each key building's own actions. Load with
## load(), not preload(): `sets` is a typed array of a custom class.

@export var tick := 1.0

@export_group("Quiet actions")
## Small cost, small progress: done again and again, with the action's time as the break.
@export var quiet_paperwork := 20.0
@export var quiet_money := 20.0
@export var quiet_exposure := 0.03
## Share of the key building's bar one action fills.
@export_range(0.0, 1.0) var quiet_progress := 0.15
@export var quiet_seconds := 30.0

@export_group("Loud actions")
## Big cost, big progress, and an inspector is sent to the Fixer's door.
@export var loud_paperwork := 60.0
@export var loud_money := 60.0
@export var loud_exposure := 0.12
@export_range(0.0, 1.0) var loud_progress := 0.45
@export var loud_seconds := 30.0

@export_group("Lying low")
## From this exposure on the Fixer starts nothing until it fades.
@export_range(0.0, 1.0) var gate_exposure := 0.7
## Share of a key building's bar lost a minute while the Fixer is not there.
@export_range(0.0, 1.0) var left_fade_per_minute := 0.02
## Share of the bar lost when an inspector at the door finds no paperwork and the Fixer
## is sent back to the Office.
@export_range(0.0, 1.0) var caught_loss := 0.3

@export_group("Look")
@export var line := "Nothing to see here."
@export var line_color := Color(0.75, 0.6, 1.0)
@export var open_note := "Open: send a Rep"
@export var caught_note := "Fixer sent back to the Office"
@export var label_font_size := 34
@export var label_pixel_size := 0.0012

@export_group("Each key building's actions")
@export var sets: Array[FixerActionSet] = []


func paperwork(a: FixerAction) -> float:
	return loud_paperwork if a.loud else quiet_paperwork


func money(a: FixerAction) -> float:
	return loud_money if a.loud else quiet_money


func exposure(a: FixerAction) -> float:
	return loud_exposure if a.loud else quiet_exposure


func progress(a: FixerAction) -> float:
	return loud_progress if a.loud else quiet_progress


func seconds(a: FixerAction) -> float:
	return loud_seconds if a.loud else quiet_seconds


## The actions at the key building called `key`; the first set when none has its name.
func actions_for(key: String) -> Array[FixerAction]:
	for s in sets:
		if s.key == key:
			return s.actions
	return sets[0].actions if not sets.is_empty() else ([] as Array[FixerAction])
