class_name LabMap
extends RefCounted
## One map made by the lab: districts, streets, blocks and their uses. Pure data,
## so the view, the menu's numbers and the test all read the same thing.

var spec: MapSpec
var layout: MapLayout
var styles: Array[StreetStyle] = []   # one per district
var mixes: Array[LandUseMix] = []     # one per district
var major: Array[PackedVector2Array] = []
var minor: Array[PackedVector2Array] = []
var blocks: CityBlocks
var uses := PackedInt32Array()        # LandUse.Use or LandUse.PAVEMENT per block


static func build(params: LabParams, settings: MapLabSettings,
		mapgen: MapGenSettings) -> LabMap:
	var out := LabMap.new()
	out._build(params, settings, mapgen)
	return out


## Share of the built-up block area (pavement left out) given to `use`.
func share(use: int) -> float:
	var total := 0.0
	var of_use := 0.0
	for b in uses.size():
		if uses[b] == LandUse.PAVEMENT:
			continue
		total += blocks.areas[b]
		if uses[b] == use:
			of_use += blocks.areas[b]
	return of_use / total if total > 0.0 else 0.0


## Mean block area in real m², squares and pavement left out.
func mean_block_area() -> float:
	var total := 0.0
	var count := 0
	for b in uses.size():
		if uses[b] >= 0 and uses[b] != LandUse.Use.SQUARE:
			total += blocks.areas[b]
			count += 1
	return total / count / (spec.metres_scale * spec.metres_scale) if count > 0 else 0.0


## Street length in real kilometres.
func street_km() -> float:
	return (blocks.main_road_length + blocks.side_road_length) / spec.metres_scale / 1000.0


func _build(params: LabParams, settings: MapLabSettings, mapgen: MapGenSettings) -> void:
	spec = MapSpec.new()
	spec.map_seed = params.map_seed
	spec.major_spacing = params.major_spacing * spec.metres_scale
	spec.minor_spacing = params.minor_spacing * spec.metres_scale
	spec.dead_end_share = params.dead_end_share
	layout = MapGenerator.generate(spec, mapgen)
	for archetype in layout.district_archetype:
		var mix := settings.mix_for(archetype.id)
		mixes.append(mix)
		styles.append(mapgen.street_styles[params.style] if params.style >= 0
				else _style(mix.street_style, mapgen))
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.map_seed
	var field := DistrictField.new(spec, rng, styles, params.curviness)
	var tracer := StreetTracer.new(spec, field, rng)
	major = tracer.major
	minor = tracer.minor
	var all := major + minor
	EndJoiner.join(all, spec.minor_spacing * settings.join_reach, params.dead_end_share, rng)
	major.assign(all.slice(0, major.size()))
	minor.assign(all.slice(major.size()))
	blocks = CityBlocks.find(major, minor, spec.field_size, settings)
	uses = LandUsePlanner.plan(blocks, mixes, spec, params, settings, rng)


static func _style(id: StringName, mapgen: MapGenSettings) -> StreetStyle:
	for style in mapgen.street_styles:
		if style.id == id:
			return style
	push_error("Unknown street style '%s'" % id)
	return mapgen.street_styles[0]
