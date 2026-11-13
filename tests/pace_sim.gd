extends Node
## Plays the Slums with a simple bot at high speed and prints how far the Committee
## gets, so a balance change can be judged in minutes instead of hours of play.
##
## Run headless:
##   godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,send,shop,upgrade,bury
## Bot habits (any mix): train = train a Rep whenever the cap, the pool and the paperwork
## allow, send = send Reps to buildings in reach (the fullest meters first), shop = open
## a shop in a building of yours when the money is there, upgrade = buy the Office's
## Training Room, Desks and Shop in turn, bury = bury the file whenever the exposure is
## past a half. It never uses the hand (so every inspector arrives), a miracle or a
## loan, so a player should do better than this.

const MAIN := preload("res://scenes/main.tscn")
const SPEED := 8.0
const REPORT_EVERY := 120.0   # game seconds
const ACT_EVERY := 5.0
const SHOP_EVERY := 4         # one building in this many becomes a shop
const BURY_FROM := 0.5
const OFFICE_UPGRADES: Array[BuildingUpgrades.Kind] = [BuildingUpgrades.Kind.TRAINING,
		BuildingUpgrades.Kind.DESKS, BuildingUpgrades.Kind.SHOP]

var _main: Node3D
var _population: Population
var _districts: Districts
var _campaigns: Campaigns
var _treasury: Treasury
var _followers: Followers
var _menus: BuildingMenus
var _decrees: Decrees
var _progress: DistrictProgress
var _faith: Faith
var _inspectors: Inspectors
var _papers := 0
var _reps_lost := 0
var _habits := PackedStringArray()
var _minutes := 40.0
var _clock := 0.0
var _next_report := 0.0
var _next_act := 0.0
var _won := 0
var _lost := 0
var _bought := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			_minutes = float(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--bot="):
			_habits = arg.trim_prefix("--bot=").split(",", false)
	_main = MAIN.instantiate()
	add_child(_main)
	_population = _main.get_node("Population")
	_districts = _main.get_node("Districts")
	_campaigns = _main.get_node("Campaigns")
	_treasury = _main.get_node("Treasury")
	_followers = _main.get_node("Followers")
	_menus = _main.get_node("BuildingMenus")
	_decrees = _main.get_node("Decrees")
	_progress = _main.get_node("DistrictProgress")
	_faith = _main.get_node("Faith")
	_inspectors = _main.get_node("Inspectors")
	_inspectors.papers_shown.connect(func(_b: Node3D, _c: float) -> void: _papers += 1)
	_inspectors.audit_passed.connect(func(_b: Node3D, _c: float) -> void: _papers += 1)
	_inspectors.rep_sent_home.connect(func(_b: Node3D, _r: Resident) -> void: _reps_lost += 1)
	_districts.building_changed.connect(_on_building_changed)
	Engine.time_scale = SPEED
	print("PACE SIM bot=%s" % ",".join(_habits))


func _physics_process(delta: float) -> void:
	_clock += delta
	if _clock >= _next_act:
		_next_act += ACT_EVERY
		_act()
	if _clock < _next_report:
		return
	_next_report += REPORT_EVERY
	var d := _districts.start_district()
	var blocks := 0
	for b in _districts.block_count():
		blocks += 1 if _districts.is_block_complete(b) else 0
	print("PACE %3d min  followers %4d (%2d sellers %2d clerks)  reps %d/%d  buildings %3d (%2.0f%%, won %d lost %d)  blocks %2d  bar %3.0f%%  core %s  $%5.0f %+.1f/s  paperwork %4.0f %+.2f/s  exposure %3.0f%%  paid %d  reps lost %d" % [
			roundi(_clock / 60.0), _followers.total, _followers.sellers, _followers.clerks,
			_population.reps_out, _followers.rep_cap(),
			_districts.converted_buildings().size(), _districts.share(d) * 100.0, _won, _lost,
			blocks, _progress.value(d) * 100.0,
			"yes" if _districts.is_yours(_districts.core_of(d)) else "no",
			_treasury.money, _treasury.income, _faith.belief_pool, _followers.paperwork_rate,
			_faith.exposure * 100.0, _papers, _reps_lost])
	if _clock >= _minutes * 60.0 or _districts.is_controlled(d):
		print("PACE SIM END: %s" % ("district won" if _districts.is_controlled(d) else "time up"))
		get_tree().quit()


func _on_building_changed(_index: int, yours: bool) -> void:
	if yours:
		_won += 1
	else:
		_lost += 1


func _act() -> void:
	var office := _districts.start_building()
	if _habits.has("train"):
		_menus.choose(&"train_rep", office)
	if _habits.has("bury") and _faith.exposure >= BURY_FROM:
		_inspectors.bury()
	if _habits.has("upgrade"):
		var kind := OFFICE_UPGRADES[_bought % OFFICE_UPGRADES.size()]
		if _menus.choose(StringName("upgrade_%d" % kind), office):
			_bought += 1
	if _habits.has("shop"):
		var held := _districts.converted_buildings()
		var shops := get_tree().get_nodes_in_group(Population.SHOPS).size()
		if shops < held.size() / SHOP_EVERY:
			for b in held:
				if not _followers.has_shop(_districts.index_of(b)) and _menus.choose(&"open_shop", b):
					break
	if not _habits.has("send"):
		return
	for b in _campaigns.marked():
		if not _districts.can_claim(_districts.index_of(b)):
			_campaigns.clear(b)   # its border was lost: don't wait on it
	# One building per free Rep; those that already want us first.
	if _campaigns.marked().size() >= maxi(_population.reps_out, 1):
		return
	var order: Array[int] = []
	for i in _districts.buildings.size():
		if _districts.buildings[i] and not _districts.is_yours(i):
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _districts.meter_of(a) > _districts.meter_of(b))
	for i in order:
		var b := _districts.buildings[i]
		if not _campaigns.is_sent(b) and _campaigns.why_not(b) == "":
			_campaigns.send(b)
			return
