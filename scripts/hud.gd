class_name Hud
extends PanelContainer
## Top left, one strip of masking tape with the numbers the player may see, each an
## icon, a number and what comes in a second: paperwork (net of what the Reps cost, so a
## falling pool shows before it is empty), money, followers (and how many sell and keep
## the books), Reps free out of the cap, and the buildings of yours as a bar. The
## exposure has its own dial (ExposureDial). Under the strip, what the hand holds.

const S: UiSettings = preload("res://data/ui.tres")
const U: UnitSettings = preload("res://data/units.tres")

enum Item { PAPERWORK, MONEY, FOLLOWERS, REPS, BUILDINGS }

@export var faith: Faith
@export var tools: HandTools
@export var followers: Followers
@export var treasury: Treasury
@export var districts: Districts
@export var population: Population
@export var upkeep: UnitUpkeep

var _timer := 0.0
var _numbers: Array[Label] = []
var _rates: Array[Label] = []
var _bar := ProgressBar.new()
var _held := Label.new()


func _ready() -> void:
	theme_type_variation = &"TapeStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	add_child(row)
	var kinds := [UiIcon.Kind.PAPERWORK, UiIcon.Kind.MONEY, UiIcon.Kind.FOLLOWER, UiIcon.Kind.REP,
			UiIcon.Kind.BUILDING]
	for i in kinds.size():
		var item := HBoxContainer.new()
		item.add_theme_constant_override(&"separation", 5)
		item.add_child(UiIcon.new(kinds[i]))
		if i == Item.BUILDINGS:
			_bar.theme_type_variation = &"InkBar"
			_bar.show_percentage = false
			_bar.custom_minimum_size = Vector2(S.buildings_bar_width, 10.0)
			_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item.add_child(_bar)
		else:
			var number := Label.new()
			number.theme_type_variation = &"Number"
			item.add_child(number)
			_numbers.append(number)
		var rate := Label.new()
		rate.theme_type_variation = &"Rate"
		rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(rate)
		_rates.append(rate)
		row.add_child(item)
	_held.theme_type_variation = &"HintTape"
	_held.visible = false
	_held.top_level = true
	_held.position = Vector2(S.strip_position.x, S.strip_position.y + S.held_below)
	add_child(_held)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.refresh
	var paperwork := followers.paperwork_rate - upkeep.rate()
	_show(Item.PAPERWORK, "%d" % floori(faith.belief_pool),
			"%+.1f/s  of %d" % [paperwork, roundi(followers.paperwork_cap())], paperwork)
	_show(Item.MONEY, "$%d" % floori(treasury.money),
			"%+.1f/s  of %d" % [treasury.income, roundi(followers.money_cap())], treasury.income)
	_show(Item.FOLLOWERS, "%d" % followers.total,
			"%d sell · %d clerk" % [followers.sellers, followers.clerks], 0.0)
	_show(Item.REPS, "%d" % population.free_rep_count, "/ %d %s" % [followers.rep_cap(),
			U.plural(Resident.Rank.MISSIONARY)], 0.0)
	var mine := districts.converted_buildings().size()
	_bar.max_value = maxi(districts.buildings.size(), 1)
	_bar.value = mine
	_show(Item.BUILDINGS, "", "%d / %d" % [mine, districts.buildings.size()], 0.0)
	var line := ""
	if tools.charged != &"":
		line = "In the hand: %s · click to cast · right click to drop" % String(tools.charged).capitalize()
	if _held.text != line:
		_held.text = line
		_held.visible = line != ""


## Item `i` reads `number` and `rate`; a rate in green when `trend` is above 0, red below.
func _show(i: Item, number: String, rate: String, trend: float) -> void:
	if i < _numbers.size() and _numbers[i].text != number:
		_numbers[i].text = number
	if _rates[i].text != rate:
		_rates[i].text = rate
		_rates[i].theme_type_variation = &"RateUp" if trend > 0.0 \
				else (&"RateDown" if trend < 0.0 else &"Rate")
