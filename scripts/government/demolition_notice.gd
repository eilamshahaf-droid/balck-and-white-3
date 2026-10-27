extends Label3D
## The red notice the inspector leaves on a building, with the days (seconds)
## left before the bulldozer comes. Readable from a god's height.

var _shown := -1


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fixed_size = true
	pixel_size = 0.0012
	font_size = 44
	outline_size = 14
	no_depth_test = true
	modulate = Color(1.0, 0.3, 0.25)


## Only rebuilds the text when the whole number changes.
func show_seconds(seconds: float) -> void:
	var whole := ceili(seconds)
	if whole == _shown:
		return
	_shown = whole
	text = "NOTICE OF DEMOLITION\nDept. of Buildings · %d" % whole
