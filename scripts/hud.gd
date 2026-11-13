extends Label
## The numbers the player may see, as a row of cards along the top: paperwork (what
## training, decrees and miracles spend), money and what comes in, followers and how
## many of them hold a role, Reps (free of the cap), buildings of yours, and the
## exposure with the inspectors out. Under
## them, what the hand holds.

const REFRESH := 0.25   # seconds; the numbers don't need to change every frame
const U: UnitSettings = preload("res://data/units.tres")

var _timer := 0.0
var _values: Array[Label] = []

@onready var faith: Faith = get_node("../../Faith")
@onready var tools: HandTools = get_node("../../HandTools")
@onready var followers: Followers = get_node("../../Followers")
@onready var inspectors: Inspectors = get_node("../../Inspectors")
@onready var treasury: Treasury = get_node("../../Treasury")
@onready var districts: Districts = get_node("../../Districts")
@onready var population: Population = get_node("../../Population")


func _ready() -> void:
	var version := "%s %s" % [ProjectSettings.get_setting("application/config/release_stage"),
			ProjectSettings.get_setting("application/config/version")]
	DisplayServer.window_set_title("%s %s" % [ProjectSettings.get_setting("application/config/name"), version])
	var corner_layer := CanvasLayer.new()  # this label is 0 px wide, so anchors need a layer of their own
	add_child(corner_layer)
	var corner := Label.new()
	corner.text = version
	corner.add_theme_font_size_override(&"font_size", 11)
	corner.modulate = Color(1, 1, 1, 0.5)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_left = -8.0
	corner.offset_top = -6.0
	corner_layer.add_child(corner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.position = Vector2(0.0, -52.0)
	add_child(row)
	var titles := ["PAPERWORK", "MONEY", "FOLLOWERS", U.plural(Resident.Rank.MISSIONARY).to_upper(),
			"BUILDINGS", "EXPOSURE"]
	for title: String in titles:
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
	_show(0, "%d  %+.1f/s" % [floori(faith.belief_pool), followers.paperwork_rate])
	_show(1, "$%d  %+.1f/s" % [floori(treasury.money), treasury.income])
	_show(2, "%d  (%d sellers, %d clerks)" % [followers.total, followers.sellers, followers.clerks])
	_show(3, "%d free, %d of %d" % [population.free_rep_count, population.reps_out,
			followers.rep_cap()])
	_show(4, "%d" % districts.converted_buildings().size())
	var count := inspectors.out.size()
	_show(5, "%d%%" % roundi(faith.exposure * 100.0) if count == 0
			else "%d%%  %d inspector%s out" % [roundi(faith.exposure * 100.0), count, "" if count == 1 else "s"])
	var line := ""
	if tools.charged != &"":
		line = "In the hand: %s (click to cast, right-click to drop)" % String(tools.charged).capitalize()
	if text != line:
		text = line


func _show(i: int, value: String) -> void:
	if _values[i].text != value:
		_values[i].text = value
