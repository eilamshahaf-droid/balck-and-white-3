extends Node
## The god's two wheels, on top of the hand's movement (god_hand.gd).
##
## Hold the left button still for a moment: a wheel opens around the hand.
## On a building it is the building wheel: divine decrees on your own
## buildings, and the three takeover marks (force, buy, missionaries) on
## everyone else's. Anywhere else, the miracle wheel. The hand stays in the
## middle and points where the mouse goes; letting go signs the decree or
## marks the building (choosing the mark it already has calls it off), or
## puts the miracle in the hand (a glowing orb in the palm). It fills the hand: nothing can be picked up meanwhile.
## The next short click (or long press), on the ground or a building, casts
## it there; a right click puts it away. Dragging still moves the city. A circle drawn with the right button casts water straight away.

const RadialWheel = preload("res://scripts/radial_wheel.gd")
const Sfx = preload("res://scripts/sfx.gd")

enum Mode { NONE, MIRACLES, BUILDING, USES }

## The takeover marks on the wheel, by slice id.
const MARKS := {&"force": Campaigns.Route.FORCE, &"buy": Campaigns.Route.BUY,
		&"preach": Campaigns.Route.PREACH}

@export var campaigns: Campaigns

@onready var hand: Node3D = get_node("../GodHand")
@onready var miracles: Miracles = get_node("../Miracles")
@onready var faith: Node = get_node("../Faith")
@onready var decrees: Decrees = get_node("../Decrees")

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
	hand.tool_clicked.connect(_cast_charged)
	hand.right_clicked.connect(func(): _charge(&""))
	hand.circle_drawn.connect(func(at: Vector2, radius: float): miracles.cast_at_screen(&"water", at, radius))


## The window lost focus with a wheel open: its button-up will never come.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _mode != Mode.NONE:
		_close()


## While a wheel is open it owns the mouse buttons, so the hand never sees the
## release that picks a slice.
func _input(event: InputEvent) -> void:
	if _mode == Mode.NONE or not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_wheel.point_at(event.position)  # where the button came up, not where the mouse is a frame later
		_choose()
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()  # the click that picks from a second wheel
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_close()  # never mind
		get_viewport().set_input_as_handled()


func _open(hit: Dictionary, at: Vector2) -> void:
	if charged != &"":
		_cast_charged(hit)
		return
	_target = hit
	hand.start_pointing(at)
	if hit.collider.is_in_group("buildings"):
		_mode = Mode.BUILDING
		_set_outline(hit.collider, true)
		Sfx.play(get_tree(), hit.position, Sfx.surface_of(hit.collider), 0.4)
		_wheel.open(at, _building_items(hit.collider))
	else:
		_mode = Mode.MIRACLES
		var items: Array[Dictionary] = miracles.wheel_items()
		for item in items:
			var wait: float = miracles.ready_in(item.id)
			var price := "%d belief" % roundi(item.cost)
			item.note = "ready in %ds" % ceili(wait) if wait > 0.0 else price
			item.enabled = wait <= 0.0 and faith.belief_pool >= item.cost
		_wheel.open(at, items)


func _choose() -> void:
	var id: StringName = _wheel.close()
	var building: Node3D = _target.collider if is_instance_valid(_target.collider) and _target.collider.is_in_group("buildings") else null
	if id != &"":
		match _mode:
			Mode.MIRACLES:
				_charge(id)
			Mode.BUILDING:
				if building and MARKS.has(id):
					campaigns.mark(building, MARKS[id])
					Sfx.play(get_tree(), _target.position, &"chime", 0.5)
				elif building and id == &"use":
					# Which use: a second wheel in the same place; the next click picks.
					_mode = Mode.USES
					_wheel.open(_wheel.center, decrees.use_items(building))
					return
				elif building:
					decrees.issue(id, building)
			Mode.USES:
				if building:
					decrees.issue(&"use", building, String(id))
	_close()


func _close() -> void:
	_wheel.visible = false
	_wheel.set_process(false)
	if _mode in [Mode.BUILDING, Mode.USES] and is_instance_valid(_target.collider):
		_set_outline(_target.collider, false)
	_target = {}
	_mode = Mode.NONE
	hand.stop_pointing()


func _cast_charged(hit: Dictionary) -> void:
	var building: Node3D = hit.collider if hit.collider.is_in_group("buildings") else null
	miracles.cast(charged, hit.position, building)
	_charge(&"")


func _charge(kind: StringName) -> void:
	charged = kind
	hand.carrying_tool = kind != &""
	_orb.visible = kind != &""
	if _orb.visible:
		_orb_mat.albedo_color = _colors[kind]
		_glow.light_color = _colors[kind]
		Sfx.play(get_tree(), hand.global_position, &"chime", 0.4)


## Decrees on your own building; the takeover marks on anyone else's. The
## mark a building already has reads "call off".
func _building_items(building: Node3D) -> Array[Dictionary]:
	if decrees.is_yours(building):
		return decrees.wheel_items(building)
	var items: Array[Dictionary] = [
		{"id": &"force", "label": "Skull: Force", "color": Color(0.85, 0.3, 0.3)},
		{"id": &"buy", "label": "$: Buy", "color": Color(0.4, 0.8, 0.4)},
		{"id": &"preach", "label": "Sky Sign: Missionaries", "color": Color(0.5, 0.75, 1.0)},
	]
	var current := campaigns.route_of(building)
	for item in items:
		var route: Campaigns.Route = MARKS[item.id]
		var why := campaigns.why_not(building, route)
		item.note = "call off" if route == current else ("go" if why == "" else why)
		item.enabled = route == current or why == ""
	return items


func _set_outline(building: Node3D, on: bool) -> void:
	for mesh in building.find_children("*", "MeshInstance3D", false, false):
		mesh.material_overlay = _outline if on else null
