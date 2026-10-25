extends Node
## The god's two wheels, on top of the hand's movement (god_hand.gd).
##
## Right button held still: the miracle wheel. The chosen miracle stays in the
## hand (it glows in the miracle's colour); each short left click casts it
## there, until a short right click puts it away. Dragging, lifting and
## throwing work as usual meanwhile.
## Left button held still on a building: the sign wheel for that building.
## A circle drawn with the right button still casts water straight away.

const DivineSign = preload("res://scripts/divine_sign.gd")
const RadialWheel = preload("res://scripts/radial_wheel.gd")
const Sfx = preload("res://scripts/sfx.gd")

enum Mode { NONE, MIRACLES, SIGNS }

@onready var hand: Node3D = get_node("../GodHand")
@onready var miracles: Node = get_node("../Miracles")
@onready var faith: Node = get_node("../Faith")

## The miracle in the hand (&"" for none).
var charged := &""

var _wheel: RadialWheel
var _mode := Mode.NONE
var _sign_target: Node3D
var _outline := StandardMaterial3D.new()
var _glow: OmniLight3D
var _orb: MeshInstance3D
var _orb_mat := StandardMaterial3D.new()
var _colors := {}   # miracle id -> colour


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_wheel = RadialWheel.new()
	layer.add_child(_wheel)
	for item in miracles.wheel_items():
		_colors[item.id] = item.color

	_outline.albedo_color = Color(1.0, 0.9, 0.5)
	_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline.grow = true
	_outline.grow_amount = 0.3

	# The charged miracle: a small glowing orb in the palm.
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	_orb = MeshInstance3D.new()
	_orb.mesh = sphere
	_orb.material_override = _orb_mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.position = Vector3(0, -0.6, 0.6)
	_orb.visible = false
	hand.add_child(_orb)
	_glow = OmniLight3D.new()
	_glow.omni_range = 8.0
	_glow.light_energy = 2.0
	_glow.visible = false
	_orb.add_child(_glow)

	hand.wheel_requested.connect(_open_miracles)
	hand.building_held.connect(_open_signs)
	hand.spot_clicked.connect(func(at: Vector2): miracles.cast_at_screen(charged, at))
	hand.right_clicked.connect(func(): _charge(&""))
	hand.circle_drawn.connect(func(at: Vector2, radius: float): miracles.cast_at_screen(&"water", at, radius))


## While a wheel is open it owns the mouse buttons, so the hand never sees the
## release that picks a slice.
func _input(event: InputEvent) -> void:
	if _mode == Mode.NONE or not event is InputEventMouseButton:
		return
	var button := MOUSE_BUTTON_RIGHT if _mode == Mode.MIRACLES else MOUSE_BUTTON_LEFT
	if event.button_index == button and not event.pressed:
		_wheel.point_at(event.position)  # where the button came up, not where the mouse is a frame later
		_choose()
		get_viewport().set_input_as_handled()
	elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and event.pressed:
		_close()  # the other button: never mind
		get_viewport().set_input_as_handled()


func _open_miracles(at: Vector2) -> void:
	var items: Array[Dictionary] = miracles.wheel_items()
	for item in items:
		item.note = "%d belief" % roundi(item.cost)
		item.enabled = faith.belief_pool >= item.cost
	_mode = Mode.MIRACLES
	_wheel.open(at, items)


func _open_signs(building: Node3D, at: Vector2) -> void:
	_mode = Mode.SIGNS
	_sign_target = building
	_set_outline(building, true)
	Sfx.play(get_tree(), building.global_position, Sfx.surface_of(building), 0.4)
	_wheel.open(at, DivineSign.wheel_items())


func _choose() -> void:
	var id := _wheel.close()
	match _mode:
		Mode.MIRACLES:
			if id != &"":
				_charge(id)
		Mode.SIGNS:
			if id != &"" and is_instance_valid(_sign_target):
				DivineSign.mark(_sign_target, id)
				Sfx.play(get_tree(), _sign_target.global_position, &"chime", 0.5)
	_close()


func _close() -> void:
	_wheel.visible = false
	_wheel.set_process(false)
	if is_instance_valid(_sign_target):
		_set_outline(_sign_target, false)
	_sign_target = null
	_mode = Mode.NONE


func _charge(kind: StringName) -> void:
	charged = kind
	hand.spot_tool_active = kind != &""
	_orb.visible = hand.spot_tool_active
	_glow.visible = hand.spot_tool_active
	if hand.spot_tool_active:
		_orb_mat.albedo_color = _colors[kind]
		_glow.light_color = _colors[kind]


func _set_outline(building: Node3D, on: bool) -> void:
	for mesh in building.find_children("*", "MeshInstance3D", false, false):
		mesh.material_overlay = _outline if on else null
