class_name InspectorSettings
extends Resource
## Every number of the city's answer (round B of the model): exposure, the inspectors
## that walk out of key buildings, what they demand, and burying the file.

@export var tick := 0.5

@export_group("Exposure")
## Exposure each Rep at work on a building adds, per minute.
@export var work_exposure_per_minute := 0.016
## Exposure a building taken adds, once.
@export var take_exposure := 0.015
## Exposure that goes away when an inspector gets his way (a Rep sent home, a building
## lost): City Hall is satisfied for a while.
@export var satisfied_exposure := 0.12

@export_group("Sending inspectors")
## Seconds between inspectors with no exposure, and at full exposure.
@export var spawn_seconds := 50.0
@export var spawn_seconds_min := 15.0
## Seconds before the very first one, so the first building is taken in peace.
@export var first_seconds := 90.0
## Inspectors out at once with no exposure, and how many more at full exposure.
@export var max_base := 1
@export var max_extra := 3
## From this exposure on, some inspectors audit a building of yours instead of a Rep.
@export_range(0.0, 1.0) var audit_from := 0.35
@export_range(0.0, 1.0) var audit_chance := 0.4

@export_group("The inspector")
@export var speed := 2.4
@export var mass := 3.0
## Seconds he lies where he landed before he gets up and walks again.
@export var stun_seconds := 4.0
## Seconds after leaving his office that he gives up and goes home.
@export var patience_seconds := 150.0
## He has arrived this close to the door he is after.
@export var arrive_radius := 2.5
@export var coat_color := Color(0.45, 0.4, 0.3)
@export var skin_color := Color(0.9, 0.75, 0.6)
@export var alert_color := Color(1.0, 0.25, 0.2)
@export var alert_text := "! INSPECTOR"
@export var alert_font_size := 40
@export var alert_pixel_size := 0.0012

@export_group("What he demands")
## Paperwork a Rep must show, with no exposure; times 1 + exposure * demand_exposure.
@export var demand_paperwork := 25.0
@export var demand_exposure := 1.0
## Paperwork an audit of an ordinary building of yours costs; a bigger building costs
## more (by its room against ordinary_room), each Security level divides it.
@export var audit_paperwork := 40.0
@export var ordinary_room := 12.0
@export var security_step := 0.5

@export_group("Burying the file")
## Paperwork the first time, how it grows each time, and the exposure it removes.
@export var bury_paperwork := 60.0
@export var bury_growth := 1.5
@export var bury_exposure := 0.25

@export_group("Texts")
@export var sent_note := "Inspector on the way"
@export var papers_note := "Papers in order: -%d paperwork"
@export var rep_lost_note := "No papers. Rep sent home"
@export var audit_note := "Audit passed: -%d paperwork"
@export var turned_back_note := "Audit failed. Building lost"
@export var gave_up_note := "Inspector gave up"
@export var good_color := Color(0.75, 0.9, 1.0)
@export var bad_color := Color(1.0, 0.4, 0.35)
