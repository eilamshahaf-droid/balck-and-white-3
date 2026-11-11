class_name LabPanel
extends CanvasLayer
## The map lab's menu: street style, seed, the sliders listed in MapLabSettings,
## a colour key with each use's share of the land, and a few numbers about the map.

signal changed
signal districts_toggled(shown: bool)

var _params: LabParams
var _styles: Array[StreetStyle] = []
var _sliders := {}                    # StringName property -> HSlider
var _seed := SpinBox.new()
var _shares: Array[Label] = []
var _use_names := PackedStringArray()
var _stats := Label.new()


func setup(params: LabParams, settings: MapLabSettings, styles: Array[StreetStyle]) -> void:
	_params = params
	_styles = styles
	_use_names = settings.use_names
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	frame.custom_minimum_size.x = settings.panel_width
	add_child(frame)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, settings.panel_margin)
	frame.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_heading(list, "Map Lab")
	_add_style_menu(list)
	_add_seed(list)
	for slider in settings.sliders:
		_add_slider(list, slider)
	var districts := CheckBox.new()
	districts.text = "Show districts"
	districts.button_pressed = true
	districts.toggled.connect(districts_toggled.emit)
	list.add_child(districts)
	_heading(list, "Land use")
	for u in settings.use_names.size():
		_add_key(list, settings.use_colours[u])
	_heading(list, "Numbers (real metres)")
	list.add_child(_stats)
	var hint := Label.new()
	hint.text = "Wheel: zoom   Right drag: move"
	hint.modulate = Color(1, 1, 1, 0.6)
	list.add_child(hint)


func show_map(map: LabMap) -> void:
	for u in _shares.size():
		_shares[u].text = "%s  %d%%" % [_use_names[u], roundi(map.share(u) * 100.0)]
	_stats.text = "Blocks: %d\nMean block: %d m²\nStreets: %.1f km" % [
			map.uses.size(), roundi(map.mean_block_area()), map.street_km()]


func _heading(list: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	list.add_child(label)


func _add_style_menu(list: VBoxContainer) -> void:
	var menu := OptionButton.new()
	menu.add_item("Streets: each district its own style")
	for style in _styles:
		menu.add_item("Streets: %s" % style.title)
	menu.select(_params.style + 1)
	menu.item_selected.connect(_on_style_selected)
	list.add_child(menu)


func _add_seed(list: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Seed"
	row.add_child(label)
	_seed.max_value = 999999.0
	_seed.value = _params.map_seed
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed.value_changed.connect(_on_seed_changed)
	row.add_child(_seed)
	var roll := Button.new()
	roll.text = "New map"
	roll.pressed.connect(func() -> void: _seed.value = randi_range(0, int(_seed.max_value)))
	row.add_child(roll)
	list.add_child(row)


func _add_slider(list: VBoxContainer, def: LabSlider) -> void:
	var label := Label.new()
	list.add_child(label)
	var slider := HSlider.new()
	slider.min_value = def.min_value
	slider.max_value = def.max_value
	slider.step = def.step
	slider.value = _params.get(def.property)
	label.text = _slider_text(def, slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		_params.set(def.property, value)
		label.text = _slider_text(def, value)
		changed.emit())
	list.add_child(slider)
	_sliders[def.property] = slider


func _add_key(list: VBoxContainer, colour: Color) -> void:
	var row := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = colour
	swatch.custom_minimum_size = Vector2(18.0, 18.0)
	row.add_child(swatch)
	var label := Label.new()
	row.add_child(label)
	_shares.append(label)
	list.add_child(row)


func _slider_text(def: LabSlider, value: float) -> String:
	return "%s: %s" % [def.label, str(snappedf(value, def.step))]


## A fixed style also moves the spacing sliders to that style's numbers, so the
## menu shows what the map is made with.
func _on_style_selected(index: int) -> void:
	_params.style = index - 1
	if _params.style >= 0:
		var style := _styles[_params.style]
		_set_slider(&"major_spacing", style.major_spacing)
		_set_slider(&"minor_spacing", style.minor_spacing)
		_set_slider(&"dead_end_share", style.dead_end_share)
	changed.emit()


func _set_slider(property: StringName, value: float) -> void:
	var slider: HSlider = _sliders.get(property)
	if slider != null:
		slider.value = value


func _on_seed_changed(value: float) -> void:
	_params.map_seed = int(value)
	changed.emit()
