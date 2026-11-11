extends Node2D
## The map lab: a top-down 2D playground for the city map generator, coloured by
## what each block is used for. The menu on the left changes the numbers; the map
## is made again a moment after the last change.

const SETTINGS_PATH := "res://data/map_lab.tres"   # load() at run time: typed arrays
const MAPGEN_PATH := "res://data/mapgen.tres"
const LABEL_SIZE := 14

var _settings: MapLabSettings = load(SETTINGS_PATH)
var _mapgen: MapGenSettings = load(MAPGEN_PATH)
var _params: LabParams
var _map: LabMap
var _texture: ImageTexture
var _main_lines: Array[PackedVector2Array] = []   # in pixels, made once per map
var _side_lines: Array[PackedVector2Array] = []
var _show_districts := true
var _rebuild_timer := Timer.new()

@onready var _panel: LabPanel = $Panel
@onready var _camera: LabCamera = $Camera


func _ready() -> void:
	RenderingServer.set_default_clear_color(_settings.background_colour)
	_params = _settings.defaults.duplicate() as LabParams
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = _settings.rebuild_delay
	_rebuild_timer.timeout.connect(_rebuild)
	add_child(_rebuild_timer)
	_camera.setup(_settings)
	_panel.setup(_params, _settings, _mapgen.street_styles)
	_panel.changed.connect(_rebuild_timer.start.bind(_settings.rebuild_delay))
	_panel.districts_toggled.connect(_on_districts_toggled)
	_rebuild()


func _draw() -> void:
	var ppm := _settings.pixels_per_metre
	var half := _map.spec.field_size / 2.0
	draw_texture_rect(_texture, Rect2(-half * ppm, _map.spec.field_size * ppm), false)
	# The painted cells give the blocks; lines on top keep the streets crisp.
	for line in _side_lines:
		draw_polyline(line, _settings.road_colour, _settings.side_road_width * ppm, true)
	for line in _main_lines:
		draw_polyline(line, _settings.main_road_colour, _settings.main_road_width * ppm, true)
	if not _show_districts:
		return
	var spec := _map.spec
	var cell := Vector2(spec.field_size.x / spec.columns, spec.field_size.y / spec.rows)
	var font := ThemeDB.fallback_font
	for d in _map.layout.district_count():
		var low := -half + Vector2(d % spec.columns, floori(float(d) / spec.columns)) * cell
		var rect := Rect2(Vector2(low.x, -(low.y + cell.y)) * ppm, cell * ppm)
		var start := d == _map.layout.start_district
		draw_rect(rect, Color(1, 1, 1, 0.9 if start else 0.35), false, 3.0 if start else 1.0)
		var title := _map.layout.district_archetype[d].title + ("  (start)" if start else "")
		_label(font, rect.position + Vector2(6.0, 18.0), title)
		_label(font, rect.position + Vector2(6.0, 36.0), _map.styles[d].title)


func _label(font: Font, at: Vector2, text: String) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, 4, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE)


func _rebuild() -> void:
	_map = LabMap.build(_params, _settings, _mapgen)
	_texture = ImageTexture.create_from_image(_paint())
	_main_lines = _to_pixels(_map.major)
	_side_lines = _to_pixels(_map.minor)
	_panel.show_map(_map)
	queue_redraw()


## One pixel per cell, north at the top.
func _paint() -> Image:
	var blocks := _map.blocks
	var image := Image.create(blocks.size.x, blocks.size.y, false, Image.FORMAT_RGB8)
	for y in blocks.size.y:
		for x in blocks.size.x:
			image.set_pixel(x, blocks.size.y - 1 - y, _colour(blocks.label_at(x, y)))
	return image


func _to_pixels(lines: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for line in lines:
		var pixels := PackedVector2Array()
		for p in line:
			pixels.append(Vector2(p.x, -p.y) * _settings.pixels_per_metre)
		out.append(pixels)
	return out


func _colour(label: int) -> Color:
	if label == CityBlocks.MAIN_ROAD:
		return _settings.main_road_colour
	if label == CityBlocks.SIDE_ROAD:
		return _settings.road_colour
	var use := _map.uses[label]
	return _settings.pavement_colour if use == LandUse.PAVEMENT else _settings.use_colours[use]


func _on_districts_toggled(shown: bool) -> void:
	_show_districts = shown
	queue_redraw()
