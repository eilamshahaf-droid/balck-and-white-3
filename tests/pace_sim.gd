extends Node
## Plays the Slums with a simple bot at high speed and prints how far the Committee
## gets, so a balance change can be judged in minutes instead of hours of play.
##
## Run headless:
##   godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,send,shop,upgrade,bury,fixer
## Bot habits (any mix): train = train a Rep whenever the cap, the pool and the paperwork
## allow, send = send Reps to buildings in reach (the fullest meters first), shop = open
## a shop in a building of yours when the money is there, upgrade = fit a Training Room,
## a Desk Room, an Archive and a Vault into the Office in turn (while they fit), bury = bury the file whenever the exposure is
## past a half. It never uses the hand (so every inspector arrives), a miracle or a
## loan, so a player should do better than this. fixer = train a Fixer and keep him
## opening the nearest key building in reach. hand = stand-in for a player who carries
## an inspector off every HAND_EVERY seconds (he gives up, as if thrown away).
## Every STATS_EVERY a STATS block gives the paperwork economy for the Balance Tester:
## income and spending per minute by use (the last ten minutes), and running totals of
## inspectors, demands, audits and buildings.

const MAIN := preload("res://scenes/main.tscn")
const SPEED := 8.0
const REPORT_EVERY := 120.0   # game seconds
const ACT_EVERY := 5.0
const SHOP_EVERY := 4         # one building in this many becomes a shop
const BURY_FROM := 0.5
const STATS_EVERY := 600.0   # game seconds
const HAND_EVERY := 15.0
const OFFICE_ROOMS: Array[StringName] = [&"training", &"desks", &"archive", &"vault"]

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
var _rooms: Rooms
var _breaches: Breaches
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
var _next_stats := STATS_EVERY
var _next_hand := HAND_EVERY
var _spent := {}           # use -> paperwork spent since the last STATS
var _pool_then := 0.0
var _sent := 0
var _paid := 0
var _audits := 0
var _turned_back := 0
var _carried := 0
var _gave_up := 0
var _keys_opened := 0


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
	_rooms = _main.get_node("Rooms")
	_breaches = _main.get_node("Breaches")
	_inspectors.papers_shown.connect(func(_b: Node3D, _c: float) -> void: _papers += 1)
	_inspectors.audit_passed.connect(func(_b: Node3D, _c: float) -> void: _papers += 1)
	_inspectors.rep_sent_home.connect(func(_b: Node3D, _r: Resident) -> void: _reps_lost += 1)
	_inspectors.sent.connect(func(_i: Inspector, _f: Node3D) -> void: _sent += 1)
	_inspectors.papers_shown.connect(func(_b: Node3D, _c: float) -> void: _paid += 1)
	_inspectors.audit_passed.connect(func(_b: Node3D, _c: float) -> void: _audits += 1)
	_inspectors.turned_back.connect(func(_b: Node3D) -> void: _turned_back += 1)
	_inspectors.gave_up.connect(func(_p: Vector3) -> void: _gave_up += 1)
	_breaches.opened.connect(func(_b: Node3D) -> void: _keys_opened += 1)
	_faith.spent.connect(_on_spent)
	_districts.building_changed.connect(_on_building_changed)
	_pool_then = _faith.belief_pool
	Engine.time_scale = SPEED
	print("PACE SIM bot=%s" % ",".join(_habits))


func _physics_process(delta: float) -> void:
	_clock += delta
	if _clock >= _next_act:
		_next_act += ACT_EVERY
		_act()
	if _habits.has("hand") and _clock >= _next_hand:
		_next_hand += HAND_EVERY
		_carry_one()
	if _clock >= _next_stats:
		_next_stats += STATS_EVERY
		_print_stats()
	if _clock < _next_report:
		return
	_next_report += REPORT_EVERY
	var d := _districts.start_district()
	var blocks := 0
	for b in _districts.block_count():
		blocks += 1 if _districts.is_block_complete(b) else 0
	print("PACE %3d min  followers %4d (%2d sellers %2d clerks)  reps %d/%d  buildings %3d (%2.0f%%, won %d lost %d)  blocks %2d  bar %3.0f%%  core %s  $%5.0f %+.1f/s  paperwork %4.0f %+.2f/s  exposure %3.0f%%  paid %d  reps lost %d  keys %d/%d" % [
			roundi(_clock / 60.0), _followers.total, _followers.sellers, _followers.clerks,
			_population.reps_out, _followers.rep_cap(),
			_districts.converted_buildings().size(), _districts.share(d) * 100.0, _won, _lost,
			blocks, _progress.value(d) * 100.0,
			"yes" if _districts.is_yours(_districts.core_of(d)) else "no",
			_treasury.money, _treasury.income, _faith.belief_pool, _followers.paperwork_rate,
			_faith.exposure * 100.0, _papers, _reps_lost,
			roundi(_districts.key_share(d) * _districts.keys.size()), _districts.keys.size()])
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
		var kind := _rooms.settings.kind(OFFICE_ROOMS[_bought % OFFICE_ROOMS.size()])
		if _rooms.place_anywhere(_districts.headquarters, kind):
			_bought += 1
	if _habits.has("shop"):
		var held := _districts.converted_buildings()
		var shops := get_tree().get_nodes_in_group(Population.SHOPS).size()
		if shops < floori(held.size() / float(SHOP_EVERY)):
			for b in held:
				if not _followers.has_shop(_districts.index_of(b)) \
						and _rooms.place_anywhere(_districts.index_of(b), _rooms.settings.kind(&"shop")):
					break
	if _habits.has("fixer"):
		_use_fixer(office)
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


## Train a Fixer when there is none, and send him to the nearest key building that
## borders ours and is not open yet.
func _use_fixer(office: Node3D) -> void:
	if _population.agent_count == 0:
		_menus.choose(&"train_fixer", office)
		return
	if _breaches.target:
		return
	var best: Node3D = null
	var gap := INF
	for k in _districts.keys:
		var b := _districts.buildings[k]
		var d := b.global_position.distance_squared_to(office.global_position)
		if _breaches.why_not(b) == "" and d < gap:
			gap = d
			best = b
	if best:
		_breaches.send(best)


func _on_spent(amount: float, use: StringName) -> void:
	_spent[use] = _spent.get(use, 0.0) + amount


## The hand's stand-in: the inspector nearest his door gives up.
func _carry_one() -> void:
	var best: Inspector = null
	var gap := INF
	for inspector in _inspectors.out:
		if inspector.lost or inspector.arrived:
			continue
		var d := inspector.global_position.distance_squared_to(inspector.building.global_position)
		if d < gap:
			gap = d
			best = inspector
	if best:
		best.lost = true
		_carried += 1


## Ten minutes of the paperwork economy, per minute where it is a rate.
func _print_stats() -> void:
	var minutes := STATS_EVERY / 60.0
	var total := 0.0
	var uses := PackedStringArray()
	for use: StringName in _spent:
		total += _spent[use]
		uses.append("%s %.1f" % [use, _spent[use] / minutes])
	var income := (_faith.belief_pool - _pool_then + total) / minutes
	print("STATS %3d min  clerks %d  sellers %d  paperwork income %.1f/min  spent %.1f/min (%s)" % [
			roundi(_clock / 60.0), _followers.clerks, _followers.sellers, income,
			total / minutes, ", ".join(uses) if not uses.is_empty() else "nothing"])
	print("STATS %3d min  exposure %3.0f%%  inspectors out %d  totals: sent %d carried %d gave up %d  demands paid %d failed (Rep lost) %d  audits paid %d failed (building lost) %d  buildings held %d won %d lost %d  keys opened %d" % [
			roundi(_clock / 60.0), _faith.exposure * 100.0, _inspectors.out.size(), _sent,
			_carried, _gave_up, _paid, _reps_lost, _audits, _turned_back,
			_districts.converted_buildings().size(), _won, _lost, _keys_opened])
	_spent.clear()
	_pool_then = _faith.belief_pool
