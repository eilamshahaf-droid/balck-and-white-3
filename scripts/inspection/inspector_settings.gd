class_name InspectorSettings
extends Resource
## Every number of the city's answer: exposure, the inspectors that walk out of key
## buildings on a timer, what they demand, and burying the file.

@export var tick := 0.5

@export_group("Exposure")
## Exposure each Rep at work on a building adds, per minute.
@export var work_exposure_per_minute := 0.03
## Exposure a building taken adds, once.
@export var take_exposure := 0.03
## Exposure that goes away when an inspector catches the Fixer: City Hall is satisfied
## for a while.
@export var satisfied_exposure := 0.12

@export_group("Sending inspectors")
## A clerk of City Hall on a timer: the first comes this many seconds in, then one every
## interval_seconds; exposure sends more at once (1 + floor(exposure x per_exposure)).
@export var first_seconds := 150.0
@export var interval_seconds := 120.0
@export var per_exposure := 3.0
## One who could not get all he asked for comes back to the same building this much later.
@export var return_seconds := 90.0

@export_group("The inspector")
@export var speed := 2.4
@export var mass := 3.0
## Seconds he lies where he landed before he gets up and walks again; every further throw
## of the same inspector makes it this much shorter (the hand's work is Sisyphean).
@export var stun_seconds := 4.0
@export_range(0.0, 1.0) var stun_shortens := 0.25
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
## Paperwork he takes at a building of yours: this much, and this much more for every
## building you hold; each Security level of the building divides it.
@export var demand_paperwork := 15.0
@export var demand_per_building := 1.0
@export var security_step := 0.5

@export_group("Burying the file")
## Paperwork the first time, how it grows each time, and the exposure it removes.
@export var bury_paperwork := 60.0
@export var bury_growth := 1.5
@export var bury_exposure := 0.25

@export_group("Texts")
@export var sent_note := "Inspector on the way"
@export var papers_note := "Papers in order: -%d paperwork"
@export var short_note := "Short of papers: -%d paperwork. He'll be back"
@export var gave_up_note := "Inspector gave up"
@export var good_color := Color(0.75, 0.9, 1.0)
@export var bad_color := Color(1.0, 0.4, 0.35)
