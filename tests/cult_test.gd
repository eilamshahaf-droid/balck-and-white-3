extends Node
## Checks the Slums slice of the core loop in the real main scene: who lives in
## the start district, the high priest at the start building, the conversion
## formula, believers' output and needs, training, claiming next to your buildings,
## awareness, fragility, the Vandalist and his arrest, condemnation, the block bonus,
## and capturing the district.
##
## Run headless:
##   godot --headless --path . res://tests/cult_test.tscn
## Prints one line per check and exits with code 1 if any failed.

const MAIN := preload("res://scenes/main.tscn")
const U: UnitSettings = preload("res://data/units.tres")
const DS: DistrictSettings = preload("res://data/districts.tres")
const A: AwarenessSettings = preload("res://data/awareness.tres")
const LS: LandmarkSettings = preload("res://data/landmarks.tres")

var _main: Node3D
var _population: Population
var _districts: Districts
var _near := -1   # a building claimed next to the headquarters by _test_borders
var _failures := 0


func _ready() -> void:
	_main = MAIN.instantiate()
	add_child(_main)
	_population = _main.get_node("Population")
	_districts = _main.get_node("Districts")
	await _frames(20)
	_test_stage_map()
	_test_start()
	_test_slums_people()
	_test_chance()
	_test_output_and_needs()
	await _test_training()
	await _test_borders()
	_test_awareness()
	await _test_fragility()
	await _test_vandalist()
	await _test_condemnation()
	_test_landmarks()
	await _test_block()
	_test_hand_orders()
	await _test_capture()
	print("CULT TEST: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## The Slums come from the Map Lab's stage file: a few hundred buildings, each taken on
## its own, in about 50 blocks, and the base far enough from the core.
func _test_stage_map() -> void:
	var city: City = _main
	var count := _districts.buildings.size()
	var blocks := _districts.block_count()
	_check(count >= 300, "every building of the stage map can be taken (%d)" % count)
	_check(blocks >= 40 and blocks <= 65, "they stand in about 50 blocks (%d)" % blocks)
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
	_check(start != null, "the start district has a start building")
	_check(_population.priest != null, "there is a high priest")
	if start == null or _population.priest == null:
		return
	_check(_population.priest.rank == Resident.Rank.HIGH_PRIEST, "he has the high priest's rank")
	_check(_population.priest.post == start, "he serves in the start building")
	_check(start.is_in_group(Population.PRAYER_HOUSES), "the start building is a sermon house")
	_check(_population.believer_count <= 1, "nobody else believes at the start")
	_check(_districts.owns(start), "the start building is yours")
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


func _test_chance() -> void:
	var target := _resident_of("Homeless")
	var priest := _population.priest
	if target == null or priest == null:
		_check(false, "a homeless resident to preach to")
		return
	# Homeless: curiosity H, skepticism L, anxiety L; the high priest's charisma H.
	var expected := U.conversion_base * 0.8 * (1.0 - 0.2) * (1.0 - 0.5 * 0.2) * (1.0 + 0.3 * 0.8)
	var got := _population.preaching.chance(target, priest, Vector3(9999, 0, 9999))
	_check(absf(got - expected) < 0.001, "conversion chance matches the formula (%.3f)" % got)


func _test_output_and_needs() -> void:
	var r := _resident_of("Blue collar")
	if r == null:
		_check(false, "a blue collar resident")
		return
	_population.convert_to(r, Resident.Rank.BELIEVER)
	_check(r.is_believer(), "converting makes a believer")
	Needs.refresh(r, U)
	var m := _population.needs_multiplier(r)
	_check(m >= U.multiplier_min and m <= U.multiplier_max, "needs multiplier in range (%.2f)" % m)
	var money := _population.money_rate(r) * 60.0
	_check(absf(money - U.money_per_minute * 0.2 * m) < 0.001,
			"money per minute = 4 x wealth x needs (%.2f)" % money)


func _test_training() -> void:
	var house := _districts.start_building()
	var r := _resident_of("Blue collar", true)
	if r == null or house == null:
		_check(false, "a believer to train")
		return
	_check(_population.staffing.train(r, Resident.Rank.MISSIONARY, house), "a believer starts training")
	_check(r.job == Resident.Job.TRAIN, "they are training")
	r.training_left = 0.1
	await _frames(60)
	_check(r.rank == Resident.Rank.MISSIONARY, "training makes a missionary")
	_check(_population.missionary_count >= 1, "the cult counts its missionaries")
	_check(_population.staffing.train(r, Resident.Rank.PRIEST, house), "a missionary trains as a priest")
	r.training_left = 0.1
	await _frames(60)
	_check(r.rank == Resident.Rank.PRIEST, "training makes a priest")
	_check(r.post == house and r.job == Resident.Job.PRIEST, "the new priest serves in the house")


func _test_borders() -> void:
	var d := _districts.start_district()
	var core := _districts.core_of(d)
	var seen := {core: true}
	var todo: Array[int] = [core]
	while not todo.is_empty():
		for j in _districts.borders_of(todo.pop_back()):
			if not seen.has(j) and _districts.buildings[j] \
					and _districts.district_at(_districts.buildings[j].global_position) == d:
				seen[j] = true
				todo.append(j)
	var total := 0
	for i in _districts.buildings.size():
		if _districts.buildings[i] and _districts.district_at(_districts.buildings[i].global_position) == d:
			total += 1
	_check(seen.size() == total, "every Slums building is reachable from the core (%d of %d)"
			% [seen.size(), total])
	var far := -1
	var near := -1
	for i in _districts.buildings.size():
		if not _districts.buildings[i] or _districts.residents_in(i) == 0 or _districts.is_yours(i) \
				or _districts.district_at(_districts.buildings[i].global_position) != d:
			continue
		if _districts.can_claim(i):
			near = i if near < 0 else near
		else:
			far = i if far < 0 else far
	if far < 0 or near < 0:
		_check(false, "a lived-in building next to yours and one far away")
		return
	_believe_in(far)
	_believe_in(near)
	await _frames(int(DS.tick * 60.0 * 3.0))
	_check(not _districts.is_yours(far), "a believing building far from yours stays out of reach")
	_check(_districts.is_yours(near), "a believing building bordering yours becomes yours")
	_near = near


func _test_awareness() -> void:
	var aware: Awareness = _main.get_node("Awareness")
	var d := _districts.start_district()
	var home := _districts.buildings[_near]
	_check(is_equal_approx(aware.factor_for(home), 1.0), "an unaware district converts at full chance")
	aware.add(d, 0.5)
	_check(absf(aware.factor_for(home) - (1.0 - A.effect * 0.5)) < 0.001,
			"awareness 0.5 makes converting harder (x%.2f)" % aware.factor_for(home))
	aware.add(d, 1.0)
	var floor_ := maxf(A.effect_min, 1.0 - A.effect)
	_check(absf(aware.factor_for(home) - floor_) < 0.001, "full awareness: x%.2f at most" % floor_)
	aware.add(d, -1.0)
	aware.add_martyr(home)
	var martyr := (1.0 - A.effect * A.arrest_awareness) * A.martyr_bonus
	_check(absf(aware.factor_for(home) - martyr) < 0.001,
			"a martyr nearby makes converting easier (x%.2f)" % aware.factor_for(home))
	aware.add(d, -1.0)


func _test_fragility() -> void:
	var fragility: Fragility = _main.get_node("Fragility")
	_check(fragility.is_exposed(_near), "a building with one of yours next to it is exposed")
	_check(not fragility.is_exposed(_districts.headquarters), "the headquarters is never exposed")
	var before := _districts.believers_at(_near)
	fragility.crumble(_near)
	_check(not _districts.is_yours(_near), "a crumbling building is lost")
	await _frames(int(DS.tick * 60.0 * 2.0))
	_check(_districts.believers_at(_near) <= ceili(before / 2.0),
			"half its believers stop believing (%d of %d left)" % [_districts.believers_at(_near), before])


func _test_vandalist() -> void:
	var hq := _districts.buildings[_districts.headquarters]
	var r := _resident_of("Blue collar")
	if r == null:
		_check(false, "a resident to make a Vandalist")
		return
	_population.convert_to(r, Resident.Rank.BELIEVER)
	_check(not _population.staffing.can_train(Resident.Rank.AGENT, hq) \
			or _population.believer_count >= U.agent_unlock_believers,
			"the Vandalist needs %d believers first" % U.agent_unlock_believers)
	_districts.convert_near(hq.global_position, 3)
	await _frames(120)  # believers are counted on a timer
	_check(_population.staffing.train(r, Resident.Rank.AGENT, hq), "a believer trains as a Vandalist at the core")
	_population.staffing.tick_training(r, U.agent_time + 1.0)
	_check(r.rank == Resident.Rank.AGENT, "training makes a Vandalist")
	var murals: Murals = _main.get_node("Murals")
	var painted := [-1]
	murals.painted.connect(func(i: int) -> void: painted[0] = i)
	murals.paint(r, _near, Vector3.FORWARD)
	_check(painted[0] == _near, "he paints a mural")
	_population.bring_out(r)
	var arrests: PoliceArrests = _main.get_node("Arrests")
	_check(arrests.arrest(r), "the police can arrest the Vandalist")
	var aware: Awareness = _main.get_node("Awareness")
	var spot := _districts.building_near(r.body.global_position)
	_check(aware.factor_for(_districts.buildings[spot]) > 1.0, "the arrest makes him a martyr nearby")
	_check(not arrests.bail(), "no bail while nobody is in jail")
	await _frames(5)


func _test_condemnation() -> void:
	var condemnation: Condemnation = _main.get_node("Condemnation")
	_districts.convert_near(_districts.buildings[_districts.headquarters].global_position, 4)
	var target := -1
	for i in _districts.buildings.size():
		if _districts.is_yours(i) and i != _districts.headquarters and _districts.residents_in(i) > 0:
			target = i
			break
	if target < 0:
		_check(false, "a building of yours to condemn")
		return
	condemnation.warning_seconds = 1.0
	condemnation.close_seconds = 6.0
	var lived := _population.residents_in(_districts.buildings[target])
	condemnation.condemn(target)
	_check(condemnation.current() == target, "a notice goes up")
	await _frames(int(60.0 * 2.5))
	_check(condemnation.is_closed(target) and _population.residents_in(_districts.buildings[target]) == 0,
			"after the warning the building is closed and empty")
	await _frames(int(60.0 * 7.0))
	_check(condemnation.current() < 0 and _population.residents_in(_districts.buildings[target]) == lived,
			"it reopens and its people come back (%d)" % lived)


func _believe_in(index: int) -> void:
	for r: Resident in _population.residents:
		if r.home == _districts.buildings[index] and not r.is_believer():
			_population.convert_to(r, Resident.Rank.BELIEVER)


func _test_landmarks() -> void:
	var landmarks: Landmarks = _main.get_node("Landmarks")
	var d := _districts.start_district()
	var core := _districts.core_of(d)
	_check(_districts.headquarters != core, "the base is not the core")
	_check(landmarks.buildings.size() == 5, "five landmarks (%d)" % landmarks.buildings.size())
	var apart := true
	for i in landmarks.buildings:
		apart = apart and i != core and i != _districts.headquarters \
				and _districts.district_of(i) == d
	_check(apart, "landmarks stand in the Slums, apart from the base and the core")
	var before := landmarks.core_ease(d)
	landmarks.mark(landmarks.buildings[0])
	landmarks.mark(landmarks.buildings[1])
	_check(landmarks.marks_in(d) == 2 and landmarks.core_ease(d) > before * 6.0,
			"each mark makes the core easier (x%.2f)" % landmarks.core_ease(d))
	landmarks.clean(landmarks.buildings[0])
	_check(landmarks.marks_in(d) == 1, "City Hall can clean a mark off")
	_check(is_equal_approx(landmarks.mark_cost(landmarks.buildings[0]), LS.redo_cost)
			and is_equal_approx(landmarks.mark_cost(landmarks.buildings[2]), LS.mark_cost),
			"marking a scrubbed landmark again costs more")
	_check(_population.seats == U.seats_base + U.seats_per_clerk * _population.priest_count,
			"believers have seats: %d" % _population.seats)


## The hand's orders: someone set down at a building acts by who they are; a willing
## one gives full effort, a worn-out one still goes but does worse, is worn further, is
## noticed by the neighbours, and quits after one order too many. A canvasser set down
## at a building next to yours starts the sky sign there with no wheel.
func _test_hand_orders() -> void:
	var people: PeopleSettings = load("res://data/people.tres")
	var aware: Awareness = _main.get_node("Awareness")
	var campaigns: Campaigns = _main.get_node("Campaigns")
	var d := _districts.start_district()
	var r: Resident = null
	for x in _population.residents:
		if x.rank == Resident.Rank.BELIEVER and x != _population.priest and x.alive \
				and _population.has_body(x):
			r = x
			break
	if r == null:
		_check(false, "a member on the street to give orders to")
		return
	r.strain = 0.0
	_check(is_equal_approx(_population.effort_of(r), 1.0), "a rested member gives full effort")
	_check(_population._take_order(r) and is_equal_approx(r.strain, people.order_strain),
			"a glad order wears them a little (+%.1f)" % people.order_strain)
	r.strain = 0.8
	var before := aware.level(d)
	_check(_population.effort_of(r) < 1.0, "a worn-out member does worse (x%.2f)" % _population.effort_of(r))
	_check(_population._take_order(r) or r.rank == Resident.Rank.RESIDENT, "they still go, or quit")
	_check(aware.level(d) > before, "the neighbours notice someone hauled off unwilling")
	r.strain = people.strain_leave
	_population.convert_to(r, Resident.Rank.BELIEVER)
	_check(not _population._take_order(r) and r.rank == Resident.Rank.RESIDENT,
			"one order too many and they quit")
	var near := -1
	var far := -1
	for i in _districts.buildings.size():
		if _districts.is_yours(i) or _districts.residents_in(i) == 0:
			continue
		if campaigns.why_not(_districts.buildings[i], Campaigns.Route.PREACH) == "":
			near = i if near < 0 else near
		elif not _districts.borders_yours(i):
			far = i if far < 0 else far
	if near < 0 or far < 0:
		_check(false, "a building in reach and one out of reach for the canvasser")
		return
	var refused := [false]
	campaigns.mark_refused.connect(func(_b: Node3D, _why: String) -> void: refused[0] = true)
	_population.canvasser_set_down.emit(_population.priest, _districts.buildings[far])
	_check(refused[0] and campaigns.route_of(_districts.buildings[far]) < 0,
			"a canvasser set down out of reach is told why not")
	_population.canvasser_set_down.emit(_population.priest, _districts.buildings[near])
	_check(campaigns.route_of(_districts.buildings[near]) == Campaigns.Route.PREACH,
			"a canvasser set down next to yours starts the sky sign there")
	campaigns.clear(_districts.buildings[near])


## A block whose buildings are all yours is complete: its people make more, and its
## buildings are safe from giving way.
func _test_block() -> void:
	var fragility: Fragility = _main.get_node("Fragility")
	var block := _districts.block_of(_districts.headquarters)
	var done := [false]
	_districts.block_changed.connect(func(b: int, complete: bool) -> void:
		done[0] = done[0] or (b == block and complete))
	var members := _districts.block_members(block)
	var hq := _districts.buildings[_districts.headquarters]
	_check(is_equal_approx(_districts.block_bonus(hq), 1.0), "no bonus while the block is not all yours")
	for i in members:
		_believe_in(i)
		if _districts.residents_in(i) == 0:
			_move_believer_into(i, block)
	await _frames(int(DS.tick * 60.0 * 3.0))
	_check(_districts.block_held(block) == members.size(),
			"every building of the base's block is yours (%d of %d)"
			% [_districts.block_held(block), members.size()])
	_check(done[0] and _districts.is_block_complete(block), "so the block is complete")
	_check(is_equal_approx(_districts.block_bonus(hq), DS.block_output_bonus),
			"its people make x%.2f" % DS.block_output_bonus)
	var safe := true
	for i in members:
		safe = safe and not fragility.is_exposed(i)
	_check(safe, "and none of its buildings can give way")


## Someone from another block starts believing and moves into empty building `index`.
func _move_believer_into(index: int, block: int) -> void:
	for r: Resident in _population.residents:
		var home := _districts.index_of(r.home)
		if home >= 0 and _districts.block_of(home) != block and not r.is_believer() \
				and _districts.residents_in(home) > 1:
			_population.convert_to(r, Resident.Rank.BELIEVER)
			_population.move_home(r, _districts.buildings[index])
			return


func _test_capture() -> void:
	var d := _districts.start_district()
	var progress: DistrictProgress = _main.get_node("DistrictProgress")
	var landmarks: Landmarks = _main.get_node("Landmarks")
	_check(progress.value(d) < 1.0 and not _districts.is_controlled(d),
			"the district's bar is not full yet (%d%%)" % roundi(progress.value(d) * 100.0))
	var before := progress.key_places(d)
	var spot := -1
	for i in landmarks.buildings:
		if not landmarks.is_marked(i):
			spot = i
			break
	landmarks.mark(spot)
	_check(is_equal_approx(progress.key_places(d) - before, DS.landmark_points),
			"a marked landmark adds %d%% to the bar" % roundi(DS.landmark_points * 100.0))
	var got := [false]
	_districts.district_controlled.connect(func(x: int) -> void: got[0] = got[0] or x == d)
	var core := _districts.buildings[_districts.core_of(d)]
	_districts.convert_near(core.global_position, _districts.buildings.size())
	_check(is_equal_approx(progress.following(d), DS.following_max),
			"a following alone fills at most %d%% of the bar" % roundi(DS.following_max * 100.0))
	await _frames(int(DS.progress_tick * 60.0 * 2.0))
	_check(got[0] and _districts.is_controlled(d), "a full bar wins the district")


func _resident_of(title: String, believer := false) -> Resident:
	for r in _population.residents:
		if r.archetype and r.archetype.title == title and r.is_believer() == believer \
				and r != _population.priest and r.alive:
			return r
	return null


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
