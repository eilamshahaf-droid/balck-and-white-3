class_name FloatingNote
extends Label3D
## A line of text that pops up over something in the city, rises and fades:
## how the player sees what just happened ("Saved!", "+3 believers").

const RISE := 3.0          # metres per second
const LIFE := 3.5          # seconds on screen
const FADE := 1.0          # of which the last second fades out

var _age := 0.0


## Float `text` in `color` over `at`, as a child of `parent`.
static func pop(parent: Node, at: Vector3, text: String, color: Color) -> FloatingNote:
	var note := FloatingNote.new()
	note.text = text
	note.modulate = color
	note.position = at
	parent.add_child(note)
	return note


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0012
	font_size = 34
	outline_size = 10
	outline_modulate = Color(0, 0, 0, 0.7)


func _process(delta: float) -> void:
	_age += delta
	position.y += RISE * delta
	modulate.a = clampf((LIFE - _age) / FADE, 0.0, 1.0)
	if _age >= LIFE:
		queue_free()
