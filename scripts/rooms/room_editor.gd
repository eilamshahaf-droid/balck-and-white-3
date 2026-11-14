class_name RoomEditor
extends CanvasLayer
## The room editor: the front of one building of yours as a grid of bays and floors, and
## a palette of rooms to fit into it. Pick a room, turn it (right click or the wheel),
## click a free place. Opened from the building wheel ("Rooms"); the game goes on behind
## it unless the player paused it. Placeholder look: coloured blocks until the rooms
## have models.

const PALETTE_WIDTH := 330.0
const ROW := 58.0
const MINI := 11.0
const MARGIN := 28.0
const TITLE_SIZE := 26
const TEXT_SIZE := 16
const SMALL_SIZE := 13
const REMOVE := -2
const NOTHING := -1

@export var rooms: Rooms
@export var menus: BuildingMenus
@export var districts: Districts
@export var followers: Followers
@export var treasury: Treasury
@export var faith: Faith

var _board := Control.new()
var _index := -1
var _picked := NOTHING   # index into the kinds, REMOVE, or NOTHING
var _turns := 0
var _hover := Vector2i(-1, -1)
var _font: Font = ThemeDB.fallback_font

@onready var _s: RoomSettings = rooms.settings


func _ready() -> void:
	layer = 4
	visible = false
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_on_gui_input)
	add_child(_board)
	menus.rooms_requested.connect(open)
	rooms.changed.connect(func(_i: int) -> void: _board.queue_redraw())
	followers.changed.connect(_board.queue_redraw)
	treasury.money_changed.connect(func(_money: float) -> void: _board.queue_redraw())
	districts.building_changed.connect(_on_building_changed)


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open(building: Node3D) -> void:
	_index = districts.index_of(building)
	_picked = NOTHING
	_turns = 0
	visible = true
	# The hand hides the system pointer over the city; here it is what the player aims with.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_board.queue_redraw()


func close() -> void:
	visible = false
	_index = -1
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Coming back to the window, the hand hides the pointer again: show it while open.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and visible:
		(func() -> void: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE).call_deferred()


func is_open() -> bool:
	return visible


func _on_building_changed(index: int, yours: bool) -> void:
	if index == _index and not yours:
		close()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		if cell != _hover:
			_hover = cell
			_board.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_click(event.position)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP:
				_turns = posmod(_turns + 1, 4)
			MOUSE_BUTTON_WHEEL_DOWN:
				_turns = posmod(_turns - 1, 4)
		_board.queue_redraw()


func _click(at: Vector2) -> void:
	if _close_rect().has_point(at):
		close()
		return
	for k in _s.kinds.size():
		if _palette_rect(k).has_point(at):
			_picked = k if _allowed(_s.kinds[k]) else NOTHING
			_turns = 0
			return
	if _palette_rect(_s.kinds.size()).has_point(at):
		_picked = REMOVE
		return
	var cell := _cell_at(at)
	if cell.x < 0:
		return
	if _picked == REMOVE:
		rooms.remove(_index, cell)
	elif _picked >= 0:
		rooms.place(_index, _s.kinds[_picked], cell, _turns)


func _allowed(kind: RoomKind) -> bool:
	return rooms.is_office(_index) or not kind.office_only


# --- Layout ---

func _cell_size() -> float:
	var layout := rooms.layout_of(_index)
	var room := _board.size - Vector2(PALETTE_WIDTH + MARGIN * 3.0, 230.0)
	return minf(_s.cell_pixels, minf(room.x / layout.columns, room.y / layout.rows))


## The top-left corner of the grid on the screen.
func _grid_origin() -> Vector2:
	var layout := rooms.layout_of(_index)
	var cell := _cell_size()
	var free := _board.size.x - PALETTE_WIDTH - MARGIN * 2.0
	return Vector2((free - layout.columns * cell) / 2.0 + MARGIN,
			110.0 + (_board.size.y - 230.0 - layout.rows * cell) / 2.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	var layout := rooms.layout_of(_index)
	var size := _cell_size()
	# Row 0 is the ground floor, at the bottom.
	return Rect2(_grid_origin() + Vector2(cell.x, layout.rows - 1 - cell.y) * size, Vector2(size, size))


func _cell_at(at: Vector2) -> Vector2i:
	if _index < 0:
		return Vector2i(-1, -1)
	var layout := rooms.layout_of(_index)
	var local := (at - _grid_origin()) / _cell_size()
	if local.x < 0.0 or local.y < 0.0 or local.x >= layout.columns or local.y >= layout.rows:
		return Vector2i(-1, -1)
	return Vector2i(floori(local.x), layout.rows - 1 - floori(local.y))


func _palette_rect(row: int) -> Rect2:
	return Rect2(_board.size.x - PALETTE_WIDTH - MARGIN, 108.0 + row * ROW, PALETTE_WIDTH, ROW - 4.0)


func _close_rect() -> Rect2:
	return Rect2(_board.size.x - 150.0 - MARGIN, 30.0, 150.0, 44.0)


# --- Drawing ---

func _draw_board() -> void:
	if _index < 0 or not districts.is_yours(_index):
		return
	var layout := rooms.layout_of(_index)
	_board.draw_rect(Rect2(Vector2.ZERO, _board.size), _s.backdrop_color)
	var title := "The Office" if rooms.is_office(_index) else "Building"
	_text(Vector2(MARGIN, 52.0), "%s: rooms  (%d bays, %d floors)" % [title, layout.columns, layout.rows],
			TITLE_SIZE, Color.WHITE)
	_text(Vector2(MARGIN, 80.0),
			"Pick a room, turn it with the right button or the wheel, click a free place. An empty place is a plain flat. Esc closes.",
			SMALL_SIZE, Color(1, 1, 1, 0.7))
	for y in layout.rows:
		for x in layout.columns:
			var rect := _cell_rect(Vector2i(x, y)).grow(-1.5)
			_board.draw_rect(rect, _s.flat_color)
	for piece in layout.pieces:
		var cells := piece.cells()
		for cell in cells:
			# No gap between its own cells: a room reads as one shape.
			_board.draw_rect(_cell_rect(cell), piece.kind.color)
		for cell in cells:
			_outline(cell, cells)
		_text(_cell_rect(piece.origin + piece.kind.turned(piece.turns)[0]).position + Vector2(5.0, 17.0),
				piece.kind.title, SMALL_SIZE, _s.grid_color)
	_draw_ghost()
	_draw_palette()
	_draw_totals()
	_text(Vector2(_board.size.x - PALETTE_WIDTH - MARGIN, 92.0), "You have $%d and %d paperwork" % [
			floori(treasury.money), floori(faith.belief_pool)], TEXT_SIZE, Color(1.0, 0.85, 0.4))
	var button := _close_rect()
	_board.draw_rect(button, Color(1, 1, 1, 0.14))
	_text(button.position + Vector2(48.0, 29.0), "Close", TEXT_SIZE, Color.WHITE)


## A dark line on every side of `cell` where its room ends, so two rooms of one kind
## side by side read as two.
func _outline(cell: Vector2i, cells: Array[Vector2i]) -> void:
	var r := _cell_rect(cell)
	var corners := [r.position, r.position + Vector2(r.size.x, 0.0), r.end, r.position + Vector2(0.0, r.size.y)]
	# Up on the grid is up on the screen: the side toward +y is the top edge.
	var sides := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for k in 4:
		if not cells.has(cell + sides[k]):
			_board.draw_line(corners[k], corners[(k + 1) % 4], _s.outline_color, _s.outline_width)


func _draw_ghost() -> void:
	if _hover.x < 0 or _picked == NOTHING:
		return
	if _picked == REMOVE:
		var piece := rooms.layout_of(_index).piece_at(_hover)
		if piece:
			for cell in piece.cells():
				_board.draw_rect(_cell_rect(cell).grow(-1.5), _s.bad_color)
		return
	var kind := _s.kinds[_picked]
	var why := rooms.why_not(_index, kind, _hover, _turns)
	var layout := rooms.layout_of(_index)
	for c in kind.turned(_turns):
		var cell := _hover + c
		if cell.x >= 0 and cell.y >= 0 and cell.x < layout.columns and cell.y < layout.rows:
			_board.draw_rect(_cell_rect(cell).grow(-1.5), _s.ok_color if why == "" else _s.bad_color)
	if why != "":
		_text(_grid_origin() + Vector2(0.0, -12.0), why, TEXT_SIZE, _s.bad_color.lightened(0.3))


func _draw_palette() -> void:
	for k in _s.kinds.size():
		var kind := _s.kinds[k]
		var rect := _palette_rect(k)
		var allowed := _allowed(kind)
		_board.draw_rect(rect, Color(1, 1, 1, 0.22 if k == _picked else 0.08))
		var shade := 1.0 if allowed else 0.35
		for c in kind.turned(_turns if k == _picked else 0):
			var at := rect.position + Vector2(8.0 + c.x * MINI, rect.size.y - 10.0 - (c.y + 1) * MINI)
			_board.draw_rect(Rect2(at, Vector2(MINI - 1.0, MINI - 1.0)), kind.color * Color(1, 1, 1, shade))
		var price := "$%d" % roundi(kind.money)
		if kind.paperwork > 0.0:
			price += " + %d paperwork" % roundi(kind.paperwork)
		_text(rect.position + Vector2(64.0, 21.0), "%s   %s" % [kind.title, price], TEXT_SIZE,
				Color(1, 1, 1, shade))
		_text(rect.position + Vector2(64.0, 41.0), kind.note if allowed else "only in an office",
				SMALL_SIZE, Color(1, 1, 1, 0.65 * shade))
	var remove := _palette_rect(_s.kinds.size())
	_board.draw_rect(remove, Color(1, 0.4, 0.4, 0.3 if _picked == REMOVE else 0.12))
	_text(remove.position + Vector2(64.0, 21.0), "Take a room out", TEXT_SIZE, Color.WHITE)
	_text(remove.position + Vector2(64.0, 41.0), "%d%% of its money back" % roundi(_s.refund_share * 100.0),
			SMALL_SIZE, Color(1, 1, 1, 0.65))


func _draw_totals() -> void:
	var t := rooms.totals_of(_index)
	var line := "Room for %d followers (%d live here)" % [followers.room_of(_index), followers.count_of(_index)]
	if t.sellers > 0:
		line += "     Sellers %d of %d" % [followers.sellers_in(_index), t.sellers]
	if t.clerks > 0:
		line += "     Desks %d" % t.clerks
	if t.attraction > 0.0:
		line += "     Draw +%d%%" % roundi(t.attraction * 100.0)
	if t.security > 0:
		line += "     Security %d" % t.security
	_text(Vector2(MARGIN, _board.size.y - 78.0), line, TEXT_SIZE, Color.WHITE)
	_text(Vector2(MARGIN, _board.size.y - 50.0),
			"The Committee: paperwork up to %d, money up to $%d, %d Reps at a time, %d desks" % [
			roundi(followers.paperwork_cap()), roundi(followers.money_cap()), followers.rep_cap(),
			followers.clerk_slots()], SMALL_SIZE, Color(1, 1, 1, 0.75))


func _text(at: Vector2, line: String, size: int, color: Color) -> void:
	_board.draw_string(_font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
