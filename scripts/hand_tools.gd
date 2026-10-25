extends Node
## The god's two wheels, on top of the hand's movement (god_hand.gd).
##
## Hold the left button still for a moment: a wheel opens around the hand.
## On a building it is the sign wheel; anywhere else, the miracle wheel. The
## hand stays in the middle and points where the mouse goes; letting go
## gives the sign to the building, or puts the miracle in the hand (a glowing
## orb in the palm). The next long press, on the ground or a building, casts
## it there; a right click puts it away. Moving, lifting and throwing work as
## usual meanwhile. A circle drawn with the right button casts water straight away.

const M = preload("res://data/miracles.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")
const RadialWheel = preload("res://scripts/radial_wheel.gd")
const Sfx = preload("res://scripts/sfx.gd")

enum Mode { NONE, MIRACLES, SIGNS }

@onready var hand: Node3D = get_node("../GodHand")
@onready var miracles: Node = get_node("../Miracles")
@onready var faith: Node = get_node("../Faith")

var _wheel: RadialWheel
var _mode := Mode.NONE
var _target := {}          # the raycast hit the wheel was opened on
var _outline := StandardMaterial3D.new()
## The miracle in the hand (&"" for none).
var charged := &""
var _orb: MeshInstance3D
var _orb_mat := StandardMaterial3D.new()
var _glow: OmniLight3D
var _colors := {}   # miracle id -> colour


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10  # above the HUD and the art style's screen pass
	add_child(layer)
	_wheel = RadialWheel.new()
	layer.add_child(_wheel)

	_outline.albedo_color = Color(1.0, 0.9, 0.5)
	_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline.grow = true
	_outline.grow_amount = 0.3

	# The charged miracle: a small glowing orb in the palm.
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
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
	_orb.add_child(_glow)
	for item in miracles.wheel_items():
		_colors[item.id] = item.color

	hand.long_pressed.connect(_open)
	hand.right_clicked.connect(func(): _charge(&""))
	hand.circle_drawn.connect(func(at: Vector2, radius: float): miracles.cast_at_screen(&"water", at, radius))


## While a wheel is open it owns the mouse buttons, so the hand never sees the
## release that picks a slice.
func _input(event: InputEvent) -> void:
	if _mode == Mode.NONE or not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_wheel.point_at(event.position)  # where the button came up, not where the mouse is a frame later
		_choose()
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_close()  # never mind
		get_viewport().set_input_as_handled()


func _open(hit: Dictionary, at: Vector2) -> void:
	if charged != &"":
		var building: Node3D = hit.collider if hit.collider.is_in_group("buildings") else null
		miracles.cast(charged, hit.position, building)
		_charge(&"")
		return
	_target = hit
	hand.start_pointing(at)
	if hit.collider.is_in_group("buildings"):
		_mode = Mode.SIGNS
		_set_outline(hit.collider, true)
		Sfx.play(get_tree(), hit.position, Sfx.surface_of(hit.collider), 0.4)
		_wheel.open(at, DivineSign.wheel_items())
	else:
		_mode = Mode.MIRACLES
		var items: Array[Dictionary] = miracles.wheel_items()
		for item in items:
			item.note = "%d belief" % roundi(item.cost)
			item.enabled = faith.belief_pool >= item.cost
		_wheel.open(at, items)


func _choose() -> void:
	var id: StringName = _wheel.close()
	var building: Node3D = _target.collider if is_instance_valid(_target.collider) and _target.collider.is_in_group("buildings") else null
	if id != &"":
		match _mode:
			Mode.MIRACLES:
				_charge(id)
			Mode.SIGNS:
				if building and (id == &"clear" or faith.spend(M.sign_cost)):
					DivineSign.mark(building, id)
					if id != &"clear":
						faith.exposure = minf(faith.exposure + M.sign_exposure, 1.0)
					Sfx.play(get_tree(), _target.position, &"chime", 0.5)
	_close()


func _close() -> void:
	_wheel.visible = false
	_wheel.set_process(false)
	if _mode == Mode.SIGNS and is_instance_valid(_target.collider):
		_set_outline(_target.collider, false)
	_target = {}
	_mode = Mode.NONE
	hand.stop_pointing()


func _charge(kind: StringName) -> void:
	charged = kind
	_orb.visible = kind != &""
	if _orb.visible:
		_orb_mat.albedo_color = _colors[kind]
		_glow.light_color = _colors[kind]
		Sfx.play(get_tree(), hand.global_position, &"chime", 0.4)


func _set_outline(building: Node3D, on: bool) -> void:
	for mesh in building.find_children("*", "MeshInstance3D", false, false):
		mesh.material_overlay = _outline if on else null
