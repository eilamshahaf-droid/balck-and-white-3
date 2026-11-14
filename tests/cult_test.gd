extends Node
## Checks the Slums slice of the core loop in the real main scene: the stage map, the
## Secretary at the main Office, followers as numbers and the roles that fill
## themselves, training a Rep under the cap, taking a building next to yours with a Rep
## who stays as its Manager, the pull inside a block, shops, floors, the loan, key
## buildings and inspectors (papers, audits, burying the file), the block bonus, and
## winning the district.
##
## Run headless:
##   godot --headless --path . res://tests/cult_test.tscn
## Prints one line per check and exits with code 1 if any failed.

const MAIN := preload("res://scenes/main.tscn")
const U: UnitSettings = preload("res://data/units.tres")
const DS: DistrictSettings = preload("res://data/districts.tres")
const F: FollowersSettings = preload("res://data/followers.tres")
const I: InspectorSettings = preload("res://data/inspectors.tres")
const PULL_MINUTES := 2.0
const PLENTY := 100000.0

var _main: Node3D
var _population: Population
var _districts: Districts
var _followers: Followers
var _menus: BuildingMenus
var _faith: Faith
var _treasury: Treasury
var _decrees: Decrees
var _inspectors: Inspectors
var _campaigns: Campaigns
var _near := -1   # a building taken next to the headquarters by _test_taking
var _failures := 0


func _ready() -> void:
	_main = MAIN.instantiate()
	add_child(_main)
	_population = _main.get_node("Population")
	_districts = _main.get_node("Districts")
	_followers = _main.get_node("Followers")
	_menus = _main.get_node("BuildingMenus")
	_faith = _main.get_node("Faith")
	_treasury = _main.get_node("Treasury")
	_decrees = _main.get_node("Decrees")
	_inspectors = _main.get_node("Inspectors")
	_campaigns = _main.get_node("Campaigns")
	await _frames(int(F.tick * 60.0) + 20)
	_test_stage_map()
	_test_start()
	_test_slums_people()
	_test_roles()
	_test_training()
	await _test_taking()
	_test_growth()
	_test_pull()
	_test_shop_and_floors()
	_test_loan()
	_test_key_buildings()
	await _test_inspector_and_rep()
	_test_audit()
	await _test_block()
	await _test_capture()
	print("CULT TEST: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## The Slums come from the Map Lab's stage file: 100 to 200 large buildings (each needs
## a rep of its own, so each is a decision), in blocks of three to six, and the base far
## enough from the core.
func _test_stage_map() -> void:
	var city: City = _main
	var count := _districts.buildings.size()
	var blocks := _districts.block_count()
	_check(count >= 100 and count <= 200, "the stage map has 100 to 200 buildings (%d)" % count)
	_check(blocks >= 30 and blocks <= 55, "they stand in about 40 blocks (%d)" % blocks)
	_check(get_tree().get_nodes_in_group("buildings").size() == count, "each is its own building")
	var d := _districts.start_district()
	var steps := {_districts.core_of(d): 0}
	var todo: Array[int] = [_districts.core_of(d)]
	while not todo.is_empty():
		var i: int = todo.pop_front()
		for j in _districts.borders_of(i):
			if not steps.has(j):
				steps[j] = steps[i] + 1
				todo.append(j)
	_check(steps.get(_districts.headquarters, 0) >= 6,
			"the base is several buildings from the core (%d)" % steps.get(_districts.headquarters, 0))
	var walk := city.walk_from(city.nearest_node(_districts.start_building().global_position), 5)
	_check(walk.size() >= 2, "people can walk the streets from the base")


func _test_start() -> void:
	var start := _districts.start_building()
	_check(start != null, "the start district has a main Office")
	_check(_population.priest != null, "there is a Secretary")
	if start == null or _population.priest == null:
		return
	var hq := _districts.headquarters
	_check(_population.priest.rank == Resident.Rank.HIGH_PRIEST, "with the Secretary's rank")
	_check(_population.priest.post == start, "serving at the main Office")
	_check(_districts.owns(start), "the main Office is yours")
	_check(_followers.total > 0 and _followers.total == _followers.count_of(hq),
			"the Office opens with followers of its own (%d)" % _followers.total)
	_check(_followers.count_of(hq) <= _followers.room_of(hq),
			"no more than it has room for (%d)" % _followers.room_of(hq))
	_check(_population.missionary_count == 0, "and no Rep yet")
	_check(_districts.is_unlocked(_districts.start_district()), "the start district is open")
	if _districts.district_count() > 1:
		_check(not _districts.is_unlocked((_districts.start_district() + 1) % _districts.district_count()),
				"the next district is locked")


func _test_slums_people() -> void:
	var counts := {}
	var total := 0
	for r in _population.residents:
		if r.home == null or _districts.district_at(r.home.global_position) != _districts.start_district():
			continue
		counts[r.archetype.title] = counts.get(r.archetype.title, 0) + 1
		total += 1
	_check(total > 0, "people live in the Slums (%d)" % total)
	_check(counts.keys().size() == 2 and counts.has("Homeless") and counts.has("Blue collar"),
			"only homeless and blue collar live in the Slums %s" % str(counts))
	var homeless := float(counts.get("Homeless", 0)) / maxi(total, 1)
	_check(homeless > 0.25 and homeless < 0.55, "about 40%% homeless (%d%%)" % roundi(homeless * 100))


## Roles fill themselves from the pool: clerks at the Office make paperwork, sellers in
## its shop make money, each further seller less, and the player can let one go.
func _test_roles() -> void:
	var hq := _districts.headquarters
	_check(_followers.clerks > 0 and _followers.clerks <= _followers.clerk_slots() \
			and _followers.paperwork_rate > 0.0,
			"clerks took the Office's desks and make paperwork (%d, %.2f/s)"
			% [_followers.clerks, _followers.paperwork_rate])
	_check(_followers.has_shop(hq) and _followers.sellers_in(hq) > 0 and _followers.money_rate > 0.0,
			"sellers took the Office shop's slots and make money (%d, $%.2f/s)"
			% [_followers.sellers_in(hq), _followers.money_rate])
	_check(_followers.idle() == _followers.total - _followers.clerks - _followers.sellers \
			and _followers.idle() >= 0, "the rest are only counted (%d idle)" % _followers.idle())
	var sellers := _followers.sellers_in(hq)
	var rate := _followers.money_rate
	var next := _followers.next_seller_net(hq)
	_followers.change_sellers(hq, -1)
	_check(_followers.sellers_in(hq) == sellers - 1 and _followers.money_rate < rate,
			"letting a seller go leaves one fewer at work, and less money")
	_check(_followers.next_seller_net(hq) > next, "each further seller brings in less")
	_followers.change_sellers(hq, 1)
	_check(_followers.sellers_in(hq) == sellers, "and taking one on again brings them back")


## A Rep is trained at the main Office from one follower, for paperwork, up to the cap.
func _test_training() -> void:
	var office := _districts.start_building()
	_faith.belief_pool = 0.0
	_check(not _menus.choose(&"train_rep", office), "no training without the paperwork")
	_faith.belief_pool = F.rep_paperwork * 10.0
	var before := _followers.total
	_check(_menus.choose(&"train_rep", office), "a Rep starts training at the main Office")
	_check(_followers.total == before - 1, "one follower left the pool for it")
	_check(is_equal_approx(_faith.belief_pool, F.rep_paperwork * 9.0),
			"and it cost %d paperwork" % roundi(F.rep_paperwork))
	_finish_training()
	_check(_population.missionary_count == 1 and _population.free_rep_count == 1,
			"after the training there is a free Rep")
	for i in _followers.rep_cap():
		_menus.choose(&"train_rep", office)
	_finish_training()
	_check(_population.reps_out == _followers.rep_cap(),
			"Reps can be trained up to the cap (%d)" % _followers.rep_cap())
	_check(_menus.why_not_train(Resident.Rank.MISSIONARY) != "" \
			and not _menus.choose(&"train_rep", office), "and no further")
	_followers.upgrades.add(office, BuildingUpgrades.Kind.TRAINING)
	_check(_menus.why_not_train(Resident.Rank.MISSIONARY) == "",
			"a Training Room at the Office raises the cap by one")


## A building is taken only next to one of yours: its meter fills, and a Rep set down at
## it takes it and stays as its Manager, which frees a place under the cap.
func _test_taking() -> void:
	var d := _districts.start_district()
	var far := -1
	var near := -1
	for i in _districts.buildings.size():
		if not _districts.buildings[i] or _districts.is_yours(i) or _districts.district_of(i) != d \
				or _districts.is_core(_districts.buildings[i]):
			continue
		if _districts.can_claim(i):
			near = i if near < 0 else near
		else:
			far = i if far < 0 else far
	if far < 0 or near < 0:
		_check(false, "a building next to yours and one far away")
		return
	_check(not _districts.take(far) and not _districts.is_yours(far),
			"a building far from yours can't be taken")
	_districts.add_meter(near, 0.4)
	_check(is_equal_approx(_districts.meter_of(near), 0.4) and not _districts.wants_you(near),
			"a takeover meter fills part way")
	_districts.add_meter(near, 0.6 - 0.000001)
	_districts.add_meter(near, 0.5)
	_check(_districts.wants_you(near) and not _districts.is_yours(near),
			"a full meter means the building wants you, and is not yours yet")
	var rep: Resident = null
	for r in _population.residents:
		if r.rank == Resident.Rank.MISSIONARY and r.job == Resident.Job.FREE:
			rep = r
	var out := _population.reps_out
	var pool := _followers.total
	_population.canvasser_set_down.emit(rep, _districts.buildings[near])
	await _frames(3)
	_check(_districts.is_yours(near), "a Rep set down at a building that wants you takes it")
	_check(_population.manager_of(_districts.buildings[near]) == rep \
			and rep.job == Resident.Job.MANAGER, "and stays as its Manager")
	_check(_population.reps_out == out - 1, "a Manager no longer counts against the Rep cap")
	_check(_followers.count_of(near) == floori(_followers.room_of(near) * F.start_share) \
			and _followers.total == pool + _followers.count_of(near),
			"the building joins the pool half full (%d of %d)"
			% [_followers.count_of(near), _followers.room_of(near)])
	_near = near


## Followers come by themselves up to the room there is; attraction brings them faster.
func _test_growth() -> void:
	if _near < 0:
		return
	var b := _districts.buildings[_near]
	var before := _followers.count_of(_near)
	_followers._grow(2.0 / F.growth_per_minute)
	_check(_followers.count_of(_near) > before, "a building of yours gains followers with time")
	_followers._grow(PLENTY)
	_check(_followers.count_of(_near) == _followers.room_of(_near), "up to the room it has")
	var plain := _followers.attraction_of(_near)
	_followers.upgrades.add(b, BuildingUpgrades.Kind.ATTRACTION)
	_check(_followers.attraction_of(_near) > plain, "an Attraction upgrade brings them faster")


## Buildings of yours pull up the meters next door, only inside their own block.
func _test_pull() -> void:
	var before := PackedFloat32Array()
	for i in _districts.buildings.size():
		before.append(_districts.meter_of(i))
	_followers._pull(PULL_MINUTES)
	var rose := 0
	var inside := true
	for j in _districts.buildings.size():
		if _districts.buildings[j] == null or _districts.is_yours(j) \
				or _districts.meter_of(j) <= before[j]:
			continue
		rose += 1
		var next_to_ours := false
		for i in _districts.borders_of(j):
			next_to_ours = next_to_ours or (_districts.is_yours(i) \
					and _districts.block_of(i) == _districts.block_of(j))
		inside = inside and next_to_ours
	_check(rose > 0, "buildings of yours pull their neighbours' meters up (%d rose)" % rose)
	_check(inside, "only next door, and only inside their own block")


## A building of yours can open a shop and stays yours and lived in; floors add room.
func _test_shop_and_floors() -> void:
	if _near < 0:
		return
	var b := _districts.buildings[_near]
	_faith.belief_pool = PLENTY
	_treasury.money = PLENTY
	var sellers := _followers.sellers
	_check(not _followers.has_shop(_near) and _decrees.issue(&"use", b) and _followers.has_shop(_near),
			"a building of yours opens a shop")
	_check(_districts.is_yours(_near) and _followers.count_of(_near) > 0,
			"and stays yours, with its followers")
	_check(_followers.sellers > sellers and _followers.sellers_in(_near) > 0,
			"followers from the pool take its slots (%d sellers)" % _followers.sellers_in(_near))
	var slots := _followers.shop_slots(_near)
	_followers.upgrades.add(b, BuildingUpgrades.Kind.SHOP)
	_check(_followers.shop_slots(_near) > slots, "a Bigger Shop has more slots")
	var room := _followers.room_of(_near)
	_check(_decrees.issue(&"floors", b) and _followers.room_of(_near) > room,
			"more floors make room for more followers (%d to %d)" % [room, _followers.room_of(_near)])


## One loan at a time, opened with paperwork; money from outside pays it off first.
func _test_loan() -> void:
	_faith.belief_pool = F.loan_paperwork * 2.0
	_treasury.money = 0.0
	_check(_treasury.borrow() and is_equal_approx(_treasury.money, F.loan_money) \
			and is_equal_approx(_treasury.owed, F.loan_owed),
			"a loan gives $%d now for $%d owed" % [roundi(F.loan_money), roundi(F.loan_owed)])
	_check(not _treasury.borrow(), "only one loan at a time")
	_treasury.add_money(F.loan_owed + 10.0)
	_check(is_zero_approx(_treasury.owed) and is_equal_approx(_treasury.money, F.loan_money + 10.0),
			"banknotes from a miracle pay the loan off first")


## About one block in four or five has a key building, spread over the district; they
## can't be taken by a Rep.
func _test_key_buildings() -> void:
	var d := _districts.start_district()
	var keys := _districts.keys
	_check(keys.size() >= 6 and keys.size() <= 12, "the Slums have about nine key buildings (%d)" % keys.size())
	_check(keys.has(_districts.core_of(d)), "the core is one of them")
	var in_base_block := false
	var claimable := false
	for k in keys:
		in_base_block = in_base_block or _districts.block_of(k) == _districts.block_of(_districts.headquarters)
		claimable = claimable or _districts.can_claim(k)
	_check(not in_base_block, "none stands in the Office's block")
	_check(not claimable and _campaigns.why_not(_districts.buildings[keys[0]]) != "",
			"a Rep can't take a key building")
	var city: City = _main
	var from := city.nearest_node(_districts.buildings[keys[0]].global_position)
	var to := city.nearest_node(_districts.start_building().global_position)
	var route := city.route(from, to)
	var joined := route[0] == from and route[route.size() - 1] == to
	for n in route.size() - 1:
		joined = joined and city.plan.neighbours[route[n]].has(route[n + 1])
	_check(joined and route.size() > 2, "the streets join a key building to the Office (%d corners)" % route.size())


## An inspector walks from a key building to a Rep at work. With paperwork the Rep shows
## papers; with none the Rep is sent home. More exposure, more inspectors.
func _test_inspector_and_rep() -> void:
	_faith.exposure = 0.0
	_check(_inspectors.allowed() == I.max_base, "with no exposure, %d inspector at a time" % I.max_base)
	_faith.exposure = 1.0
	_check(_inspectors.allowed() == I.max_base + I.max_extra,
			"at full exposure, %d" % (I.max_base + I.max_extra))
	_faith.exposure = 0.5
	_faith.belief_pool = _inspectors.bury_cost()
	var first := _inspectors.bury_cost()
	_check(_inspectors.bury() and is_equal_approx(_faith.exposure, 0.5 - I.bury_exposure) \
			and is_zero_approx(_faith.belief_pool), "burying the file costs paperwork and lowers exposure")
	_check(_inspectors.bury_cost() > first, "and costs more the next time")
	var rep: Resident = null
	for r in _population.residents:
		if r.rank == Resident.Rank.MISSIONARY and r.job == Resident.Job.FREE:
			rep = r
	var door: Node3D = null
	for i in _districts.buildings.size():
		if _districts.buildings[i] and not _districts.is_yours(i) and not _districts.wants_you(i) \
				and _campaigns.why_not(_districts.buildings[i]) == "":
			door = _districts.buildings[i]
			break
	if rep == null or door == null:
		_check(false, "a free Rep and a door to send them to")
		return
	_population.bring_out(rep)
	_population.canvasser_set_down.emit(rep, door)
	_check(_campaigns.reps_at(door).has(rep), "a Rep set down at a door is at work there")
	var inspector := _inspectors.send_to(door, false)
	var start := inspector.global_position
	await _frames(60)
	_check(inspector.global_position.distance_to(start) > 1.0 and not inspector.arrived,
			"an inspector leaves the nearest key building and walks the streets")
	inspector.on_grabbed()
	inspector.on_released(Vector3.ZERO)
	_check(_inspectors.out.has(inspector) and not inspector.arrived, "the hand can lift him and set him down")
	var cost := _inspectors.demand_cost()
	_faith.belief_pool = cost + 5.0
	inspector.arrived = true
	_inspectors._arrive(inspector)
	_check(is_equal_approx(_faith.belief_pool, 5.0) and rep.rank == Resident.Rank.MISSIONARY \
			and _campaigns.reps_at(door).has(rep),
			"when he arrives the Rep shows papers (%d paperwork) and works on" % roundi(cost))
	_check(not _inspectors.out.has(inspector), "and the inspector leaves")
	inspector = _inspectors.send_to(door, false)
	inspector.arrived = true
	_inspectors._arrive(inspector)
	_check(rep.rank == Resident.Rank.RESIDENT and _campaigns.reps_at(door).is_empty(),
			"with no paperwork the Rep is sent home")


## An inspector audits a building of yours: paperwork passes it (less with Security);
## with none it is lost, with its followers and its Manager, and keeps part of its meter.
func _test_audit() -> void:
	if _near < 0:
		return
	var b := _districts.buildings[_near]
	var plain := _inspectors.audit_cost(_near)
	_followers.upgrades.add(b, BuildingUpgrades.Kind.SECURITY)
	var cost := _inspectors.audit_cost(_near)
	_check(cost < plain, "Security makes an audit cheaper (%d to %d paperwork)" % [roundi(plain), roundi(cost)])
	_faith.belief_pool = cost
	var inspector := _inspectors.send_to(b, true)
	inspector.arrived = true
	_inspectors._arrive(inspector)
	_check(_districts.is_yours(_near) and is_zero_approx(_faith.belief_pool),
			"a building of yours passes its audit for paperwork")
	var manager := _population.manager_of(b)
	_followers.recount()
	var pool := _followers.total
	var there := _followers.count_of(_near)
	inspector = _inspectors.send_to(b, true)
	inspector.arrived = true
	_inspectors._arrive(inspector)
	_check(not _districts.is_yours(_near) and is_equal_approx(_districts.meter_of(_near), DS.lost_meter),
			"with no paperwork it is lost, and keeps %d%% of its meter" % roundi(DS.lost_meter * 100.0))
	_check(_followers.count_of(_near) == 0 and _followers.total == pool - there,
			"its followers leave the pool")
	_check(manager != null and manager.rank == Resident.Rank.RESIDENT \
			and _population.manager_of(b) == null, "and its Manager is lost")


## A block whose buildings are all yours is complete: followers come to it faster.
func _test_block() -> void:
	var hq := _districts.headquarters
	var block := _districts.block_of(hq)
	var done := [false]
	_districts.block_changed.connect(func(b: int, complete: bool) -> void:
		done[0] = done[0] or (b == block and complete))
	var members := _districts.block_members(block)
	var plain := _followers.attraction_of(hq)
	# Outward from the base: each can only be taken next to one already held.
	for pass_ in members.size():
		for i in members:
			_districts.take(i)
	await _frames(int(DS.tick * 60.0 * 3.0))
	_check(_districts.block_held(block) == members.size(),
			"every building of the base's block is yours (%d of %d)"
			% [_districts.block_held(block), members.size()])
	_check(done[0] and _districts.is_block_complete(block), "so the block is complete")
	_check(is_equal_approx(_followers.attraction_of(hq) - plain, F.block_attraction),
			"and followers come to its buildings faster")


func _test_capture() -> void:
	var d := _districts.start_district()
	var progress: DistrictProgress = _main.get_node("DistrictProgress")
	_check(progress.value(d) < 1.0 and not _districts.is_controlled(d),
			"the district's bar is not full yet (%d%%)" % roundi(progress.value(d) * 100.0))
	var got := [false]
	_districts.district_controlled.connect(func(x: int) -> void: got[0] = got[0] or x == d)
	var core := _districts.buildings[_districts.core_of(d)]
	_districts.convert_near(core.global_position, _districts.buildings.size())
	await _frames(int(DS.progress_tick * 60.0 * 2.0))
	_check(got[0] and _districts.is_controlled(d), "a full bar wins the district")
	var empty := 0
	for i in _districts.buildings.size():
		if _districts.buildings[i] and _population.residents_in(_districts.buildings[i]) == 0:
			empty += 1
	_check(empty == 0, "no building stands empty (%d do)" % empty)


## Everyone in training finishes now.
func _finish_training() -> void:
	for r in _population.residents:
		if r.job == Resident.Job.TRAIN:
			_population.staffing.tick_training(r, maxf(U.missionary_time, U.agent_time))


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
