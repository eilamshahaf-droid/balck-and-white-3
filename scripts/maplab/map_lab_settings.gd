class_name MapLabSettings
extends Resource
## Everything the map lab needs that is not a menu value: the menu itself, how
## each archetype uses its land, how blocks are found and the colours.

@export var defaults: LabParams
@export var sliders: Array[LabSlider] = []
@export var mixes: Array[LandUseMix] = []
@export_group("Blocks")
## Side of a grid cell when the streets are painted to find blocks, game metres.
@export var cell_size := 1.5
@export var main_road_width := 6.0
@export var side_road_width := 3.5
## Blocks smaller than this (game m²) are left as pavement.
@export var sliver_area := 40.0
## Blocks smaller than this (game m²) become squares.
@export var square_area := 120.0
## How far a street that stops short is carried on to meet another, in side
## street spacings.
@export var join_reach := 2.0
@export_group("Land use rules")
## Offices weight on a block that fronts a main street.
@export var main_road_offices := 2.0
## Public weight at the city centre; it fades to 1 at the edge.
@export var centre_public := 2.5
## Blocks bigger than this (game m²) are likelier parks.
@export var big_block_area := 2200.0
@export var big_block_parks := 3.0
## Industry weight on blocks at the edge of the map.
@export var edge_industry := 1.8
@export_group("Look")
@export var panel_width := 340.0
@export var panel_margin := 12
## Seconds after the last menu change before the map is made again.
@export var rebuild_delay := 0.25
@export var pixels_per_metre := 1.6
@export var zoom_range := Vector2(0.4, 6.0)
@export var zoom_step := 1.15
@export var use_names := PackedStringArray()
@export var use_colours := PackedColorArray()
@export var road_colour := Color(0.42, 0.42, 0.45)
@export var main_road_colour := Color(0.55, 0.5, 0.42)
@export var pavement_colour := Color(0.62, 0.62, 0.6)
@export var background_colour := Color(0.12, 0.13, 0.15)


func mix_for(archetype: StringName) -> LandUseMix:
	for mix in mixes:
		if mix.archetype == archetype:
			return mix
	push_error("No land use mix for archetype '%s'" % archetype)
	return mixes[0]
