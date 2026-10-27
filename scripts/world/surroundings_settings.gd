class_name SurroundingsSettings
extends Resource
## Tunables for what lies beyond the playable grid (surroundings.gd): the land,
## the river, the outer neighbourhoods, the clouds and the haze.

@export_group("Land")
@export var reach := 2200.0             # how far the land goes from the city centre
@export var cell := 25.0                # terrain mesh resolution, metres
@export var flat_margin := 120.0        # flat ground around the city before hills may start
@export var hill_height := 90.0
@export var hill_rise := 900.0          # distance over which hills grow to full height
@export var hill_frequency := 0.0016

@export_group("River")
@export var river_offset := 30.0        # from the city's east edge to the nearest bank
@export var river_width := 150.0
@export var river_wiggle := 45.0        # how far the river bends sideways
@export var river_wavelength := 1300.0
@export var water_level := -2.0
@export var river_depth := 7.0
@export var promenade_width := 10.0

@export_group("Roads")
@export var avenue_reach := 1400.0      # roads that carry on from the avenues
@export var street_reach := Vector2(180.0, 520.0)   # side streets end sooner, min..max
@export var road_width := 11.0
@export var bend := 0.5                 # how much roads wander once they leave the grid
@export var spread := 0.35              # how much they fan out away from the city
@export var ring_offsets := PackedFloat32Array([230.0, 620.0])   # ring roads around the city
@export var bridges := 2

@export_group("Neighbourhoods")
@export var lot_spacing := 19.0
## Columns of lots laid out per frame while the town grows in, so startup stays short.
@export var columns_per_frame := 6
@export var building_reach := 1300.0
@export var near_height := Vector2(8.0, 24.0)   # just outside the grid, min..max
@export var far_height := Vector2(4.0, 8.0)     # at building_reach
@export var near_density := 0.9
@export var far_density := 0.12
@export var road_pull := 70.0           # buildings far from any road are rarer than this
@export var pitched_below := 13.0       # buildings lower than this get a pitched roof
@export var skyline_across := 70.0      # height bonus for the cluster across the river
@export var skyline_radius := 260.0
@export var tree_count := 2600

@export_group("Sky")
@export var fog_begin := 450.0
@export var fog_end := 2100.0
@export var cloud_count := 16
@export var cloud_height := Vector2(150.0, 260.0)
@export var cloud_turn_speed := 0.4     # degrees per second the cloud layer drifts around

@export_group("Colours")
@export var grass_color := Color(0.52, 0.62, 0.42)
@export var water_color := Color(0.4, 0.6, 0.74)
@export var road_color := Color(0.3, 0.3, 0.33)
@export var promenade_color := Color(0.85, 0.78, 0.64)
@export var bridge_color := Color(0.62, 0.66, 0.74)
@export var roof_color := Color(0.74, 0.38, 0.3)
@export var rooftop_color := Color(0.56, 0.56, 0.6)
@export var trunk_color := Color(0.42, 0.3, 0.2)
@export var crown_colors := PackedColorArray([Color(0.3, 0.5, 0.27), Color(0.38, 0.56, 0.3)])
@export var cloud_color := Color(1.0, 1.0, 1.0)
@export var building_colors := PackedColorArray([
	Color(0.8, 0.6, 0.5), Color(0.86, 0.78, 0.64), Color(0.64, 0.7, 0.8),
	Color(0.74, 0.7, 0.66), Color(0.86, 0.68, 0.54), Color(0.6, 0.64, 0.72),
])
