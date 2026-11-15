class_name MissionCard
extends PanelContainer
## The one thing to do next, as a card with a progress bar, in place of paragraphs of
## help. The first ten minutes teach one thing at a time (GDD "The first ten minutes"):
## take the first building, plan the Office, throw the inspector, train the Fixer and open
## a key building; then the goal, the key buildings of the district. It reads the game's
## state a few times a second; texts are in data/districts.tres ("Missions").

const S: DistrictSettings = preload("res://data/districts.tres")
const U: UnitSettings = preload("res://data/units.tres")
const REFRESH := 0.25

@export var districts: Districts
@export var population: Population
@export var campaigns: Campaigns
@export var progress: DistrictProgress
@export var inspectors: Inspectors
@export var breaches: Breaches
@export var menus: BuildingMenus

var _timer := 0.0
var _title := Label.new()
var _hint := Label.new()
var _bar := ProgressBar.new()
var _planned := false   # the player has opened the rooms of a building
var _threw := false     # the player has thrown an inspector


func _ready() -> void:
	menus.rooms_requested.connect(func(_b: Node3D) -> void: _planned = true)
	inspectors.thrown.connect(func(_i: Inspector) -> void: _threw = true)
	var box := VBoxContainer.new()
	add_child(box)
	_title.add_theme_font_size_override(&"font_size", 20)
	_title.add_theme_color_override(&"font_color", S.captured_color)
	box.add_child(_title)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = S.mission_width
	box.add_child(_hint)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 10.0
	box.add_child(_bar)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = REFRESH
	var d := districts.start_district()
	var held := districts.converted_buildings().size() - 1   # the Office is not taken
	var working := _best_meter()
	if districts.is_controlled(d):
		_show(S.mission_won, "", 1.0)
	elif not _threw and not inspectors.out.is_empty():
		_show(S.mission_inspector, S.mission_inspector_hint, 0.0)
	elif held <= 0:
		_show(S.mission_first, S.mission_first_hint, maxf(working, 0.0))
	elif not _planned:
		_show(S.mission_rooms, S.mission_rooms_hint, 0.0)
	elif held < S.mission_fixer_from and population.agent_count == 0:
		_show_reps(working)
	elif population.agent_count == 0:
		_show(S.mission_fixer, S.mission_fixer_hint,
				population.training_progress(Resident.Rank.AGENT))
	elif _keys_open(d) == 0:
		_show(S.mission_open, S.mission_open_hint,
				breaches.bar_of(breaches.target) if breaches.target else 0.0)
	elif working >= 0.0:
		_show(S.mission_take, S.mission_take_hint, working)
	else:
		var all := 0
		var mine := 0
		for k in districts.keys:
			if districts.district_of(k) == d:
				all += 1
				mine += 1 if districts.is_yours(k) else 0
		_show(S.mission_keys % [mine, all], S.mission_district_hint, progress.value(d))


## Take buildings with Reps: one at work, one free to send, or one to train.
func _show_reps(working: float) -> void:
	if working >= 0.0:
		_show(S.mission_take, S.mission_take_hint, working)
	elif population.free_rep_count > 0:
		_show(S.mission_send, S.mission_send_hint, 0.0)
	else:
		_show(S.mission_train, S.mission_train_hint,
				population.training_progress(Resident.Rank.MISSIONARY))


## Key buildings of district `d` that are open or yours.
func _keys_open(d: int) -> int:
	var n := 0
	for k in districts.keys:
		if districts.district_of(k) == d and (districts.is_key_open(k) or districts.is_yours(k)):
			n += 1
	return n


## The fullest meter among the buildings reps are working on; -1 when none is.
func _best_meter() -> float:
	var best := -1.0
	for b in campaigns.marked():
		best = maxf(best, districts.meter_of(districts.index_of(b)))
	return best


func _show(title: String, hint: String, value: float) -> void:
	if _title.text != title:
		_title.text = title
	if _hint.text != hint:
		_hint.text = hint
		_hint.visible = hint != ""
	_bar.value = clampf(value, 0.0, 1.0)
