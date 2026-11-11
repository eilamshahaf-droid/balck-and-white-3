extends Node
## Checks the Slums slice of the core loop in the real main scene: who lives in
## the start district, the high priest at the start building, the conversion
## formula, believers' output and needs, training, and capturing the district.
##
## Run headless:
##   godot --headless --path . res://tests/cult_test.tscn
## Prints one line per check and exits with code 1 if any failed.

const MAIN := preload("res://scenes/main.tscn")
const U: UnitSettings = preload("res://data/units.tres")
const DS: DistrictSettings = preload("res://data/districts.tres")

var _main: Node3D
var _population: Population
var _districts: Districts
var _failures := 0


func _ready() -> void:
	_main = MAIN.instantiate()
	add_child(_main)
	_population = _main.get_node("Population")
	_districts = _main.get_node("Districts")
	await _frames(20)
	_test_start()
	_test_slums_people()
	_test_chance()
	_test_output_and_needs()
	await _test_training()
	await _test_borders()
	_test_capture()
	print("CULT TEST: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


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
	_check(_districts.is_unlocked(DS.start_district), "the start district is open")
	_check(not _districts.is_unlocked((DS.start_district + 1) % _districts.district_count()),
			"the next district is locked")


func _test_slums_people() -> void:
	var counts := {}
	var total := 0
	for r in _population.residents:
		if r.home == null or _districts.district_at(r.home.global_position) != DS.start_district:
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
	var d := DS.start_district
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


func _believe_in(index: int) -> void:
	for r: Resident in _population.residents:
		if r.home == _districts.buildings[index] and not r.is_believer():
			_population.convert_to(r, Resident.Rank.BELIEVER)


func _test_capture() -> void:
	var d := DS.start_district
	var got := [false]
	_districts.district_controlled.connect(func(x: int) -> void: got[0] = got[0] or x == d)
	var core := _districts.buildings[_districts.core_of(d)]
	_districts.convert_near(core.global_position, 400)
	_check(got[0] and _districts.is_controlled(d), "taking most of the Slums captures the district")


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
