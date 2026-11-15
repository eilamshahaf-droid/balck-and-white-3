extends Node
## Checks the Slums slice of the core loop in the real main scene: the stage map, the
## Secretary at the main Office, which starts empty and is planned for the purse,
## followers as numbers and the roles that fill themselves, training a Rep under the cap,
## taking a building with a Rep who stays as its Manager, the influence radius and the
## impression a building needs, the pull inside a block, shops, floors, the loan, key
## buildings and inspectors on a timer (papers, coming back, burying the file), what Reps
## cost in paperwork, the block bonus, and winning the district.
##
## Run headless:
##   godot --headless --path . res://tests/cult_test.tscn
## Prints one line per check and exits with code 1 if any failed.

const MAIN := preload("res://scenes/main.tscn")
const U: UnitSettings = preload("res://data/units.tres")
const DS: DistrictSettings = preload("res://data/districts.tres")
const F: FollowersSettings = preload("res://data/followers.tres")
const I: InspectorSettings = preload("res://data/inspectors.tres")
const CS: CampaignSettings = preload("res://data/campaigns.tres")
const TS: TreasurySettings = preload("res://data/treasury.tres")
const BAL: Balance = preload("res://data/balance.tres")
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
var _rooms: Rooms
var _upkeep: UnitUpkeep
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
	_rooms = _main.get_node("Rooms")
	_upkeep = _main.get_node("UnitUpkeep")
	# What the Reps cost is checked on its own; elsewhere it would eat the paperwork the
	# checks count.
	_upkeep.set_physics_process(false)
	await _frames(int(F.tick * 60.0) + 20)
	_test_stage_map()
	_test_opening()
	_test_start()
	_test_slums_people()
	_test_roles()
	_test_training()
	await _test_taking()
	_test_growth()
	_test_pull()
	_test_shop_and_floors()
	_test_loan()
	_test_rooms()
	_test_key_buildings()
	await _test_inspector()
	_test_guard_room()
	_test_unit_upkeep()
	_test_shop_homes_and_upkeep()
	await _test_fixer()
	await _test_block()
	_test_reach()
	await _test_impression()
	await _test_capture()
	print("CULT TEST: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## The opening scene steps through its panels, the last one leading to the first building.
## (Headless it stays hidden; this walks it without closing, which would mark it seen.)
func _test_opening() -> void:
	var screens: StageScreens = _main.get_node("StageScreens")
	var hidden := not screens.is_open()
	screens._show(0)
	for i in DS.opening_count() - 1:
		screens._on_next()
	_check(hidden and DS.opening_count() == 5 and screens._panel == 4
			and screens._next.text == DS.opening_done and screens._line.text == DS.opening_line(4),
			"the opening: hidden headless, %d panels, the last leads to the first building"
				% DS.opening_count())


## The Slums come from the Map Lab's stage file: about a hundred large buildings (each
## needs a Rep of its own, so each is a decision), in about ten large blocks, and the
## base far enough from the core.
func _test_stage_map() -> void:
	var city: City = _main
	var count := _districts.buildings.size()
	var blocks := _districts.block_count()
	_check(count >= 70 and count <= 130, "the stage map has about a hundred buildings (%d)" % count)
	_check(blocks >= 8 and blocks <= 14, "they stand in about ten large blocks (%d)" % blocks)
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
	_check(steps.get(_districts.headquarters, 0) >= 4,
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
	_check(_rooms.layout_of(hq).pieces.is_empty(), "the Office starts empty")
	_check(_followers.total > 0 and _followers.total == _followers.count_of(hq),
			"and with followers of its own (%d)" % _followers.total)
	_check(_followers.count_of(hq) <= _followers.room_of(hq),
			"no more than it has room for (%d)" % _followers.room_of(hq))
	_check(_population.missionary_count == U.start_reps and _population.free_rep_count == U.start_reps,
			"and %d free Rep out and ready" % U.start_reps)
	var editor: RoomEditor = _main.get_node("RoomEditor")
	var hand: GodHand = _main.get_node("GodHand")
	hand.own_building_double_clicked.emit(start)
	_check(editor.visible and editor._shown.size() > 1,
			"a double click on the Office opens its rooms, with every room that fits")
	editor.close()
	var spent := 0.0
	var paper := 0.0
	for id: StringName in [&"shop", &"desks", &"family", &"family"]:
		spent += _rooms.settings.kind(id).money
		paper += _rooms.settings.kind(id).paperwork
	# A second of building upkeep has already gone by.
	_treasury.money = TS.start_money
	_faith.belief_pool = BAL.belief_start
	var planned := true
	for id: StringName in [&"shop", &"desks", &"family", &"family"]:
		planned = planned and _fit(hq, id)
	_check(planned and is_equal_approx(spent, TS.start_money) and is_zero_approx(_treasury.money) \
			and is_equal_approx(_faith.belief_pool, BAL.belief_start - paper),
			"the first lesson (a Shop, a Desk Room, two homes) costs the whole purse, $%d and %d paperwork: no price rise"
				% [roundi(spent), roundi(paper)])
	var family := _rooms.settings.kind(&"family")
	_check(_rooms.money_of(hq, family) > family.money, "the fifth room bought in the Office costs more")
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
	_treasury.money = PLENTY
	_faith.belief_pool = 0.0
	_check(not _menus.choose(&"train_rep", office), "no training without the paperwork")
	_faith.belief_pool = F.rep_paperwork * 10.0
	var before := _followers.total
	var reps := _population.missionary_count
	_check(_menus.choose(&"train_rep", office), "a Rep starts training at the main Office")
	_check(_followers.total == before - 1, "one follower left the pool for it")
	_check(is_equal_approx(_faith.belief_pool, F.rep_paperwork * 9.0),
			"and it cost %d paperwork" % roundi(F.rep_paperwork))
	_finish_training()
	_check(_population.missionary_count == reps + 1 and _population.free_rep_count == reps + 1,
			"after the training there is one more free Rep")
	for i in _followers.rep_cap():
		_menus.choose(&"train_rep", office)
	# A trainee's body may be swapped to a housemate on the way; the Rep still comes out.
	for r in _population.residents:
		if r.job == Resident.Job.TRAIN:
			_population.put_away(r)
	_finish_training()
	_check(_population.reps_out == _followers.rep_cap(),
			"Reps can be trained up to the cap (%d)" % _followers.rep_cap())
	var walking := true
	for r in _population.residents:
		if r.rank == Resident.Rank.MISSIONARY and r.job == Resident.Job.FREE:
			walking = walking and _population.has_body(r)
	_check(walking, "every free Rep has a body to be sent out in")
	_check(_menus.why_not_train(Resident.Rank.MISSIONARY) != "" \
			and not _menus.choose(&"train_rep", office), "and no further")
	_treasury.money = PLENTY
	_check(_fit(_districts.headquarters, &"training") \
			and _menus.why_not_train(Resident.Rank.MISSIONARY) == "",
			"a Training Room fitted into the Office raises the cap by one")


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
	var start := _districts.meter_of(near)
	_districts.add_meter(near, 0.3)
	_check(is_equal_approx(_districts.meter_of(near), start + 0.3) and not _districts.wants_you(near),
			"a takeover meter fills part way")
	_districts.add_meter(near, 1.0 - _districts.meter_of(near) - 0.000001)
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
	var plain := _followers.growth_of(_near)
	_treasury.money = PLENTY
	_check(not _fit(_near, &"duplex") and is_equal_approx(_followers.growth_of(_near), plain),
			"the Slums offer only the basic homes: no Duplex here")


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
	_check(not _followers.has_shop(_near) and _fit(_near, &"shop") and _followers.has_shop(_near),
			"a Shop fitted into a building of yours opens there")
	_check(_districts.is_yours(_near) and _followers.count_of(_near) > 0,
			"and stays yours, with its followers")
	_check(_followers.sellers > sellers and _followers.sellers_in(_near) > 0,
			"followers from the pool take its slots (%d sellers)" % _followers.sellers_in(_near))
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


## Every building of yours is a grid of bays and floors. An empty place is a plain flat;
## rooms of different shapes are fitted in for money, and set what the Committee can keep.
func _test_rooms() -> void:
	var hq := _districts.headquarters
	var kinds := _rooms.settings
	var office := _rooms.layout_of(hq)
	_check(office.columns >= 4 and office.rows >= 3 and not office.pieces.is_empty(),
			"the Office is a grid of bays and floors with the first lesson's rooms in (%d by %d, %d rooms)"
			% [office.columns, office.rows, office.pieces.size()])
	# The Training Room of the earlier test sits where first-fit put it; the plan below
	# needs that place, as a player's would.
	for piece in office.pieces.duplicate():
		if piece.kind.id == &"training":
			_rooms.remove(hq, piece.cells()[0])
	var taken := office.pieces[0].cells()[0]
	_check(not office.fits(kinds.kind(&"guard"), taken, 0), "a room can't go where another is")
	_check(not office.fits(kinds.kind(&"shop"), Vector2i(office.columns - 2, office.rows - 1), 0),
			"a Shop must touch the ground floor")
	_check(not office.fits(kinds.kind(&"archive"), Vector2i(office.columns - 1, office.rows - 2), 0) \
			and kinds.kind(&"archive").turned(1).size() == 3,
			"a room must fit inside the grid, and can be turned")
	_treasury.money = PLENTY
	_faith.belief_pool = PLENTY
	var cap := _followers.paperwork_cap()
	_check(is_equal_approx(cap, kinds.base_paperwork_cap), "paperwork can be kept up to %d" % roundi(cap))
	_check(_fit(hq, &"archive") and _followers.paperwork_cap() > cap, "an Archive keeps more")
	_faith.belief_pool = _followers.paperwork_cap() - 0.01
	_faith._physics_process(5.0)
	_check(is_equal_approx(_faith.belief_pool, _followers.paperwork_cap()),
			"the clerks stop when the archives are full")
	# The first lesson's rooms and the stairs hem the Shop in; the Vault below needs a
	# place by it, so the Shop moves to the left wall, stood on end.
	for id: StringName in [&"family", &"archive", &"desks", &"shop"]:
		for piece in office.pieces.duplicate():
			if piece.kind.id == id:
				_rooms.remove(hq, piece.cells()[0])
	_rooms.place(hq, kinds.kind(&"shop"), Vector2i.ZERO, 1)
	var purse := _followers.money_cap()
	var kinds_vault := kinds.kind(&"vault")
	var lone := Vector2i(-1, -1)
	for y in office.rows:
		for x in office.columns:
			if lone.x < 0 and office.is_free(Vector2i(x, y)) and office.is_free(Vector2i(x + 1, y)) \
					and office.is_free(Vector2i(x, y + 1)) and office.is_free(Vector2i(x + 1, y + 1)) \
					and not office.touches(kinds_vault.cells, Vector2i(x, y), &"shop"):
				lone = Vector2i(x, y)
	_check(lone.x >= 0 and _rooms.why_not(hq, kinds_vault, lone, 0).contains("next to"),
			"a Vault must be next to a Shop")
	_check(_fit(hq, &"vault") and _followers.money_cap() > purse, "and next to one it keeps more money")
	var shop_cell := Vector2i(-1, -1)
	for piece in office.pieces:
		if piece.kind.id == &"shop":
			shop_cell = piece.cells()[0]
	_check(_rooms.why_not_remove(hq, shop_cell) != "" and not _rooms.remove(hq, shop_cell),
			"the Shop can't be taken out while the Vault leans on it")
	var flights_ok := office.stairs.size() == office.rows
	var turns := 0
	for y in office.rows:
		flights_ok = flights_ok and not office.is_free(Vector2i(office.stairs[y], y))
		if y > 0 and office.stairs[y] != office.stairs[y - 1]:
			turns += 1
			# A flight is at least two floors: the floor below a turn is not itself a turn.
			flights_ok = flights_ok and y >= 2 and office.stairs[y - 1] == office.stairs[y - 2]
	_check(flights_ok and turns >= 1,
			"every floor has one stairs place, in flights of two floors that change column (%d turns)" % turns)
	var desks := _followers.clerk_slots()
	var fitted := _fit(hq, &"desks")
	_check(fitted and _followers.clerk_slots() == desks + kinds.kind(&"desks").clerks,
			"a Desk Room seats more clerks")
	if _near < 0:
		return
	_check(_rooms.why_not(_near, kinds.kind(&"desks"), Vector2i.ZERO, 0) != "",
			"office rooms go only in an office")
	var layout := _rooms.layout_of(_near)
	var plain := _followers.room_of(_near)
	_treasury.money = 1000.0
	var family := kinds.kind(&"family")
	var price := _rooms.money_of(_near, family)
	var bought := _rooms.bought_in(_near)
	_check(is_equal_approx(price, family.money * (1.0 + kinds.price_step * bought)),
			"a room costs more for each room already bought in that building (%d bought)" % bought)
	var people := _followers.count_of(_near)
	_check(_fit(_near, &"family") and _followers.room_of(_near) == plain + family.followers - family.cells.size() \
			and is_equal_approx(_treasury.money, 1000.0 - price),
			"a Family Flat houses more than the plain flats it replaces, for money")
	_check(_followers.count_of(_near) - people >= floori((family.followers - family.cells.size()) * F.start_share),
			"and brings half the people it adds at once (%d more)" % (_followers.count_of(_near) - people))
	_check(_rooms.money_of(_near, family) > price, "and the next room there costs more again")
	var piece := layout.pieces[layout.pieces.size() - 1]
	_check(_rooms.remove(_near, piece.cells()[0]) and _followers.room_of(_near) == plain \
			and is_equal_approx(_treasury.money, 1000.0 - price * (1.0 - kinds.refund_share)),
			"taking a room out gives part of its money back")


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
			"a Rep can't take a key building before the Fixer opens it")
	var city: City = _main
	var from := city.nearest_node(_districts.buildings[keys[0]].global_position)
	var to := city.nearest_node(_districts.start_building().global_position)
	var route := city.route(from, to)
	var joined := route[0] == from and route[route.size() - 1] == to
	for n in route.size() - 1:
		joined = joined and city.plan.neighbours[route[n]].has(route[n + 1])
	_check(joined and route.size() > 2, "the streets join a key building to the Office (%d corners)" % route.size())


## Inspectors come on a timer, more at once with exposure, and walk from a key building to
## a building of yours: with paperwork it is paid, short of it he takes what there is and
## comes back later. The hand can throw him. Burying the file lowers the exposure.
func _test_inspector() -> void:
	_faith.exposure = 0.0
	_check(_inspectors.at_once() == 1, "with no exposure, one inspector at a time")
	_faith.exposure = 1.0
	_check(_inspectors.at_once() == 1 + floori(I.per_exposure),
			"at full exposure, %d at once" % (1 + floori(I.per_exposure)))
	_faith.exposure = 0.5
	_faith.belief_pool = _inspectors.bury_cost()
	var first := _inspectors.bury_cost()
	_check(_inspectors.bury() and is_equal_approx(_faith.exposure, 0.5 - I.bury_exposure) \
			and is_zero_approx(_faith.belief_pool), "burying the file costs paperwork and lowers exposure")
	_check(_inspectors.bury_cost() > first, "and costs more the next time")
	_faith.exposure = 0.0
	var out := _inspectors.out.size()
	_inspectors.next_in = 0.1
	_inspectors._physics_process(I.tick)
	_check(_inspectors.out.size() == out + 1 and is_equal_approx(_inspectors.next_in, I.interval_seconds)
			and not _districts.is_base(_inspectors.out[-1].building),
			"when the timer runs out one walks to a building of yours (not the Office); the next in %ds"
				% roundi(I.interval_seconds))
	for inspector in _inspectors.out.duplicate():
		_inspectors._remove(inspector)
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
	if rep == null or door == null or _near < 0:
		_check(false, "a free Rep, a door to send them to and a building of yours")
		return
	_population.bring_out(_population.priest)
	_campaigns.send(door)
	await _frames(int(_campaign_tick() * 60.0) + 5)
	_check(_campaigns.is_sent(door) and not _campaigns.reps_at(door).has(_population.priest) \
			and not _population.priest.body.on_errand,
			"the Secretary is never sent to a marked building")
	_campaigns.clear(door)
	var b := _districts.buildings[_near]
	var inspector := _inspectors.send_to(b)
	var start := inspector.global_position
	await _frames(60)
	_check(inspector.global_position.distance_to(start) > 1.0 and not inspector.arrived,
			"an inspector leaves the nearest key building and walks the streets")
	inspector.on_grabbed()
	inspector.on_released(Vector3.ZERO)
	_check(_inspectors.out.has(inspector) and not inspector.arrived, "the hand can lift him and set him down")
	var cost := _inspectors.demand_cost(_near)
	_check(is_equal_approx(cost, I.demand_paperwork + I.demand_per_building \
			* _districts.converted_buildings().size()),
			"he demands %d paperwork: more for every building you hold" % roundi(cost))
	_faith.belief_pool = cost + 5.0
	inspector.arrived = true
	_inspectors._arrive(inspector)
	_check(is_equal_approx(_faith.belief_pool, 5.0) and _districts.is_yours(_near)
			and not _inspectors.out.has(inspector), "with the paperwork in hand he takes it and leaves")
	inspector = _inspectors.send_to(b)
	inspector.arrived = true
	_faith.belief_pool = 3.0
	_inspectors._arrive(inspector)
	_check(is_zero_approx(_faith.belief_pool) and _districts.is_yours(_near) \
			and not _inspectors.out.has(inspector),
			"short of it he takes what there is, and the building stays yours")
	out = _inspectors.out.size()
	_inspectors.next_in = PLENTY
	for step in ceili(I.return_seconds / I.tick) + 1:
		_inspectors._physics_process(I.tick)
	_check(_inspectors.out.size() == out + 1 and _inspectors.out[-1].building == b,
			"and comes back to it %ds later" % roundi(I.return_seconds))
	for one in _inspectors.out.duplicate():
		_inspectors._remove(one)


## A Guard Room makes the inspectors take less from its building.
func _test_guard_room() -> void:
	if _near < 0:
		return
	var plain := _inspectors.demand_cost(_near)
	_treasury.money = PLENTY
	_faith.belief_pool = PLENTY
	_check(_fit(_near, &"guard") and _inspectors.demand_cost(_near) < plain,
			"a Guard Room makes the inspector take less (%d to %d paperwork)"
				% [roundi(plain), roundi(_inspectors.demand_cost(_near))])


## Every Rep and the Fixer cost paperwork a second, a Manager a quarter of a Rep; with the
## paperwork at 0 a Rep goes back to being a follower, but a Manager stays.
func _test_unit_upkeep() -> void:
	var reps := 0
	var managers := 0
	for r in _population.residents:
		if r.rank == Resident.Rank.MISSIONARY:
			if r.job == Resident.Job.MANAGER:
				managers += 1
			else:
				reps += 1
	var rate := F.rep_upkeep * (reps + managers * F.manager_upkeep_share) \
			+ F.fixer_upkeep * _population.agent_count
	_check(reps > 0 and managers > 0 and is_equal_approx(_upkeep.rate(), rate),
			"%d Reps and %d Managers cost %.2f paperwork a second" % [reps, managers, rate])
	_faith.belief_pool = 10.0
	_upkeep._physics_process(1.0)
	_check(is_equal_approx(_faith.belief_pool, 10.0 - rate), "and it is taken from the pool")
	_faith.belief_pool = 0.0
	var pool := _followers.total
	var count := _population.missionary_count
	for second in ceili(F.revert_seconds) + 1:
		_upkeep._physics_process(1.0)
	_check(_population.missionary_count == count - 1 and _followers.total == pool + 1,
			"with no paperwork for %ds a Rep goes back to being a follower" % roundi(F.revert_seconds))
	var managed := 0
	for r in _population.residents:
		managed += 1 if r.rank == Resident.Rank.MISSIONARY and r.job == Resident.Job.MANAGER else 0
	_check(managed == managers, "and the Managers stay")


## A seller lives over the shop: no more sellers than the building houses. Rooms with
## upkeep cost money a minute, and close when there is none.
func _test_shop_homes_and_upkeep() -> void:
	var hq := _districts.headquarters
	_treasury.money = PLENTY
	_faith.belief_pool = PLENTY
	_followers._grow(PLENTY)
	_followers.recount()
	var slots := _followers.shop_slots(hq)
	var desks := _rooms.totals_of(hq).clerks
	_followers._count[hq] = desks + 1.0
	_followers.recount()
	_check(slots >= 2 and _followers.clerks_in(hq) == desks and _followers.sellers_in(hq) == 1 \
			and _followers.sellers_possible(hq) == 1,
			"people work where they live: with homes for %d, %d clerks and 1 seller of %d"
			% [desks + 1, desks, slots])
	_followers._grow(PLENTY)
	_followers.recount()
	_check(_followers.sellers_in(hq) == slots, "with homes enough every seller's place is filled")
	var plain := _followers.next_seller_net(hq)
	var rate := _followers.upkeep_rate()
	# The Vault of the earlier test took the place beside the shop.
	for piece in _rooms.layout_of(hq).pieces.duplicate():
		if piece.kind.id == &"vault":
			_rooms.remove(hq, piece.cells()[0])
	var stocked := _fit(hq, &"stock")
	_check(stocked and _followers.next_seller_net(hq) > plain and _followers.upkeep_rate() > rate,
			"a Stock Room by a shop makes its sellers bring more, for upkeep (fitted: %s)" % stocked)
	var laundry := _rooms.settings.kind(&"laundry")
	var draw := _rooms.totals_of(hq).impression
	_check(_fit(hq, &"laundry") and is_equal_approx(_rooms.totals_of(hq).impression, draw + laundry.impression),
			"a Laundry Room, the Slums' utility, makes %d impression more" % roundi(laundry.impression))
	_treasury.money = 0.5
	var income := _followers.money_rate
	_followers.money_rate = 0.0
	_treasury._physics_process(10.0)
	_check(is_equal_approx(_rooms.totals_of(hq).impression, draw) and is_zero_approx(_treasury.money),
			"with no money for upkeep the dearest room closes and gives nothing")
	_followers.money_rate = income
	_treasury.money = PLENTY
	_rooms._physics_process(_rooms.settings.upkeep_tick + 1.0)
	_check(is_equal_approx(_rooms.totals_of(hq).impression, draw + laundry.impression),
			"and opens again when there is money")
	var rooms_only := _rooms.upkeep() / 60.0
	_check(is_equal_approx(_followers.upkeep_rate(0.0), rooms_only) \
			and is_equal_approx(_followers.upkeep_rate(F.full_upkeep_at / 2.0) - rooms_only,
				(_followers.upkeep_rate() - rooms_only) / 2.0) \
			and is_equal_approx(_followers.upkeep_rate(F.full_upkeep_at), _followers.upkeep_rate()),
			"the buildings' upkeep grows with money, nothing at $0, all of it at $%d"
				% roundi(F.full_upkeep_at))


## The Fixer opens a key building: the wheel's actions cost paperwork, money and exposure
## and fill its bar; a loud one sends an inspector. Then a Rep can take it, and it is an
## office.
func _test_fixer() -> void:
	var breaches: Breaches = _main.get_node("Breaches")
	var inspectors: Inspectors = _main.get_node("Inspectors")
	var office := _districts.start_building()
	var key := -1
	var gap := INF
	for k in _districts.keys:
		var d2 := _districts.buildings[k].global_position.distance_squared_to(office.global_position)
		if k != _districts.core_of(_districts.start_district()) and d2 < gap:
			gap = d2
			key = k
	var b := _districts.buildings[key]
	_check(breaches.why_not(b) != "" and not breaches.send(b), "with no Fixer nobody can be sent")
	_faith.belief_pool = PLENTY
	_check(_menus.choose(&"train_fixer", office), "a Fixer is trained at the Office")
	_finish_training()
	var far := not _districts.borders_yours(key)
	_check(_population.agent_count == 1 and breaches.send(b) and breaches.target == b,
			"and sent to a key building, next to yours or not (far: %s)" % far)
	# The buildings round it are taken, so that a Rep can take it once it is open.
	for round in 12:
		if not _districts.borders_yours(key):
			_districts.convert_near(b.global_position, 2)
	var fs := breaches.settings
	print("  (guarded at the start of the Fixer test: %s)" % breaches.guarded())
	await _put_at_door(breaches, b)
	var quiet: FixerAction = null
	var noisy: FixerAction = null
	for action in breaches.actions_at(b):
		if action.loud:
			noisy = action
		else:
			quiet = action
	_check(quiet != null and noisy != null and breaches.actions_at(b).size() >= 3,
			"at its door the Fixer has the building's own quiet and loud actions")
	_faith.belief_pool = 0.0
	_check(breaches.why_not_act(b, quiet) != "" and not breaches.act(b, quiet),
			"with no paperwork he can do nothing")
	_faith.belief_pool = 1000.0
	_faith.exposure = 0.0
	_treasury.money = PLENTY
	_check(breaches.act(b, quiet) and is_equal_approx(_faith.belief_pool, 1000.0 - fs.quiet_paperwork)
			and is_equal_approx(_faith.exposure, breaches.exposure_of(quiet)) \
			and not breaches.act(b, quiet),
			"a quiet action costs paperwork and exposure, and he does one at a time")
	_tick_breaches(breaches, fs.quiet_seconds)
	_check(is_equal_approx(breaches.bar_of(b), fs.quiet_progress) and breaches.doing == null,
			"done, it fills %d%% of the bar" % roundi(fs.quiet_progress * 100.0))
	_faith.exposure = fs.gate_exposure
	_check(breaches.why_not_act(b, quiet).contains("lie low"),
			"from %d%% exposure he lies low" % roundi(fs.gate_exposure * 100.0))
	_faith.exposure = 0.0
	var out := inspectors.out.size()
	_check(breaches.act(b, noisy) and inspectors.out.size() == out + 1
			and inspectors.out[-1].building == b, "a loud action sends an inspector to his door")
	_tick_breaches(breaches, fs.loud_seconds)
	var bar := fs.quiet_progress + fs.loud_progress
	_check(is_equal_approx(breaches.bar_of(b), bar), "and fills more of the bar")
	_faith.belief_pool = 0.0
	inspectors._arrive(inspectors.out[-1])
	var loss := fs.guarded_caught_loss if breaches.guarded() else fs.caught_loss
	_check(breaches.target == null and is_equal_approx(breaches.bar_of(b), bar - loss),
			"with no papers for the inspector the Fixer is sent back and the bar drops")
	bar -= loss
	_tick_breaches(breaches, 60.0)
	_check(is_equal_approx(breaches.bar_of(b), bar - fs.left_fade_per_minute),
			"and while he is away the bar falls back %d%% a minute" % roundi(fs.left_fade_per_minute * 100.0))
	_faith.belief_pool = 1000.0
	_faith.exposure = 0.0
	_check(breaches.send(b), "he can be sent again")
	await _put_at_door(breaches, b)
	if not breaches.guarded():
		_treasury.money = PLENTY
		_fit(_districts.headquarters, &"guard")
	bar = breaches.bar_of(b)
	breaches.caught(b)
	_check(breaches.guarded() and is_equal_approx(breaches.exposure_of(quiet),
				fs.quiet_exposure * fs.guarded_exposure_share)
			and is_equal_approx(breaches.bar_of(b), maxf(bar - fs.guarded_caught_loss, 0.0)),
			"a Guard Room covers for him: %d%% less exposure, %d%% of the bar lost instead of %d%%"
				% [roundi((1.0 - fs.guarded_exposure_share) * 100.0),
				roundi(fs.guarded_caught_loss * 100.0), roundi(fs.caught_loss * 100.0)])
	_check(breaches.send(b), "and he goes back")
	await _put_at_door(breaches, b)
	for round in 20:
		if breaches.target == null:
			break
		breaches.act(b, quiet)
		_tick_breaches(breaches, fs.quiet_seconds)
	_check(_districts.is_key_open(key) and breaches.target == null and _campaigns.why_not(b) == "",
			"a full bar opens the key building to a Rep")
	var share := _districts.key_share(_districts.start_district())
	_check(_districts.take(key) and _rooms.is_office(key) \
			and _districts.key_share(_districts.start_district()) > share,
			"taken, it is an office of yours and counts toward the win")
	_treasury.money = PLENTY
	_faith.belief_pool = PLENTY
	_check(_fit(key, &"desks"), "so a Desk Room can be fitted into it")


## A block whose buildings are all yours is complete: followers come to it faster.
func _test_block() -> void:
	var hq := _districts.headquarters
	var block := _districts.block_of(hq)
	var done := [false]
	_districts.block_changed.connect(func(b: int, complete: bool) -> void:
		done[0] = done[0] or (b == block and complete))
	var members := _districts.block_members(block)
	var plain := _followers.growth_of(hq)
	# Outward from the base: each can only be taken next to one already held.
	for pass_ in members.size():
		for i in members:
			_districts.take(i)
	await _frames(int(DS.tick * 60.0 * 3.0))
	_check(_districts.block_held(block) == members.size(),
			"every building of the base's block is yours (%d of %d)"
			% [_districts.block_held(block), members.size()])
	_check(done[0] and _districts.is_block_complete(block), "so the block is complete")
	_check(is_equal_approx(_followers.growth_of(hq) - plain, F.block_growth),
			"and followers come to its buildings faster")


## The influence radius grows with the followers: 1 + floor(sqrt(followers / 60)) borders,
## and a building that far from yours can be worked on; a key building must border yours.
func _test_reach() -> void:
	_check(_followers.reach() == 1 + floori(sqrt(_followers.total / F.reach_followers))
			and _districts.reach == _followers.reach(),
			"%d followers reach %d borders out" % [_followers.total, _followers.reach()])
	var two := -1
	for i in _districts.buildings.size():
		if _districts.buildings[i] and not _districts.is_yours(i) and not _districts.is_key(i) \
				and not _districts.borders_yours(i) and not _districts.yours_within(i, 2).is_empty():
			two = i
			break
	if two < 0:
		_check(false, "a building two borders from yours")
		return
	var reach := _districts.reach
	_districts.reach = 1
	var near_only := not _districts.can_claim(two)
	_districts.reach = 2
	_check(near_only and _districts.can_claim(two),
			"a building two borders out can be worked on only once the radius is two")
	_districts.reach = reach


## An ordinary building needs impression from your buildings near it: each counts, its
## homes and shops more; what the next one needs rises with every one you hold.
func _test_impression() -> void:
	var impression: Impression = _main.get_node("Impression")
	var d := _districts.start_district()
	_check(is_equal_approx(impression.required(d), DS.impression_start
			+ DS.impression_step * maxi(impression.ordinary_held(d) - DS.impression_free, 0)),
			"the next building needs %.1f impression (%d held)" % [
			impression.required(d), impression.ordinary_held(d)])
	var shut := -1
	for round in 80:
		shut = _shut_building(impression)
		if shut >= 0:
			break
		for i in _districts.buildings.size():
			if _districts.buildings[i] and not _districts.is_yours(i) and not _districts.is_key(i) \
					and _districts.can_claim(i) and _districts.district_of(i) == d:
				_districts.take(i)
				break
	if shut < 0:
		_check(false, "taking buildings closes the gate at last")
		return
	var b := _districts.buildings[shut]
	_check(_campaigns.why_not(b).begins_with("impression %d of" % floori(impression.of(shut))),
			"then a Rep is refused: \"%s\"" % _campaigns.why_not(b))
	_treasury.money = PLENTY
	_faith.belief_pool = PLENTY
	var before := impression.of(shut)
	var fitted := false
	for j in _districts.yours_within(shut, _districts.reach):
		if _fit(j, &"laundry"):
			fitted = true
			break
	_check(fitted and is_equal_approx(impression.of(shut), before + _rooms.settings.kind(&"laundry").impression),
			"a Laundry Room next door makes %d impression more"
				% roundi(_rooms.settings.kind(&"laundry").impression))
	for round in 10:
		if _campaigns.why_not(b) == "":
			break
		for j in _districts.yours_within(shut, _districts.reach):
			_fit(j, &"family")
	_check(_campaigns.why_not(b) == "", "and homes near it open the gate again")


## A building within reach that the gate shuts; -1 when there is none.
func _shut_building(impression: Impression) -> int:
	for i in _districts.buildings.size():
		if _districts.buildings[i] and not _districts.is_yours(i) and _districts.can_claim(i) \
				and impression.why_not(i) != "":
			return i
	return -1


func _test_capture() -> void:
	var d := _districts.start_district()
	var progress: DistrictProgress = _main.get_node("DistrictProgress")
	_check(progress.value(d) < 1.0 and not _districts.is_controlled(d),
			"the district's bar is not full yet (%d%%)" % roundi(progress.value(d) * 100.0))
	_check(progress.value(d) >= progress.control(d) and progress.value(d) >= progress.freedom(d) \
			and progress.freedom(d) <= 0.5 + 0.5 * _followers.people_share(d) / DS.control_share + 0.001,
			"the bar is the better of the two ways: key buildings, or a few of them and the people")
	var share := _followers.people_share(d)
	var people := _followers.people_in(d)
	var mine := _followers.followers_in(d)
	_check(share > 0.0 and share < 0.5 and is_equal_approx(share, float(mine) / people),
			"your followers are %d of the district's %d people" % [mine, people])
	_followers._grow(PLENTY)
	_followers.recount()
	var grown := _followers.followers_in(d) - mine
	_check(grown > 0 and _followers.people_in(d) == people + grown,
			"followers you make room for count among the district's people too (+%d both)" % grown)
	var got := [false]
	_districts.district_controlled.connect(func(x: int) -> void: got[0] = got[0] or x == d)
	var core := _districts.buildings[_districts.core_of(d)]
	_districts.convert_near(core.global_position, _districts.buildings.size())
	_check(not _districts.is_controlled(d) and progress.value(d) < 1.0,
			"every ordinary building is not enough: the key buildings are still City Hall's")
	for k in _districts.keys:
		_districts.open_key(k)
		_districts.take(k)
	await _frames(int(DS.progress_tick * 60.0 * 2.0))
	_check(got[0] and _districts.is_controlled(d), "a full bar wins the district")
	var empty := 0
	for i in _districts.buildings.size():
		if _districts.buildings[i] and _population.residents_in(_districts.buildings[i]) == 0:
			empty += 1
	_check(empty == 0, "no building stands empty (%d do)" % empty)


func _campaign_tick() -> float:
	var settings: CampaignSettings = load("res://data/campaigns.tres")
	return settings.tick


## Fit room `id` into the first place of building `index` it goes.
func _fit(index: int, id: StringName) -> bool:
	return _rooms.place_anywhere(index, _rooms.settings.kind(id))


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


## The Fixer is at `b`'s door: no walk to wait for.
func _put_at_door(breaches: Breaches, b: Node3D) -> void:
	breaches.fixer.body.global_position = breaches._door_of(b)
	breaches.fixer.body._errand_route.clear()
	await _frames(5)


func _tick_breaches(breaches: Breaches, seconds: float) -> void:
	for step in ceili(seconds / breaches.settings.tick):
		breaches._physics_process(breaches.settings.tick)
