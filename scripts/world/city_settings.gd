class_name CitySettings
extends Resource
## The city built from a stage's map (CityPlan): which map, how tall a floor stands,
## street colours and how much life is scattered on it.

## The stage's map, written by tools/maplab/export_map.js.
@export_file("*.json") var map_path := "res://data/maps/slums/map.json"
## Game metres per Map Lab storey metre: the map is squeezed sideways (its scale), not upward.
@export var vertical_scale := 1.0
## Map Lab building kinds built as glass curtain walls; the rest are stone and brick.
@export var glass_kinds: PackedStringArray = ["officeTower"]
## Gap left between buildings that share a wall, so their facades don't flicker.
@export var party_wall_gap := 0.3
@export_group("Streets")
@export var asphalt_color := Color(0.18, 0.18, 0.2)
@export var sidewalk_color := Color(0.55, 0.55, 0.55)
@export var line_color := Color(0.85, 0.82, 0.7)
## Height of the sidewalks and the asphalt above the ground, drawn only (no step to trip on).
@export var sidewalk_lift := 0.03
@export var asphalt_lift := 0.05
## Centre line dashes on two-way streets this wide or wider: length, gap, width.
@export var dash := Vector3(2.0, 2.5, 0.15)
@export var dashed_from := 6.0
@export_group("Ground")
## Land colour per Map Lab use: homes, offices, industry, public, parks, squares, countryside.
@export var use_colors: PackedColorArray = [
	Color(0.6, 0.58, 0.54), Color(0.62, 0.62, 0.62), Color(0.5, 0.48, 0.45),
	Color(0.64, 0.6, 0.55), Color(0.25, 0.5, 0.22), Color(0.78, 0.72, 0.62), Color(0.45, 0.55, 0.3),
]
@export var water_color := Color(0.2, 0.35, 0.5)
@export_group("Life")
## Share of the map's trees that are planted (each one sways and costs a little).
@export_range(0.0, 1.0) var tree_share := 0.3
@export var taxi_count := 24
@export var litter_count := 140
@export var pigeon_flocks := 8
## Taxis keep this far from the centre line, toward their side.
@export var taxi_lane := 1.8


## The land colour of ground value `v` (CityPlan.ground).
func ground_color(v: int) -> Color:
	if v == 250:
		return water_color
	if v >= 1 and v <= use_colors.size():
		return use_colors[v - 1]
	return asphalt_color
