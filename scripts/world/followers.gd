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
var _timer := 0.0


func _ready() -> void:
	districts.layout_ready.connect(_on_layout_ready, CONNECT_ONE_SHOT)
	districts.building_changed.connect(_on_building_changed)
	decrees.decree_issued.connect(func(_kind: StringName, _building: Node3D) -> void: recount())
	rooms.changed.connect(func(_index: int) -> void: recount())


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


## How fast followers come to building `index`, 1 = plain: the rooms that draw them
## and a complete block.
func attraction_of(index: int) -> float:
	var out := 1.0 + rooms.totals_of(index).attraction
	return out + (F.block_attraction if districts.in_complete_block(index) else 0.0)


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
	return F.seller_income * pow(F.seller_falloff, _staff[index]) - F.seller_pay


## The player allows one seller more (`step` 1) or fewer (-1) in building `index`'s shop
## than now; from then on that shop keeps to the player's number.
func change_sellers(index: int, step: int) -> void:
	_limit[index] = clampi(_staff[index] + step, 0, shop_slots(index))
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


func _grow(minutes: float) -> void:
	for i in _count.size():
		if not districts.is_yours(i):
			continue
		var room := float(room_of(i))
		# Rooms that house fewer were fitted in: the followers over the room move out.
		_count[i] = minf(_count[i] + F.growth_per_minute * attraction_of(i) * minutes, room) \
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
			var one := F.pull_per_minute * attraction_of(i)
			pull += one * F.office_pull if districts.is_base(districts.buildings[i]) else one
		if pull > 0.0:
			districts.add_meter(j, pull * minutes)
		elif districts.meter_of(j) > 0.0:
			districts.add_meter(j, -F.sink_per_minute * minutes)


## Count the pool and hand out the roles: clerks first, then sellers, one at a time to
## the shop where the next one brings in the most, while that is worth the pay (or up to
## the number the player set for that shop).
func _fill_roles() -> void:
	total = 0
	for i in _count.size():
		if districts.is_yours(i):
			total += floori(_count[i])
	clerks = mini(clerk_slots(), total)
	var free := total - clerks
	_staff.fill(0)
	sellers = 0
	money_rate = 0.0
	while free > 0:
		var best := -1
		var best_net := -INF
		for i in _count.size():
			if _staff[i] >= shop_slots(i):
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
