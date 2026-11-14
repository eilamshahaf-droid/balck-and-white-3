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


@export var districts: Districts
@export var treasury: Treasury
@export var faith: Faith
@export var decrees: Decrees

# Loaded at run time: its typed array holds custom resources.
var settings: RoomSettings = load("res://data/rooms.tres")

var _layouts := {}   # building index -> BuildingLayout
var _totals := {}    # building index -> Totals


func _ready() -> void:
	districts.building_changed.connect(_on_building_changed)
	decrees.decree_issued.connect(_on_decree_issued)


## The rooms of building `index` of yours (made on first use).
func layout_of(index: int) -> BuildingLayout:
	if not _layouts.has(index):
		var layout := BuildingLayout.new()
		_measure(layout, index)
		_layouts[index] = layout
		if index == districts.headquarters:
			_furnish_office(layout)
		_count(index)
	return _layouts[index]


func totals_of(index: int) -> Totals:
	layout_of(index)
	return _totals[index]


## Rooms of the office kinds go only in an office: today the main Office.
func is_office(index: int) -> bool:
	return index == districts.headquarters


## Why `kind`, turned `turns`, can't go at `origin` in building `index`; "" when it can.
func why_not(index: int, kind: RoomKind, origin: Vector2i, turns: int) -> String:
	if not districts.is_yours(index):
		return "not your building"
	if kind.office_only and not is_office(index):
		return "only in an office"
	if not layout_of(index).fits(kind, origin, turns):
		return "must touch the ground floor" if kind.ground_only and _free(index, kind, origin, turns) \
				else "does not fit there"
	if not treasury.can_afford(kind.money):
		return "needs $%d" % roundi(kind.money)
	if faith.belief_pool < kind.paperwork:
		return "needs %d paperwork" % roundi(kind.paperwork)
	return ""


## Fit `kind` into building `index` and pay for it. False when it can't be done.
func place(index: int, kind: RoomKind, origin: Vector2i, turns: int) -> bool:
	if why_not(index, kind, origin, turns) != "":
		return false
	treasury.spend_money(kind.money)
	faith.spend(kind.paperwork)
	layout_of(index).add(kind, origin, turns)
	_count(index)
	return true


## Fit `kind` into the first place of building `index` it goes, trying every turn, and
## pay for it. False when there is no place or no money.
func place_anywhere(index: int, kind: RoomKind) -> bool:
	var layout := layout_of(index)
	for y in layout.rows:
		for x in layout.columns:
			for turns in 4:
				if place(index, kind, Vector2i(x, y), turns):
					return true
	return false


## Take out the room covering `cell` of building `index`; part of its money comes back.
func remove(index: int, cell: Vector2i) -> bool:
	var layout := layout_of(index)
	var piece := layout.piece_at(cell)
	if piece == null:
		return false
	layout.pieces.erase(piece)
	treasury.add_money(piece.kind.money * settings.refund_share)
	_count(index)
	return true


## Followers building `index` has room for: its rooms, and a plain flat in every cell
## with no room.
func room_of(index: int) -> int:
	return totals_of(index).followers + layout_of(index).free_cells() * settings.followers_per_cell


func _free(index: int, kind: RoomKind, origin: Vector2i, turns: int) -> bool:
	var layout := layout_of(index)
	for c in kind.turned(turns):
		var cell := origin + c
		if cell.x < 0 or cell.y < 0 or cell.x >= layout.columns or cell.y >= layout.rows \
				or layout.piece_at(cell):
			return false
	return true


## The grid of building `index` from its box: a column a bay, a row a floor.
func _measure(layout: BuildingLayout, index: int) -> void:
	var size := BuildingBox.size_of(districts.buildings[index])
	layout.columns = clampi(roundi(size.x / settings.bay_width), settings.min_columns, settings.max_columns)
	layout.rows = clampi(roundi(size.y / settings.floor_height), settings.min_rows, settings.max_rows)


func _furnish_office(layout: BuildingLayout) -> void:
	for line in settings.office_start:
		var parts := line.split(" ")
		var kind := settings.kind(StringName(parts[0]))
		var origin := Vector2i(int(parts[1]), int(parts[2]))
		if kind and layout.fits(kind, origin, int(parts[3])):
			layout.add(kind, origin, int(parts[3]))


func _count(index: int) -> void:
	var t := Totals.new()
	for p: BuildingLayout.Piece in (_layouts[index] as BuildingLayout).pieces:
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
