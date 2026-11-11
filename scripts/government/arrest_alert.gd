extends Label
## Top of the screen: the Vandalist is being arrested (how long is left, and what frees
## him), or he is in jail (how long, and a button to pay bail). Hidden otherwise.

const REFRESH := 0.25   # seconds; the countdown doesn't need every frame
const A: AwarenessSettings = preload("res://data/awareness.tres")
const U: UnitSettings = preload("res://data/units.tres")

@export var arrests: PoliceArrests

var _timer := 0.0
var _bail: Button


func _ready() -> void:
	visible = false
	_bail = Button.new()
	_bail.text = "Pay bail ($%d)" % roundi(A.bail_money)
	_bail.position = Vector2(size.x / 2.0 - 80.0, size.y + 4.0)
	_bail.custom_minimum_size = Vector2(160.0, 0.0)
	_bail.pressed.connect(func() -> void: arrests.bail())
	add_child(_bail)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	var title := U.title(Resident.Rank.AGENT).to_upper()
	var line := ""
	var arresting := arrests.seconds_left()
	var jail := arrests.jail_left()
	if arresting > 0.0:
		line = "POLICE ARE ARRESTING YOUR %s (%d s)\nThrow the officers away with the hand (%d belief), or scatter them with a miracle" \
				% [title, ceili(arresting), roundi(A.rescue_belief)]
	elif jail > 0.0:
		line = "YOUR %s IS IN JAIL (%d s)\nPeople near the arrest side with the martyr" \
				% [title, ceili(jail)]
	visible = line != ""
	_bail.visible = arresting <= 0.0 and jail > 0.0
	if text != line:
		text = line
