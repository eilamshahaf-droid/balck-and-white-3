class_name StreetStyle
extends Resource
## A way real cities lay out their streets, found by grouping 100 cities by how
## grid-like, winding, long-blocked and dead-end-ridden their streets are
## (tools/city_stats.csv, tools/cluster_city_styles.py). Distances are real
## metres; MapSpec.metres_scale shrinks them to the game's toy-town size.

@export var id := &""
@export var title := ""
@export var examples := ""
## How many of the 100 cities fall in this group.
@export var city_count := 0
@export var grid_fields := 1
@export var radial_fields := 0
@export var field_reach := 300.0
@export var field_wobble := 0.1
## Median distance between side streets, and between main streets.
@export var minor_spacing := 80.0
@export var major_spacing := 200.0
## Share of side streets that stop short instead of reaching the next street.
@export_range(0.0, 1.0) var dead_end_share := 0.07
