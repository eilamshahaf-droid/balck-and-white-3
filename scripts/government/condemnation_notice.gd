class_name CondemnationNotice
extends RigidBody3D
## The notice nailed to a condemned building: a board with the countdown. The hand
## can tear it off (Condemnation charges belief and reopens the building), then it
## is litter in the hand, gone a moment after it is let go.

## The hand grabbed the notice.
signal grabbed

const BOARD := Vector3(2.4, 1.6, 0.12)
const GONE_AFTER := 2.0   # seconds after the hand lets go of a torn notice

var torn := false
var _label := Label3D.new()
var _shown := ""


func build(color: Color) -> void:
	add_to_group("god_grabbable")
	set_meta("surface", &"paper")
	mass = 0.5
	freeze = true
	collision_layer = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BOARD
	shape.shape = box
	add_child(shape)
	var board := MeshInstance3D.new()
	board.mesh = SharedMeshes.box(Vector3.ONE)
	board.scale = BOARD
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	board.material_override = material
	add_child(board)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 40
	_label.outline_size = 12
	_label.no_depth_test = true
	_label.modulate = color.lightened(0.2)
	_label.position = Vector3(0.0, BOARD.y, 0.0)
	add_child(_label)


## Only rebuilds the text when it changes.
func show_line(line: String) -> void:
	if line != _shown:
		_shown = line
		_label.text = line


## Whether the hand may take it now (the notice is up and there is belief for it).
func set_grabbable(on: bool) -> void:
	if on and not is_in_group("god_grabbable"):
		add_to_group("god_grabbable")
	elif not on and is_in_group("god_grabbable") and not torn:
		remove_from_group("god_grabbable")


func on_grabbed() -> void:
	if torn:
		return
	torn = true
	freeze = false
	_label.visible = false
	grabbed.emit()


func on_released(_throw_velocity: Vector3) -> void:
	get_tree().create_timer(GONE_AFTER).timeout.connect(queue_free)
