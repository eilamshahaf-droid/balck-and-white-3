extends Label
## The meters the player may see, as a row of cards along the top: belief (what
## miracles and missionaries spend), money (what buying and decrees spend, and
## what comes in), believers, buildings of yours and exposure. Under them, the
## miracle power under the hand and what the hand holds. Belief itself stays
## hidden (B shows it, for debugging).

const REFRESH := 0.25   # seconds; the numbers don't need to change every frame

var _timer := 0.0
var _values: Array[Label] = []

@onready var faith: Node = get_node("../../Faith")
@onready var tools: Node = get_node("../../HandTools")
@onready var miracles: Node = get_node("../../Miracles")
@onready var treasury: Treasury = get_node("../../Treasury")
@onready var districts: Districts = get_node("../../Districts")


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.position = Vector2(0.0, -52.0)
	add_child(row)
	for title in ["BELIEF", "MONEY", "BELIEVERS", "BUILDINGS", "EXPOSURE"]:
		var card := PanelContainer.new()
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", -4)
		card.add_child(box)
		var caption := Label.new()
		caption.text = title
		caption.add_theme_font_size_override(&"font_size", 11)
		caption.modulate = Color(1, 1, 1, 0.7)
		box.add_child(caption)
		var value := Label.new()
		value.add_theme_font_size_override(&"font_size", 22)
		box.add_child(value)
		_values.append(value)
		row.add_child(card)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_show(0, "%d" % floori(faith.belief_pool))
	_show(1, "$%d  %+.1f/s" % [floori(treasury.money), treasury.income])
	_show(2, "%d" % faith.believers)
	_show(3, "%d" % districts.converted_buildings().size())
	_show(4, "%d%%" % roundi(faith.exposure * 100.0))
	var line := "Miracle power here: %d%%" % roundi(miracles.power_here * 100.0)
	if tools.charged != &"":
		line += "    In the hand: %s (click to cast, right-click to drop)" % String(tools.charged).capitalize()
	if text != line:
		text = line


func _show(i: int, value: String) -> void:
	if _values[i].text != value:
		_values[i].text = value
