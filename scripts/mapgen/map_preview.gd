extends Node2D
## Top-down view of a generated map, for looking at layouts without starting the
## game. R: a new random seed. Left / Right: the previous / next seed.
## O: switch between the district grid and the organic streets. S: next street style.

const SETTINGS_PATH := "res://data/mapgen.tres"   # load() at run time: typed Archetype array
const SCALE := 2.0            # pixels per metre
const ROAD_WIDTH := 6.0       # pixels
const BLOCK_COLOURS := {
	MapLayout.Block.PARK: Color(0.35, 0.65, 0.35),
	MapLayout.Block.PLAZA: Color(0.85, 0.82, 0.7),
}

var _settings: MapGenSettings = load(SETTINGS_PATH)
var _spec := MapSpec.new()
var _layout: MapLayout
var _streets: OrganicStreets
var _organic := false
var _style := 0
var _title := Label.new()


func _ready() -> void:
	add_child(_title)
	_title.position = Vector2(12.0, 8.0)
	_regenerate()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_R:
			_spec.map_seed = randi()
		KEY_S:
			_style = (_style + 1) % _settings.street_styles.size()
			_organic = true
		KEY_O:
			_organic = not _organic
		KEY_LEFT:
			_spec.map_seed -= 1
		KEY_RIGHT:
			_spec.map_seed += 1
		_:
			return
	_regenerate()


func _draw() -> void:
	if _layout == null:
		return
	var origin := get_viewport_rect().size / 2.0
	if _organic:
		_draw_streets(_streets.minor, origin, Color(0.55, 0.55, 0.6), 2.0)
		_draw_streets(_streets.major, origin, Color(0.95, 0.85, 0.5), 4.0)
		return
	for j in _layout.blocks_z():
		for i in _layout.blocks_x():
			var rect := _block_rect(i, j, origin)
			var kind := _layout.block_at(i, j)
			var colour: Color = BLOCK_COLOURS.get(kind, _layout.district_archetype[_layout.district_of(i, j)].tint)
			if kind == MapLayout.Block.BUILT:
				colour = colour.darkened(0.45 - 0.45 * _layout.skyline_at(i, j))
			draw_rect(rect, colour)
	for d in _layout.district_count():
		var cell := _district_cell(d, origin)
		draw_rect(cell, Color(1, 1, 1, 0.9 if d == _layout.start_district else 0.25), false, 3.0 if d == _layout.start_district else 1.0)
		var archetype := _layout.district_archetype[d]
		draw_string(ThemeDB.fallback_font, cell.position + Vector2(6.0, 18.0), archetype.title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14)


func _regenerate() -> void:
	_layout = MapGenerator.generate(_spec, _settings)
	var style := _settings.street_styles[_style]
	_streets = OrganicStreets.generate(_spec.styled(style))
	_title.text = "seed %d   %s (%d of 100 cities: %s)   R: random   Left / Right: seed   O: grid / organic   S: style" % [_spec.map_seed, style.title, style.city_count, style.examples]
	queue_redraw()


func _block_rect(i: int, j: int, origin: Vector2) -> Rect2:
	var a := _to_screen(Vector2(_layout.avenue_x[i], _layout.street_z[j]), origin)
	var b := _to_screen(Vector2(_layout.avenue_x[i + 1], _layout.street_z[j + 1]), origin)
	var low := Vector2(minf(a.x, b.x), minf(a.y, b.y)) + Vector2.ONE * ROAD_WIDTH / 2.0
	var high := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) - Vector2.ONE * ROAD_WIDTH / 2.0
	return Rect2(low, high - low)


func _district_cell(d: int, origin: Vector2) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for j in _layout.blocks_z():
		for i in _layout.blocks_x():
			if _layout.district_of(i, j) == d:
				var rect := _block_rect(i, j, origin)
				low = low.min(rect.position)
				high = high.max(rect.end)
	return Rect2(low, high - low)


func _to_screen(p: Vector2, origin: Vector2) -> Vector2:
	return origin + Vector2(p.x, -p.y) * SCALE


func _draw_streets(lines: Array[PackedVector2Array], origin: Vector2, colour: Color, width: float) -> void:
	for line in lines:
		var screen := PackedVector2Array()
		for p in line:
			screen.append(_to_screen(p, origin))
		draw_polyline(screen, colour, width)
