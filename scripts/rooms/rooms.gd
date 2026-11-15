class_name Rooms
extends Node
## The rooms inside every building of yours (Eilam's vertical planning, 2026-11-14).
## A building is a grid of bays and floors; a cell with nothing in it is a plain flat, so
## a building works with no planning at all. The player fits rooms of different shapes
## into it for money and paperwork: better flats, shops, and in an office the desk rooms,
## archives, vaults and training rooms that set how much the Committee makes and can
## keep. More floors make more rows. Followers reads the totals.

## Building `index`'s rooms changed.
signal changed(index: int)
## `kind` was fitted into building `index` (after it was paid for).
signal placed(index: int, kind: RoomKind)
## A room of building `index` closed for want of upkeep, or opened again.
signal room_closed(index: int, kind: RoomKind)
signal room_reopened(index: int, kind: RoomKind)

## What one building's rooms add up to.
class Totals:
	var followers := 0
	var clerks := 0
	var sellers := 0
	var reps := 0
	var security := 0
	var attraction := 0.0
	var paperwork_cap := 0.0
	var money_cap := 0.0
	var shop_boost := 0.0
	## Money a minute its open rooms cost to run.
	var upkeep := 0.0


@export var districts: Districts
@export var treasury: Treasury
@export var faith: Faith
@export var decrees: Decrees

# Loaded at run time: its typed array holds custom resources.
var settings: RoomSettings = load("res://data/rooms.tres")
## The first room the planner offers is still a gift (see is_gift).
var gift := true

var _layouts := {}   # building index -> BuildingLayout
var _totals := {}    # building index -> Totals
var _timer := 0.0


func _ready() -> void:
	districts.building_changed.connect(_on_building_changed)
	decrees.decree_issued.connect(_on_decree_issued)
	treasury.ran_dry.connect(close_dearest)


## Rooms that closed open again, the cheapest first, once there is money.
func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = settings.upkeep_tick
	if treasury.money < settings.reopen_money:
		return
	var best: BuildingLayout.Piece = null
	var where := -1
	for index: int in _layouts:
		for p: BuildingLayout.Piece in (_layouts[index] as BuildingLayout).pieces:
			if not p.open and (best == null or p.kind.upkeep < best.kind.upkeep):
				best = p
				where = index
	if best:
		best.open = true
		_count(where)
		room_reopened.emit(where, best.kind)


## Money a minute all your open rooms cost to run.
func upkeep() -> float:
	var sum := 0.0
	for index: int in _totals:
		sum += (_totals[index] as Totals).upkeep
	return sum


## There is no money for the upkeep: the room that costs most to run closes.
func close_dearest() -> void:
	var worst: BuildingLayout.Piece = null
	var where := -1
	for index: int in _layouts:
		for p: BuildingLayout.Piece in (_layouts[index] as BuildingLayout).pieces:
			if p.open and p.kind.upkeep > 0.0 and (worst == null or p.kind.upkeep > worst.kind.upkeep):
				worst = p
				where = index
	if worst:
		worst.open = false
		_count(where)
		room_closed.emit(where, worst.kind)


## The rooms of building `index` of yours (made on first use).
func layout_of(index: int) -> BuildingLayout:
	if not _layouts.has(index):
		var layout := BuildingLayout.new()
		_measure(layout, index)
		_layouts[index] = layout
		if index == districts.headquarters:
			if layout.rows < settings.office_min_rows:
				decrees.raise_free(districts.buildings[index], settings.office_min_rows - layout.rows)
				_measure(layout, index)
			_furnish_office(layout)
		_count(index)
	return _layouts[index]


func totals_of(index: int) -> Totals:
	layout_of(index)
	return _totals[index]


## Rooms of the office kinds go only in an office: the main Office, and every key
## building you have taken.
func is_office(index: int) -> bool:
	return index == districts.headquarters or districts.is_key(index)


## Why `kind`, turned `turns`, can't go at `origin` in building `index`; "" when it can.
func why_not(index: int, kind: RoomKind, origin: Vector2i, turns: int) -> String:
	if not districts.is_yours(index):
		return "not your building"
	if kind.office_only and not is_office(index):
		return "only in an office"
	if not offers(index, kind):
		return "not in this district"
	var layout := layout_of(index)
	if not layout.fits(kind, origin, turns):
		if not _free(index, kind, origin, turns):
			return "does not fit there"
		if kind.needs_next != &"" and not layout.touches(kind.turned(turns), origin, kind.needs_next):
			return "must be next to a %s" % String(kind.needs_next).capitalize()
		return "must touch the ground floor"
	if not treasury.can_afford(money_of(index, kind)):
		return "needs $%d" % roundi(money_of(index, kind))
	if faith.belief_pool < paperwork_of(index, kind):
		return "needs %d paperwork" % roundi(paperwork_of(index, kind))
	return ""


## What `kind` costs in building `index` now: each room already bought there makes the
## next one dearer (RoomSettings.price_step); the gift room is free.
func money_of(index: int, kind: RoomKind) -> float:
	return 0.0 if is_gift(kind) else kind.money * _escalation(index)


func paperwork_of(index: int, kind: RoomKind) -> float:
	return 0.0 if is_gift(kind) else kind.paperwork * _escalation(index)


## The first room the planner offers (RoomSettings.first_offer) is free, once.
func is_gift(kind: RoomKind) -> bool:
	return gift and kind.id == settings.first_offer


## Rooms bought in building `index` (not those it was given at the start).
func bought_in(index: int) -> int:
	var n := 0
	for p in layout_of(index).pieces:
		if p.bought:
			n += 1
	return n


## Is `kind` on offer for building `index`: office rooms in an office, homes up to the
## stage's tier.
func offers(index: int, kind: RoomKind) -> bool:
	if kind.office_only:
		return is_office(index)
	return kind.tier <= settings.max_tier


## Why the room covering `cell` of building `index` can't be taken out; "" when it can
## (or there is none).
func why_not_remove(index: int, cell: Vector2i) -> String:
	var layout := layout_of(index)
	var piece := layout.piece_at(cell)
	if piece == null:
		return ""
	var leaning := layout.leaning_on(piece)
	return "" if leaning.is_empty() else "the %s next to it needs it" % leaning[0].kind.title


## Fit `kind` into building `index` and pay for it. False when it can't be done.
func place(index: int, kind: RoomKind, origin: Vector2i, turns: int) -> bool:
	if why_not(index, kind, origin, turns) != "":
		return false
	var money := money_of(index, kind)
	treasury.spend_money(money)
	faith.spend(paperwork_of(index, kind), &"room")
	if is_gift(kind):
		gift = false
	layout_of(index).add(kind, origin, turns).paid = money
	_count(index)
	placed.emit(index, kind)
	return true


## Fit `kind` into the first place of building `index` it goes, trying every turn, and
## pay for it. False when there is no place or no money.
func place_anywhere(index: int, kind: RoomKind) -> bool:
	var spot := _first_fit(layout_of(index), kind)
	return spot.z >= 0 and place(index, kind, Vector2i(spot.x, spot.y), spot.z)


## Take out the room covering `cell` of building `index`; part of its money comes back.
func remove(index: int, cell: Vector2i) -> bool:
	var layout := layout_of(index)
	var piece := layout.piece_at(cell)
	if piece == null or why_not_remove(index, cell) != "":
		return false
	layout.pieces.erase(piece)
	treasury.add_money(piece.paid * settings.refund_share)
	_count(index)
	return true


## Followers building `index` has room for: its rooms, and a plain flat in every cell
## with no room.
func room_of(index: int) -> int:
	return totals_of(index).followers + layout_of(index).free_cells() * settings.followers_per_cell


## The first place `kind` goes in `layout`, from the ground floor up: column, row and
## quarter turns, or turns -1 when there is none.
func _first_fit(layout: BuildingLayout, kind: RoomKind) -> Vector3i:
	# As drawn before turned: a shop lies along the street when it can.
	for turns in 4:
		for y in layout.rows:
			for x in layout.columns:
				if layout.fits(kind, Vector2i(x, y), turns):
					return Vector3i(x, y, turns)
	return Vector3i(0, 0, -1)


## Followers building `index` would hold with no rooms fitted: what lives in a building
## that is not yours.
func plain_room(index: int) -> int:
	var layout := BuildingLayout.new()
	_measure(layout, index)
	return layout.free_cells() * settings.followers_per_cell


func _free(index: int, kind: RoomKind, origin: Vector2i, turns: int) -> bool:
	var layout := layout_of(index)
	for c in kind.turned(turns):
		if not layout.is_free(origin + c):
			return false
	return true


## The grid of building `index` from its box: a column a bay, a row a floor.
func _measure(layout: BuildingLayout, index: int) -> void:
	var size := BuildingBox.size_of(districts.buildings[index])
	layout.columns = clampi(roundi(size.x / settings.bay_width), settings.min_columns, settings.max_columns)
	layout.rows = clampi(roundi(size.y / settings.floor_height), settings.min_rows, settings.max_rows)
	_climb(layout, index)


## Carry the staircase of building `index` up to its top floor: a flight of
## stairs_flight floors in one column, the next in another. Floors already climbed keep
## their place (rooms were fitted round them); a single floor left over at the top goes
## on in the column below it.
func _climb(layout: BuildingLayout, index: int) -> void:
	while layout.stairs.size() < layout.rows:
		var level := layout.stairs.size()
		var below := layout.stairs[level - 1] if level > 0 else -1
		if layout.rows - level < settings.stairs_flight and below >= 0:
			layout.stairs.append(below)
			continue
		var column := absi(hash(Vector2i(index, level))) % layout.columns
		if column == below:
			column = (column + 1) % layout.columns
		for k in mini(settings.stairs_flight, layout.rows - level):
			layout.stairs.append(column)


func _furnish_office(layout: BuildingLayout) -> void:
	for id in settings.office_start:
		var kind := settings.kind(id)
		var spot := _first_fit(layout, kind)
		if spot.z >= 0:
			layout.add(kind, Vector2i(spot.x, spot.y), spot.z).bought = false


func _escalation(index: int) -> float:
	return 1.0 + settings.price_step * bought_in(index)


func _count(index: int) -> void:
	var t := Totals.new()
	for p: BuildingLayout.Piece in (_layouts[index] as BuildingLayout).pieces:
		if not p.open:
			continue
		t.shop_boost += p.kind.shop_boost
		t.upkeep += p.kind.upkeep
		t.followers += p.kind.followers
		t.clerks += p.kind.clerks
		t.sellers += p.kind.sellers
		t.reps += p.kind.reps
		t.security += p.kind.security
		t.attraction += p.kind.attraction
		t.paperwork_cap += p.kind.paperwork_cap
		t.money_cap += p.kind.money_cap
	_totals[index] = t
	# The main Office keeps its own name over its door, shop or no shop.
	if index != districts.headquarters:
		decrees.show_shop(districts.buildings[index], t.sellers > 0)
	changed.emit(index)


## A building that is lost loses its rooms.
func _on_building_changed(index: int, yours: bool) -> void:
	if not yours and _layouts.has(index):
		_layouts.erase(index)
		_totals.erase(index)
		if districts.buildings[index]:
			decrees.show_shop(districts.buildings[index], false)
		changed.emit(index)


## More floors: more rows on top.
func _on_decree_issued(kind: StringName, building: Node3D) -> void:
	var index := districts.index_of(building)
	if kind == &"floors" and _layouts.has(index):
		_measure(_layouts[index], index)
		changed.emit(index)
