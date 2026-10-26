extends CanvasLayer
## Testing shortcuts, top right (F1 hides it): convert or lose believers,
## move all believers to where the camera looks, fill the belief pool, raise
## exposure (to call City Hall), take buildings and switch the claim markers. Not part of the game; there to make testing quick.

const B = preload("res://data/balance.tres")
const STEP := 5
const BELIEF_GIFT := 100.0
const EXPOSURE_GIFT := 0.2
const TAKE_COUNT := 10

@onready var faith: Node = get_node("../Faith")
@onready var rig: Node3D = get_node("../CameraRig")
@onready var population: Node = get_node("../Population")
@onready var districts: Node = get_node("../Districts")
@onready var district_view: DistrictView = get_node("../DistrictView")

var _panel: PanelContainer


func _ready() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -200
	_panel.offset_top = 150  # below the help text
	_panel.offset_right = -10
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Debug (F1 hides)"
	box.add_child(title)
	_button(box, "Believers +%d" % STEP, func(): _convert(STEP))
	_button(box, "Believers -%d" % STEP, func(): _unconvert(STEP))
	_button(box, "Believers come here", _gather_here)
	_button(box, "Belief +%d" % roundi(BELIEF_GIFT), func(): faith.belief_pool += BELIEF_GIFT)
	_button(box, "Exposure +%d%%" % roundi(EXPOSURE_GIFT * 100.0), func(): faith.exposure = minf(faith.exposure + EXPOSURE_GIFT, 1.0))
	_button(box, "Take %d buildings here" % TAKE_COUNT, func(): districts.convert_near(rig.target_pivot, TAKE_COUNT))
	_button(box, "Markers: plates / beacons", func(): district_view.toggle_style())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible


func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space and the arrow keys for the game
	b.pressed.connect(action)
	box.add_child(b)


## Turn the `count` non-believers nearest to where the camera looks into believers.
func _convert(count: int) -> void:
	var people := _people_by_distance(false)
	for c in people.slice(0, count):
		c.belief = randf_range(0.7, 0.95)
		c.skepticism = randf_range(0.0, 0.3)


## Turn the `count` believers farthest from where the camera looks into doubters.
func _unconvert(count: int) -> void:
	var people := _people_by_distance(true)
	people.reverse()
	for c in people.slice(0, count):
		c.belief = randf_range(-0.2, 0.2)


## Every believer moves into the home nearest the camera's centre.
func _gather_here() -> void:
	var home: Node3D = population.home_near(rig.target_pivot)
	for c in _people_by_distance(true):
		if c.can_answer() and c.resident.id >= 0:
			population.move_home(c.resident, home)


func _people_by_distance(believers: bool) -> Array:
	var p: Vector3 = rig.target_pivot
	var out := get_tree().get_nodes_in_group("citizens").filter(
			func(c): return (c.belief > B.believer_threshold) == believers)
	out.sort_custom(func(a, b): return a.global_position.distance_to(p) < b.global_position.distance_to(p))
	return out
