class_name MissionCard
extends PanelContainer
## The one thing to do next, as a card with a progress bar, in place of paragraphs of
## help: train a rep, send them to a building, take it, complete the block, fill the
## district's bar. It reads the game's state a few times a second; texts are in
## data/districts.tres ("Missions").

const S: DistrictSettings = preload("res://data/districts.tres")
const U: UnitSettings = preload("res://data/units.tres")
const REFRESH := 0.25

@export var districts: Districts
@export var population: Population
@export var campaigns: Campaigns
@export var progress: DistrictProgress

var _timer := 0.0
var _title := Label.new()
var _hint := Label.new()
var _bar := ProgressBar.new()


func _ready() -> void:
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
	var block := districts.block_of(districts.headquarters)
	var held := districts.converted_buildings().size()
	var working := _best_meter()
	if districts.is_controlled(d):
		_show(S.mission_won, "", 1.0)
	elif working >= 0.0:
		_show(S.mission_take, S.mission_take_hint, working)
	elif population.free_rep_count > 0:
		_show(S.mission_send, S.mission_send_hint, 0.0)
	elif held < S.mission_block_from or population.missionary_count == 0:
		_show(S.mission_train, S.mission_train_hint, population.training_progress(Resident.Rank.MISSIONARY))
	elif not districts.is_block_complete(block):
		_show(S.mission_block % [districts.block_held(block), districts.block_size(block)],
				S.mission_block_hint,
				float(districts.block_held(block)) / maxi(districts.block_size(block), 1))
	else:
		_show(S.mission_district, S.mission_district_hint, progress.value(d))


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
