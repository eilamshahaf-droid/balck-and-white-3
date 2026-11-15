extends CanvasLayer
## Testing shortcuts, top right (hidden; F1 shows it): add paperwork and money, take the
## buildings nearest the middle of the screen, raise exposure. Not part of the game.

const BELIEF_GIFT := 100.0
const EXPOSURE_GIFT := 0.2
const TAKE_COUNT := 10
const MONEY_GIFT := 200.0

@onready var faith: Faith = get_node("../Faith")
@onready var rig: Node3D = get_node("../CameraRig")
@onready var districts: Districts = get_node("../Districts")
@onready var treasury: Treasury = get_node("../Treasury")

var _panel: PanelContainer


func _ready() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -200
	_panel.offset_top = 150  # below the help text
	_panel.offset_right = -10
	_panel.visible = false  # a tester's tool: F1 brings it up
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Debug (F1 hides)"
	box.add_child(title)
	_button(box, "Paperwork +%d" % roundi(BELIEF_GIFT), func(): faith.belief_pool += BELIEF_GIFT)
	_button(box, "Money +%d" % roundi(MONEY_GIFT), func(): treasury.add_money(MONEY_GIFT))
	_button(box, "Take %d buildings here" % TAKE_COUNT, func(): districts.convert_near(rig.target_pivot, TAKE_COUNT))
	_button(box, "Exposure +%d%%" % roundi(EXPOSURE_GIFT * 100.0), func(): faith.exposure = minf(faith.exposure + EXPOSURE_GIFT, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible


func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space and the arrow keys for the game
	b.pressed.connect(action)
	box.add_child(b)
