class_name Followers
extends Node
## Followers as numbers (Eilam's model of 2026-11-13). Every building of yours has room
## for followers and a count that starts part full and grows by itself, by how attractive
## the building is. All of them are one pool. Roles are slots that fill themselves from
## the pool: sellers in shops bring money (each further seller in a shop brings less and
## is paid the same, so only the ones worth their pay are taken on), clerks at the main
## Office make paperwork. A follower with no role is only counted. Training a Rep takes
## one follower out of the pool, and there is a cap on Reps. Buildings of yours also pull
## up the takeover meters of their neighbours inside a block.

## The counts or the rates moved.
signal changed

const F: FollowersSettings = preload("res://data/followers.tres")
const AUTO := -1

@export var districts: Districts
@export var decrees: Decrees
@export var rooms: Rooms

## Everyone in the pool, and how many of them have a role.
var total := 0
var sellers := 0
var clerks := 0
## Money and paperwork a second from the roles.
var money_rate := 0.0
var paperwork_rate := 0.0

var _count := PackedFloat32Array()     # per building: followers living there
var _limit := PackedInt32Array()       # per building: sellers the player allows (AUTO: those worth their pay)
var _staff := PackedInt32Array()       # per building: sellers at work there now
var _others := PackedInt32Array()      # per building: who lives there while it is not yours
var _timer := 0.0


func _ready() -> void:
	districts.layout_ready.connect(_on_layout_ready, CONNECT_ONE_SHOT)
	districts.building_changed.connect(_on_building_changed)
	decrees.decree_issued.connect(func(_kind: StringName, _building: Node3D) -> void: recount())
	rooms.changed.connect(func(_index: int) -> void: recount())
	rooms.placed.connect(_on_room_placed)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or _count.is_empty():
		return
	_timer = F.tick
	_grow(F.tick / 60.0)
	_pull(F.tick / 60.0)
	_fill_roles()
	changed.emit()


## How many followers building `index` has room for: by its rooms (floors add rows).
func room_of(index: int) -> int:
	if districts.buildings[index] == null:
		return 0
	return rooms.room_of(index)


func count_of(index: int) -> int:
	return floori(_count[index])


## How fast followers come to building `index`, 1 = plain, more in a complete block.
## (What rooms draw is the district's attractiveness, see Attractiveness.)
func growth_of(index: int) -> float:
	return 1.0 + (F.block_growth if districts.in_complete_block(index) else 0.0)


## Everyone who lives in district `d`: your followers, and the residents of the buildings
## that are not yours. Followers you make room for are counted here too, so growing
## inside your own buildings moves your share less and less: to grow you take buildings.
func people_in(d: int) -> int:
	var n := 0
	for i in _count.size():
		if districts.buildings[i] == null or districts.district_of(i) != d:
			continue
		n += count_of(i) if districts.is_yours(i) else _others[i]
	return n


## Your followers in district `d`.
func followers_in(d: int) -> int:
	var n := 0
	for i in _count.size():
		if districts.is_yours(i) and districts.district_of(i) == d:
			n += count_of(i)
	return n


## Your share of the people of district `d`, 0..1.
func people_share(d: int) -> float:
	return float(followers_in(d)) / maxi(people_in(d), 1)


## Followers with no role.
func idle() -> int:
	return total - sellers - clerks


## One follower leaves the pool for good (to become a Rep or a Fixer), from the fullest
## building. False when there is nobody without a role.
func take_one() -> bool:
	if idle() <= 0:
		return false
	var best := -1
	for i in _count.size():
		if districts.is_yours(i) and (best < 0 or _count[i] > _count[best]):
			best = i
	if best < 0 or _count[best] < 1.0:
		return false
	_count[best] -= 1.0
	total -= 1
	changed.emit()
	return true


## Count the pool and hand the roles out again now (a shop opened, a slot was added).
func recount() -> void:
	_fill_roles()
	changed.emit()


## Is there a shop in building `index` of yours.
func has_shop(index: int) -> bool:
	return shop_slots(index) > 0


## Slots for sellers in building `index`'s shops.
func shop_slots(index: int) -> int:
	if districts.buildings[index] == null or not districts.is_yours(index):
		return 0
	return rooms.totals_of(index).sellers


## Sellers at work in building `index` now.
func sellers_in(index: int) -> int:
	return _staff[index]


## What the next seller in building `index` would add, money a second, after pay.
func next_seller_net(index: int) -> float:
	var boost := 1.0 + rooms.totals_of(index).shop_boost if districts.is_yours(index) else 1.0
	return F.seller_income * boost * pow(F.seller_falloff, _staff[index]) - F.seller_pay


## Sellers building `index`'s shops can put to work. People work where they live: no
## more than the followers the building houses, after its clerks.
func sellers_possible(index: int) -> int:
	return mini(shop_slots(index), floori(_count[index]) - clerks_in(index))


## Clerks at the desks of building `index`: no more than live there.
func clerks_in(index: int) -> int:
	if not districts.is_yours(index):
		return 0
	return mini(rooms.totals_of(index).clerks, floori(_count[index]))


## Money a second the upkeep of your rooms and buildings costs, with `money` in hand: the
## buildings' share grows from nothing at $0 to all of it at FollowersSettings.full_upkeep_at,
## so a Committee short of money can always climb back.
func upkeep_rate(money := INF) -> float:
	var buildings := 0.0
	for i in _count.size():
		if districts.buildings[i] != null and districts.is_yours(i):
			buildings += F.building_upkeep \
					* (F.complete_block_upkeep_share if districts.in_complete_block(i) else 1.0)
	return (rooms.upkeep() + buildings * clampf(money / F.full_upkeep_at, 0.0, 1.0)) / 60.0


## The player allows one seller more (`step` 1) or fewer (-1) in building `index`'s shop
## than now; from then on that shop keeps to the player's number.
func change_sellers(index: int, step: int) -> void:
	_limit[index] = clampi(_staff[index] + step, 0, sellers_possible(index))
	_fill_roles()
	changed.emit()


## Desks for clerks, in every desk room you have.
func clerk_slots() -> int:
	var n := 0
	for i in _count.size():
		if districts.is_yours(i):
			n += rooms.totals_of(i).clerks
	return n


## Reps the player may have out at once.
func rep_cap() -> int:
	var n := F.rep_cap
	for i in _count.size():
		if districts.is_yours(i):
			n += rooms.totals_of(i).reps
	return n


## How secure building `index` is (its guard rooms).
func security_of(index: int) -> int:
	return rooms.totals_of(index).security


## How much paperwork, and how much money, can be kept.
func paperwork_cap() -> float:
	var cap := rooms.settings.base_paperwork_cap
	for i in _count.size():
		if districts.is_yours(i):
			cap += rooms.totals_of(i).paperwork_cap
	return cap


func money_cap() -> float:
	var cap := rooms.settings.base_money_cap
	for i in _count.size():
		if districts.is_yours(i):
			cap += rooms.totals_of(i).money_cap
	return cap


func _on_layout_ready() -> void:
	var n := districts.buildings.size()
	_count.resize(n)
	_limit.resize(n)
	_limit.fill(AUTO)
	_staff.resize(n)
	_others.resize(n)
	for i in n:
		_others[i] = rooms.plain_room(i) if districts.buildings[i] else 0
	_on_building_changed(districts.headquarters, true)


## A building taken starts part full; one lost takes its followers out of the pool.
func _on_building_changed(index: int, yours: bool) -> void:
	if _count.is_empty():
		return
	_count[index] = room_of(index) * F.start_share if yours else 0.0
	if not yours:
		_limit[index] = AUTO
	_fill_roles()
	changed.emit()


## A new home brings part of the people it adds over plain flats at once, as a building
## taken does (start_share); the rest grow in.
func _on_room_placed(index: int, kind: RoomKind) -> void:
	var extra := kind.followers - kind.cells.size() * rooms.settings.followers_per_cell
	if extra > 0 and not _count.is_empty() and districts.is_yours(index):
		_count[index] = minf(_count[index] + extra * F.start_share, room_of(index))
		recount()


func _grow(minutes: float) -> void:
	for i in _count.size():
		if not districts.is_yours(i):
			continue
		var room := float(room_of(i))
		# Rooms that house fewer were fitted in: the followers over the room move out.
		_count[i] = minf(_count[i] + F.growth_per_minute * growth_of(i) * minutes, room) \
				if _count[i] < room else room


## Buildings of yours raise the meters of their neighbours in their own block; a meter
## nothing holds up sinks back.
func _pull(minutes: float) -> void:
	for j in _count.size():
		if districts.buildings[j] == null or districts.is_yours(j):
			continue
		var pull := 0.0
		for i in districts.borders_of(j):
			if districts.buildings[i] == null or not districts.is_yours(i) \
					or districts.block_of(i) != districts.block_of(j):
				continue
			var one := F.pull_per_minute * growth_of(i)
			pull += one * F.office_pull if districts.is_base(districts.buildings[i]) else one
		if pull > 0.0:
			districts.add_meter(j, pull * minutes)
		elif districts.meter_of(j) > 0.0:
			districts.add_meter(j, -F.sink_per_minute * minutes)


## Count the pool and hand out the roles. People work in the building they live in:
## clerks first, at its desks, then sellers, one at a time to the shop where the next one
## brings in the most, while that is worth the pay (or up to the number the player set
## for that shop).
func _fill_roles() -> void:
	total = 0
	for i in _count.size():
		if districts.is_yours(i):
			total += floori(_count[i])
	var at_desks := 0
	for i in _count.size():
		at_desks += clerks_in(i)
	clerks = mini(at_desks, F.max_clerks)
	var free := total - at_desks
	_staff.fill(0)
	sellers = 0
	money_rate = 0.0
	while free > 0:
		var best := -1
		var best_net := -INF
		for i in _count.size():
			if _staff[i] >= sellers_possible(i):
				continue
			var net := next_seller_net(i)
			var wanted := _staff[i] < _limit[i] if _limit[i] != AUTO else net >= 0.0
			if wanted and net > best_net:
				best_net = net
				best = i
		if best < 0:
			break
		_staff[best] += 1
		sellers += 1
		free -= 1
		money_rate += best_net
	paperwork_rate = clerks * F.clerk_paperwork
