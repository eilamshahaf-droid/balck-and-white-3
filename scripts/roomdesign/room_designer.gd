class_name RoomDesigner
extends CanvasLayer
## The room designer (scenes/room_designer.tscn), for the Artist and Eilam: furnish each
## room kind at each level with the Kenney furniture, in 3D on a floor grid, and save one
## small file per room (format 1, see RoomDesign).
## Every change is kept at once (in the browser too); "Download room" hands out the file.
## Opened from the title screen; "Back to title" returns.

const Sfx := preload("res://scripts/sfx.gd")

const SETTINGS_PATH := "res://data/room_designer.tres"
const ROOMS_PATH := "res://data/rooms.tres"
const TITLE_SCENE := "res://scenes/title.tscn"
const LEFT_WIDTH := 250.0
const RIGHT_WIDTH := 320.0
const TILE := Vector2(72, 64)
const ICON_WIDTH := 60
const SLIDER_STEP := 0.05
const HEIGHT_MAX := 3.0
const SCALE_MIN := 0.5
const SCALE_MAX := 3.0
const BACKGROUND := Color("f4f1ea")
const PANEL := Color("ffffff")
const INK := Color("2b2a28")
const MUTED := Color("8a857b")
const ACCENT := Color("d9534f")
const DUPLICATE_STEP := 0.4
const HELP := "Pick a piece on the left and click a floor, or drag it in. Furniture takes whole squares of the grid and never overlaps; pictures slide along the back wall; small things go anywhere, and desks and counters take them on top. Click an item and drag it. Drag empty space to orbit, wheel to zoom. R turns, Delete removes, right click drops the piece."

var settings: RoomDesignerSettings
var catalog: FurnitureCatalog
var store: DesignStore
var kinds: Array[RoomKind] = []
var kind: RoomKind
var level := 1
var design: RoomDesign
var selected: RoomDesign.Item
var armed: StringName = &""

var _undo: Array = []   # snapshots of design.items
var _group := "all"
var _preview := DesignerPreview.new()
var _kind_menu := OptionButton.new()
var _level_buttons: Array[Button] = []
var _info := Label.new()
var _status := Label.new()
var _search := LineEdit.new()
var _groups := HFlowContainer.new()
var _palette := GridContainer.new()
var _centre := VBoxContainer.new()
var _help := Label.new()
var _picked_box := VBoxContainer.new()
var _file_dialog: FileDialog


func _ready() -> void:
	layer = 2   # above the art style's screen layer
	settings = load(SETTINGS_PATH)
	var room_settings: RoomSettings = load(ROOMS_PATH)
	kinds = room_settings.kinds
	catalog = FurnitureCatalog.new(settings)
	store = DesignStore.new(settings)
	store.file_loaded.connect(_on_file_loaded)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_preview.settings = settings
	_preview.catalog = catalog
	_preview.edit_started.connect(_snapshot)
	_preview.edited.connect(_on_edited)
	_preview.picked.connect(_pick)
	_preview.placed.connect(_pick)
	_choose_kind(0)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_ESCAPE:
			_arm(&"")
		KEY_DELETE, KEY_BACKSPACE:
			_delete()
		KEY_R:
			_turn()
		KEY_Z:
			if key.ctrl_pressed or key.meta_pressed:
				_undo_last()
		_:
			return
	get_viewport().set_input_as_handled()


func _choose_kind(i: int) -> void:
	kind = kinds[i]
	_kind_menu.select(i)
	_load_design()


func _choose_level(l: int) -> void:
	level = l
	for b in _level_buttons:
		b.button_pressed = b.get_meta("level") == l
	_load_design()


func _load_design() -> void:
	design = store.design_of(kind, level)
	selected = null
	_undo.clear()
	var cols := 0
	var rows := 0
	for c in kind.cells:
		cols = maxi(cols, c.x + 1)
		rows = maxi(rows, c.y + 1)
	_info.text = "%d places, %d across x %d high" % [kind.cells.size(), cols, rows]
	_sync(true)


## Tell the view what to show; rebuild it when the furniture changed.
func _sync(rebuild: bool) -> void:
	_preview.kind = kind
	_preview.level = level
	_preview.design = design
	_preview.selected = selected
	_preview.armed = armed
	if rebuild:
		_preview.rebuild()
	else:
		_preview.refresh_selection()
	_show_picked()


func _snapshot() -> void:
	_undo.append(design.snapshot())
	if _undo.size() > settings.undo_steps:
		_undo.pop_front()


func _on_edited() -> void:
	store.keep(design, kind)
	_sync(true)


func _pick(item: RoomDesign.Item) -> void:
	selected = item
	_sync(false)


func _arm(model: StringName) -> void:
	armed = model
	for b: Button in _palette.get_children():
		b.button_pressed = StringName(b.tooltip_text) == armed
	_sync(false)


func _undo_last() -> void:
	if _undo.is_empty():
		return
	design.items = _undo.pop_back()
	selected = null
	_on_edited()


func _delete() -> void:
	if selected == null:
		return
	_snapshot()
	design.items.erase(selected)
	selected = null
	_on_edited()


func _turn() -> void:
	if selected == null or _type() == FurnitureCatalog.Place.Type.WALL:
		return
	_snapshot()
	selected.rot = (selected.rot + 1) % 4
	if not _settle(selected):
		selected.rot = (selected.rot + 3) % 4
		_undo.pop_back()
		return
	_on_edited()


func _duplicate() -> void:
	if selected == null:
		return
	_snapshot()
	var o := selected.copy()
	var columns := 0
	for c in kind.cells:
		columns = maxi(columns, c.x + 1)
	o.x = minf(o.x + DUPLICATE_STEP, columns * settings.bay_width - 0.1)
	if _type() == FurnitureCatalog.Place.Type.WALL:
		FurnitureSpots.hang(o, o.x, catalog, kind)
	elif _type() == FurnitureCatalog.Place.Type.FLOOR \
			and not FurnitureSpots.settle(o, catalog, kind, design.items):
		Sfx.ui(get_tree(), &"error")
		_undo.pop_back()
		return
	design.items.append(o)
	selected = o
	_on_edited()


## How the picked item is placed.
func _type() -> FurnitureCatalog.Place.Type:
	return FurnitureSpots.type_of(selected, catalog)


## A floor piece back on free squares after it turned or grew; false (with an error
## sound) when there are none. Other pieces always settle.
func _settle(o: RoomDesign.Item) -> bool:
	if FurnitureSpots.type_of(o, catalog) == FurnitureCatalog.Place.Type.FLOOR \
			and not FurnitureSpots.settle(o, catalog, kind, design.items):
		Sfx.ui(get_tree(), &"error")
		return false
	if FurnitureSpots.type_of(o, catalog) == FurnitureCatalog.Place.Type.WALL:
		FurnitureSpots.hang(o, o.x, catalog, kind)
	return true


func _rest() -> void:
	if selected == null:
		return
	_snapshot()
	selected.manual = false
	selected.y = catalog.rest_height(selected, design.items)
	_on_edited()


func _set_depth(z: float) -> void:
	selected.z = z
	if not selected.manual:
		selected.y = catalog.rest_height(selected, design.items)


func _clear() -> void:
	if design.items.is_empty():
		return
	_snapshot()
	design.items.clear()
	selected = null
	_on_edited()


func _download() -> void:
	var path := store.hand_out(DesignStore.file_name(kind.id, level), design.to_dict(kind, settings))
	_status.text = "Saved to %s" % path if path != "" else "Downloaded"


func _download_all() -> void:
	var path := store.hand_out("rooms_all.json", {"format": settings.format, "rooms": store.all_rooms()})
	_status.text = "Saved to %s" % path if path != "" else "Downloaded"


func _open_file() -> void:
	if OS.has_feature("web"):
		store.pick_in_browser()
		return
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray(["*.json ; Room files"])
		_file_dialog.file_selected.connect(store.read_file)
		add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_loaded(designs: Array[RoomDesign]) -> void:
	if designs.is_empty():
		_status.text = "Could not read that file"
		return
	_status.text = "Loaded %d room(s)" % designs.size()
	var first := designs[0]
	for i in kinds.size():
		if kinds[i].id == first.room:
			level = first.level
			for b in _level_buttons:
				b.button_pressed = b.get_meta("level") == level
			_choose_kind(i)
			return
	_load_design()


# --- building the screen ---


func _build() -> void:
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.theme = _theme()
	add_child(root)
	root.add_child(_top_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	body.add_child(_left())
	_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_centre.add_child(_panel_of(_preview))
	_preview.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_centre)
	body.add_child(_right())
	_help.text = HELP
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.add_theme_color_override("font_color", MUTED)
	_centre.add_child(_help)


func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "  Room Designer"
	title.add_theme_font_size_override("font_size", 18)
	bar.add_child(title)
	for k in kinds:
		_kind_menu.add_item("%s (%s)" % [k.title, settings.category_of(k.id)])
	_kind_menu.item_selected.connect(_choose_kind)
	bar.add_child(_kind_menu)
	var levels := ButtonGroup.new()
	for l in range(1, settings.levels + 1):
		var b := _button(bar, "Level %d" % l, _choose_level.bind(l))
		b.toggle_mode = true
		b.button_group = levels
		b.button_pressed = l == level
		b.set_meta("level", l)
		_level_buttons.append(b)
	_info.add_theme_color_override("font_color", MUTED)
	bar.add_child(_info)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_status.add_theme_color_override("font_color", MUTED)
	bar.add_child(_status)
	_button(bar, "Undo", _undo_last)
	_button(bar, "Download room", _download)
	_button(bar, "Download all", _download_all)
	_button(bar, "Load file", _open_file)
	_button(bar, "Clear room", _clear)
	_button(bar, "Back to title", func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))
	return bar


func _left() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = LEFT_WIDTH
	_search.placeholder_text = "search furniture"
	_search.text_changed.connect(func(_t: String) -> void: _fill_palette())
	box.add_child(_search)
	for g in catalog.group_names():
		var b := Button.new()
		b.text = g
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			_group = g
			_fill_palette())
		_groups.add_child(b)
	box.add_child(_groups)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette.columns = 3
	scroll.add_child(_palette)
	box.add_child(scroll)
	_fill_palette()
	return _panel_of(box)


func _right() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = RIGHT_WIDTH
	box.add_child(_picked_box)
	return _panel_of(box)


func _fill_palette() -> void:
	for child in _palette.get_children():
		child.queue_free()
	for m in catalog.models_in(_group, _search.text):
		var b := Button.new()
		b.custom_minimum_size = TILE
		b.icon = catalog.icon(m)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", ICON_WIDTH)
		b.text = String(m).left(12)
		b.tooltip_text = m
		b.add_theme_font_size_override("font_size", 9)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = m == armed
		b.pressed.connect(func() -> void: _arm(&"" if armed == m else m))
		b.set_drag_forwarding(func(_at: Vector2) -> Variant:
			var shot := TextureRect.new()
			shot.texture = catalog.icon(m)
			shot.custom_minimum_size = Vector2(ICON_WIDTH, ICON_WIDTH / 2.0)
			shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			b.set_drag_preview(shot)
			return {"model": m}, Callable(), Callable())
		_palette.add_child(b)


func _show_picked() -> void:
	for child in _picked_box.get_children():
		child.queue_free()
	if selected == null:
		var none := Label.new()
		none.text = "Nothing picked."
		none.add_theme_color_override("font_color", MUTED)
		_picked_box.add_child(none)
		return
	var name_label := Label.new()
	name_label.text = String(selected.model)
	name_label.add_theme_font_size_override("font_size", 16)
	_picked_box.add_child(name_label)
	var type := _type()
	if type == FurnitureCatalog.Place.Type.FLOOR:
		var n := FurnitureSpots.squares(selected, catalog)
		var takes := Label.new()
		takes.text = "Takes %d x %d squares of the floor" % [n.x, n.y]
		takes.add_theme_color_override("font_color", MUTED)
		_picked_box.add_child(takes)
	if type == FurnitureCatalog.Place.Type.SMALL:
		var slots := HBoxContainer.new()
		var slot := RoomDesign.depth_slot(selected.z, settings.depth_band)
		for i in 3:
			var b := _button(slots, ["Back", "Mid", "Front"][i], func() -> void:
				_snapshot()
				_set_depth(settings.preset(i))
				_on_edited())
			b.toggle_mode = true
			b.button_pressed = i == slot
		_picked_box.add_child(slots)
		var reach := settings.depth / 2.0 - settings.wall_margin
		_slider("Depth (back to front), m", -reach, reach, selected.z, func(v: float) -> void:
			_set_depth(v))
	if type != FurnitureCatalog.Place.Type.FLOOR:
		_slider("Height above floor, m", 0.0, HEIGHT_MAX, selected.y, func(v: float) -> void:
			selected.y = v
			selected.manual = true)
	_slider("Size, x", SCALE_MIN, SCALE_MAX, selected.scale, func(v: float) -> void:
		var old := selected.scale
		selected.scale = v
		if not _settle(selected):
			selected.scale = old)
	var row := HFlowContainer.new()
	if type != FurnitureCatalog.Place.Type.WALL:
		_button(row, "Turn (R)", _turn)
	_button(row, "Duplicate", _duplicate)
	_button(row, "Delete", _delete)
	if type == FurnitureCatalog.Place.Type.SMALL:
		_button(row, "Rest on floor/surface", _rest)
	_picked_box.add_child(row)


## A labelled slider for the picked item; dragging it moves the item live, letting go
## keeps the change.
func _slider(title: String, lo: float, hi: float, value: float, apply: Callable) -> void:
	var label := Label.new()
	label.add_theme_color_override("font_color", MUTED)
	label.text = "%s: %.2f" % [title, value]
	_picked_box.add_child(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = SLIDER_STEP
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.drag_started.connect(_snapshot)
	s.value_changed.connect(func(v: float) -> void:
		apply.call(v)
		label.text = "%s: %.2f" % [title, v]
		_preview.refresh_selection())
	s.drag_ended.connect(func(_changed: bool) -> void: _on_edited())
	_picked_box.add_child(s)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _panel_of(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", style)
	p.add_child(content)
	return p


func _theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", 13)
	t.set_font_size("font_size", "Button", 13)
	return t
