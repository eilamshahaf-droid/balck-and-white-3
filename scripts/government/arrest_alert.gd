extends Label
## Top of the screen: the priest is being arrested, how long is left, and a
## reminder of what frees him. Hidden while no arrest is going on.

const REFRESH := 0.25   # seconds; the countdown doesn't need every frame

var _timer := 0.0

@export var arrests: PoliceArrests


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	var left := arrests.seconds_left()
	visible = left > 0.0
	if not visible:
		return
	var line := "POLICE ARE ARRESTING YOUR PRIEST (%d s)\nThrow the officers away with the hand, or scatter them with a miracle" % ceili(left)
	if text != line:
		text = line
