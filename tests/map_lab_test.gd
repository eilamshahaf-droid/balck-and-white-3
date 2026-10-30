extends Node
## Headless check of the map lab: same numbers, same map; every block gets a use;
## the menu's sliders point at real numbers; each street choice makes a map.

const SETTINGS_PATH := "res://data/map_lab.tres"   # load() at run time: typed arrays
const MAPGEN_PATH := "res://data/mapgen.tres"

var _failed := 0


func _ready() -> void:
	var settings: MapLabSettings = load(SETTINGS_PATH)
	var mapgen: MapGenSettings = load(MAPGEN_PATH)
	var params := settings.defaults.duplicate() as LabParams
	_check("one land use mix per archetype", _mixes_cover(settings, mapgen))
	_check("one name and colour per use", settings.use_names.size() == LandUse.Use.size()
			and settings.use_colours.size() == LandUse.Use.size())
	var sliders_ok := true
	for slider in settings.sliders:
		sliders_ok = sliders_ok and slider.property in params
	_check("every slider moves a LabParams number", sliders_ok)
	var a := LabMap.build(params, settings, mapgen)
	var b := LabMap.build(params, settings, mapgen)
	_check("same numbers, same streets", a.major == b.major and a.minor == b.minor)
	_check("same numbers, same uses", a.uses == b.uses)
	_check("blocks are found", a.blocks.count() > 100)
	_check("every block has a use", a.uses.size() == a.blocks.count())
	_check("districts take their archetype's street style", _styles_follow(a, settings))
	var total := 0.0
	for u in LandUse.Use.size():
		total += a.share(u)
	_check("use shares add up to the whole", absf(total - 1.0) < 0.001)
	params.parks = 0.0
	_check("parks at zero leaves no parks",
			LabMap.build(params, settings, mapgen).share(LandUse.Use.PARK) == 0.0)
	params.parks = 1.0
	var styles_ok := true
	for s in mapgen.street_styles.size():
		params.style = s
		var map := LabMap.build(params, settings, mapgen)
		styles_ok = styles_ok and map.blocks.count() > 20
		for style in map.styles:
			styles_ok = styles_ok and style == mapgen.street_styles[s]
	_check("each fixed street style makes a map", styles_ok)
	print("MAP LAB TEST: ", "PASS" if _failed == 0 else "%d FAILED" % _failed)
	get_tree().quit(_failed)


func _mixes_cover(settings: MapLabSettings, mapgen: MapGenSettings) -> bool:
	for archetype in mapgen.archetypes:
		var found := false
		for mix in settings.mixes:
			found = found or mix.archetype == archetype.id
		if not found:
			return false
	return true


func _styles_follow(map: LabMap, settings: MapLabSettings) -> bool:
	for d in map.styles.size():
		var wanted := settings.mix_for(map.layout.district_archetype[d].id).street_style
		if map.styles[d].id != wanted:
			return false
	return true


func _check(label: String, passed: bool) -> void:
	print("  ", "ok  " if passed else "FAIL", "  ", label)
	if not passed:
		_failed += 1
