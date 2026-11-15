extends CanvasLayer
## Testing shortcuts, top right (hidden; F1 shows it): add paperwork and money, take the
## buildings nearest the middle of the screen, raise exposure; and a log of money and
## paperwork in and out each minute, for playtests. Not part of the game.

const BELIEF_GIFT := 100.0
const EXPOSURE_GIFT := 0.2
const TAKE_COUNT := 10
const MONEY_GIFT := 200.0
const LOG_SECONDS := 60.0
const LOG_LINES := 12
const ROOM_DESIGNER := "res://scenes/room_designer.tscn"

@onready var faith: Faith = get_node("../Faith")
@onready var rig: Node3D = get_node("../CameraRig")
@onready var districts: Districts = get_node("../Districts")
@onready var treasury: Treasury = get_node("../Treasury")

var _panel: PanelContainer
var _log: Label
var _lines: PackedStringArray = []
var _minute := 0
var _money_in := 0.0
var _money_out := 0.0
var _paper_out := 0.0
var _last_money := 0.0
var _last_paper := 0.0


func _ready() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -200
	_panel.offset_top = 150  # below the help text
	_panel.offset_right = -10
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # the log widens it leftwards
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
	_button(box, "Room designer", func(): get_tree().change_scene_to_file(ROOM_DESIGNER))
	var head := Label.new()
	head.text = "Per minute: money in/out, paperwork in/out"
	box.add_child(head)
	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 12)
	box.add_child(_log)
	_last_money = treasury.money
	_last_paper = faith.belief_pool
	treasury.money_changed.connect(_on_money_changed)
	faith.spent.connect(func(amount: float, _use: StringName) -> void: _paper_out += amount)
	var timer := Timer.new()
	timer.wait_time = LOG_SECONDS
	timer.timeout.connect(_log_minute)
	add_child(timer)
	timer.start()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible


func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space and the arrow keys for the game
	b.pressed.connect(action)
	box.add_child(b)


func _on_money_changed(money: float) -> void:
	var change := money - _last_money
	if change > 0.0:
		_money_in += change
	else:
		_money_out -= change
	_last_money = money


## One line for the minute that just ended. Paperwork earned is the change plus what was
## spent, since it accrues every frame with no signal of its own.
func _log_minute() -> void:
	_minute += 1
	var paper := faith.belief_pool
	var paper_in := paper - _last_paper + _paper_out
	_lines.append("m%d  $%d (+%d -%d)  pp %d (+%d -%d)" % [_minute, roundi(treasury.money),
			roundi(_money_in), roundi(_money_out), roundi(paper), roundi(paper_in),
			roundi(_paper_out)])
	if _lines.size() > LOG_LINES:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)
	_last_paper = paper
	_money_in = 0.0
	_money_out = 0.0
	_paper_out = 0.0
