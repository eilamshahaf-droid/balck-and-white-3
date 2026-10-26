extends CanvasLayer
## Testing shortcuts, top right (F1 hides it): convert or lose believers,
## move all believers to where the camera looks, fill the belief pool, and
## set the god's path. Not part of the game; there to make testing quick.

const B = preload("res://data/balance.tres")
const STEP := 5
const BELIEF_GIFT := 100.0

@onready var city: Node3D = get_parent()
@onready var faith: Node = get_node("../Faith")
@onready var rig: Node3D = get_node("../CameraRig")

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
	_button(box, "Path: good", func(): _set_path(&"good"))
	_button(box, "Path: evil", func(): _set_path(&"evil"))
	_button(box, "Path: neutral", func(): _set_path(&"neutral"))


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


## Every believer moves house to the corner nearest the camera's centre.
func _gather_here() -> void:
	var corner: Vector2i = city.nearest_grid(rig.target_pivot)
	for c in _people_by_distance(true):
		if not c.can_answer():
			continue
		c.home = corner
		c.grid = corner
		c.global_position = city.intersection(corner) + c.lane_offset + Vector3.UP * 0.1
		c.resume_walking()


func _set_path(path: StringName) -> void:
	faith.good_deeds = 0
	faith.evil_deeds = 0
	if path == &"good":
		faith.good_deeds = B.path_lead
	elif path == &"evil":
		faith.evil_deeds = B.path_lead


func _people_by_distance(believers: bool) -> Array:
	var p: Vector3 = rig.target_pivot
	var out := get_tree().get_nodes_in_group("citizens").filter(
			func(c): return (c.belief > B.believer_threshold) == believers)
	out.sort_custom(func(a, b): return a.global_position.distance_to(p) < b.global_position.distance_to(p))
	return out
