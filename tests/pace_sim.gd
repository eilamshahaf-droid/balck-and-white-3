extends Node
## Plays the Slums with a simple bot at high speed and prints how far the cult gets,
## so a balance change can be judged in minutes instead of hours of play.
##
## Run headless:
##   godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,preach,buy
## Bot habits (any mix): train = keep a third of the believers as missionaries,
## pray = keep a few believers praying at the base, preach = sky-sign marks on lived-in
## buildings within reach, buy = dollar marks on empty ones (two marks at a time),
## delegate = train the Field Delegate at the base and keep three landmarks marked.
## It never uses the hand or a miracle, so a player should do better than this.

const MAIN := preload("res://scenes/main.tscn")
const LS: LandmarkSettings = preload("res://data/landmarks.tres")
const U: UnitSettings = preload("res://data/units.tres")
const SPEED := 8.0
const REPORT_EVERY := 120.0   # game seconds
const ACT_EVERY := 5.0
const MARKS := 2
const REPS_READY := 2   # train while fewer free reps than this
const PRAYING := 4
const LANDMARK_MARKS := 3
const MARK_SLACK := 60.0      # game seconds to walk there and back

var _main: Node3D
var _population: Population
var _districts: Districts
var _campaigns: Campaigns
var _treasury: Treasury
var _awareness: Awareness
var _progress: DistrictProgress
var _faith: Node
var _landmarks: Landmarks
var _delegate_free_at := 0.0
var _habits := PackedStringArray()
var _minutes := 40.0
var _clock := 0.0
var _next_report := 0.0
var _next_act := 0.0
var _won := 0
var _lost := 0


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
	_awareness = _main.get_node("Awareness")
	_progress = _main.get_node("DistrictProgress")
	_faith = _main.get_node("Faith")
	_landmarks = _main.get_node("Landmarks")
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
	print("PACE %3d min  believers %3d  missionaries %2d  buildings %3d (%2.0f%%, won %d lost %d)  blocks %2d  bar %3.0f%%  core %s  $%5.0f  belief %4.0f  awareness %.2f" % [
			roundi(_clock / 60.0), _population.believer_count, _population.missionary_count,
			_districts.converted_buildings().size(), _districts.share(d) * 100.0, _won, _lost,
			blocks, _progress.value(d) * 100.0,
			"yes" if _districts.is_yours(_districts.core_of(d)) else "no",
			_treasury.money, _faith.belief_pool, _awareness.level(d)])
	if _clock >= _minutes * 60.0 or _districts.is_controlled(d):
		print("PACE SIM END: %s" % ("district won" if _districts.is_controlled(d) else "time up"))
		get_tree().quit()


func _on_building_changed(_index: int, yours: bool) -> void:
	if yours:
		_won += 1
	else:
		_lost += 1


func _act() -> void:
	if _habits.has("train") and _population.free_rep_count < REPS_READY:
		for r in _population.residents:
			if r.rank == Resident.Rank.BELIEVER and r.job == Resident.Job.FREE \
					and _population.staffing.train(r, Resident.Rank.MISSIONARY,
					_districts.start_building()):
				break
	var base := _districts.start_building()
	if _habits.has("pray") and _population.staffing.staff_count(base, Resident.Job.PRAY) < PRAYING:
		for r in _population.residents:
			if r.rank == Resident.Rank.BELIEVER and r.job == Resident.Job.FREE \
					and _population.staffing.assign(r, Resident.Job.PRAY, base):
				break
	if _habits.has("delegate"):
		_send_delegate(base)
	for b in _campaigns.marked():
		if not _districts.can_claim(_districts.index_of(b)):
			_campaigns.clear(b)   # its border was lost: don't wait on it
	if _campaigns.marked().size() >= MARKS:
		return
	# Buildings that already want us first: they only need a rep.
	var order: Array[int] = []
	for i in _districts.buildings.size():
		if _districts.buildings[i] and not _districts.is_yours(i):
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _districts.meter_of(a) > _districts.meter_of(b))
	for i in order:
		var b := _districts.buildings[i]
		if _campaigns.route_of(b) >= 0:
			continue
		if _habits.has("buy") and not _districts.wants_you(i) \
				and _campaigns.why_not(b, Campaigns.Route.BUY) == "":
			_campaigns.mark(b, Campaigns.Route.BUY)
			return
		if _habits.has("preach") and _population.free_rep_count > 0 \
				and _campaigns.why_not(b, Campaigns.Route.PREACH) == "":
			_campaigns.mark(b, Campaigns.Route.PREACH)
			return


## Train the Field Delegate if there is none, and send him to an unmarked landmark
## while fewer than LANDMARK_MARKS stand, once he is back from the last one.
func _send_delegate(base: Node3D) -> void:
	var agent: Resident = null
	for r in _population.residents:
		if r.rank == Resident.Rank.AGENT and r.alive:
			agent = r
			break
	if agent == null:
		for r in _population.residents:
			if r.rank == Resident.Rank.BELIEVER and r.job == Resident.Job.FREE \
					and _treasury.can_afford(U.agent_cost) \
					and _population.staffing.train(r, Resident.Rank.AGENT, base):
				_treasury.spend_money(U.agent_cost)
				break
		return
	var d := _districts.start_district()
	if _clock < _delegate_free_at or agent.jailed_left > 0.0 \
			or not _population.has_body(agent) or _landmarks.marks_in(d) >= LANDMARK_MARKS:
		return
	for i in _landmarks.buildings:
		if not _landmarks.is_marked(i) and _treasury.can_afford(_landmarks.mark_cost(i)):
			_population.agent_set_down.emit(agent, _districts.buildings[i])
			_delegate_free_at = _clock + LS.mark_minutes * 60.0 + MARK_SLACK
			return
