class_name MissionCard
extends PanelContainer
## The one thing to do next, the "minutes": a lined paper slip held by a clothes peg
## (the UI brief), with the item number, the step just done struck through in red pen,
## the step now and a thin bar. After a while it folds back to the step alone; the mouse
## over it opens it again. The first ten minutes teach one thing at a time (GDD "The first ten minutes"):
## plan the empty Office (a Shop, a Desk Room, two homes for the people who work there),
## send the free Rep, take the first building, fit a Training Room, throw the inspector,
## train the Fixer and open a key building; then the goal, the key buildings of the
## district. Each step follows what really happened and, once done,
## never comes back. Texts are in data/districts.tres ("Missions").

const S: DistrictSettings = preload("res://data/districts.tres")
const U: UnitSettings = preload("res://data/units.tres")
const UI: UiSettings = preload("res://data/ui.tres")

@export var districts: Districts
@export var population: Population
@export var campaigns: Campaigns
@export var progress: DistrictProgress
@export var inspectors: Inspectors
@export var breaches: Breaches
@export var rooms: Rooms
@export var treasury: Treasury

var _timer := 0.0
var _item := 0
var _caption := Label.new()
var _done := StrikeLabel.new()
var _title := Label.new()
var _hint := Label.new()
var _bar := ProgressBar.new()
var _folded := false
var _fold_in := 0.0
# Steps done, latched so a step never shows twice.
var _shop := false        # a Shop in the Office
var _desks := false       # a Desk Room in the Office
var _homes := false       # homes in the Office for the people who work there
var _training := false    # a Training Room in the Office
var _sent := false        # a Rep sent to a building
var _first := false       # the first building taken
var _threw := false       # an inspector thrown
var _fixer := false       # a Fixer trained
var _opened := false      # a key building opened


func _ready() -> void:
	campaigns.campaign_started.connect(func(_b: Node3D) -> void: _sent = true)
	campaigns.taken.connect(func(_b: Node3D, _rep: Resident) -> void: _first = true)
	inspectors.thrown.connect(func(_i: Inspector) -> void: _threw = true)
	breaches.opened.connect(func(_b: Node3D) -> void: _opened = true)
	theme_type_variation = &"Slip"
	custom_minimum_size.x = S.mission_width
	mouse_entered.connect(_unfold)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_caption.theme_type_variation = &"Caption"
	box.add_child(_caption)
	_done.theme_type_variation = &"Caption"
	_done.visible = false
	box.add_child(_done)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.theme_type_variation = &"SlipTitle"
	box.add_child(_title)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.theme_type_variation = &"SlipText"
	box.add_child(_hint)
	_bar.theme_type_variation = &"InkBar"
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 6.0
	box.add_child(_bar)


func _draw() -> void:
	var peg := Rect2(Vector2(size.x * 0.62, -UI.peg_size.y * 0.55), UI.peg_size)
	draw_texture_rect(UI.peg_texture, peg, false)


func _process(delta: float) -> void:
	_fold_in -= delta
	if not _folded and _fold_in <= 0.0 and not _rect_has_mouse():
		_fold(true)
	_timer -= delta
	if _timer > 0.0 or districts.buildings.is_empty():
		return
	_timer = UI.refresh
	var d := districts.start_district()
	var held := districts.converted_buildings().size() - 1   # the Office is not taken
	_first = _first or held > 0
	_fixer = _fixer or population.agent_count > 0
	var working := _best_meter()
	var office := districts.headquarters
	_shop = _shop or rooms.count_in(office, &"shop") > 0
	_desks = _desks or rooms.count_in(office, &"desks") > 0
	_homes = _homes or rooms.homes_in(office) >= S.mission_homes_count
	_training = _training or rooms.count_in(office, &"training") > 0
	if districts.is_controlled(d):
		_show(S.mission_won, "", 1.0)
	elif not _threw and not inspectors.out.is_empty():
		_show(S.mission_inspector, S.mission_inspector_hint, 0.0)
	elif not _shop:
		_show(S.mission_shop, S.mission_shop_hint, 0.0)
	elif not _desks:
		_show(S.mission_desks, S.mission_desks_hint, 0.0)
	elif not _homes:
		_show(S.mission_homes % S.mission_homes_count, S.mission_homes_hint,
				float(rooms.homes_in(office)) / S.mission_homes_count)
	elif not _sent and not _first:
		_show(S.mission_first, S.mission_first_hint, 0.0)
	elif not _first:
		_show(S.mission_first_take, S.mission_first_take_hint, maxf(working, 0.0))
	elif not _training:
		var price := rooms.money_of(office, rooms.settings.kind(&"training"))
		_show(S.mission_training, S.mission_training_hint, treasury.money / maxf(price, 1.0))
	elif not _fixer and held >= S.mission_fixer_from:
		_show(S.mission_fixer, S.mission_fixer_hint,
				population.training_progress(Resident.Rank.AGENT))
	elif not _fixer:
		_show_reps(working)
	elif not _opened:
		_show(S.mission_open, S.mission_open_hint,
				breaches.bar_of(breaches.target) if breaches.target else 0.0)
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


## The fullest meter among the buildings reps are working on; -1 when none is.
func _best_meter() -> float:
	var best := -1.0
	for b in campaigns.marked():
		best = maxf(best, districts.meter_of(districts.index_of(b)))
	return best


func _show(title: String, hint: String, value: float) -> void:
	if _title.text != title:
		if _title.text != "":
			_done.text = _title.text
			_done.strike = 0.0
			create_tween().tween_property(_done, ^"strike", 1.0, UI.strike_seconds)
		_item += 1
		_caption.text = "MINUTES · ITEM %d" % _item
		_title.text = title
		_unfold()
	if _hint.text != hint:
		_hint.text = hint
		_hint.visible = hint != "" and not _folded
	_bar.value = clampf(value, 0.0, 1.0)


## Open the slip again for a while: the step done, the hint.
func _unfold() -> void:
	_fold_in = UI.collapse_seconds
	_fold(false)


func _fold(on: bool) -> void:
	_folded = on
	_done.visible = not on and _done.text != ""
	_hint.visible = not on and _hint.text != ""
	reset_size()


func _rect_has_mouse() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())
