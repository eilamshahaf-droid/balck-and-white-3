class_name DistrictSettings
extends Resource
## Every tunable number for districts and for buildings changing sides
## (design doc: "השתלטות על רובע"). Open data/districts.tres in Godot and
## change values in the Inspector.

@export_group("Layout")
@export var columns := 3                    # districts across the avenues
@export var rows := 3                       # districts along the avenues
## One name per district, west to east, then south to north.
@export var names: PackedStringArray = [
	"Battery Flats", "Garment Row", "Spin Cycle Flats",
	"Little Lisbon", "Midtown South", "Murray Rise",
	"Chelsea Docks", "Park Edge", "Canal Street",
]

## How well off each district is, in the same order: scales rent and shop
## income and what it costs to buy people out. The start district by the river
## is poor; downtown (Garment Row) is rich.
@export var wealth := PackedFloat32Array([1.2, 2.0, 0.4, 1.0, 1.5, 0.9, 0.8, 1.0, 0.7])

@export_group("Who holds a building")
@export var tick := 0.5                     # seconds between counts
## Share of a building's residents who must believe for it to be yours.
@export_range(0.0, 1.0) var capture_share := 0.5
## A district's core building (the one nearest its middle) is harder: this share of its
## residents must believe. Once it is yours, City Hall and the police leave the district alone.
@export_range(0.0, 1.0) var core_capture_share := 0.75
@export_range(0.0, 1.0) var control_share := 0.6   # share of a district's buildings that makes it yours

@export_group("Start district")
## The cult starts in the district of its headquarters (the home of most of
## its believers). Abandoned buildings stand empty: whoever moves in holds them.
@export_range(0.0, 1.0) var abandoned_start := 0.3      # share of the start district's buildings
@export_range(0.0, 1.0) var abandoned_elsewhere := 0.04  # scattered through the rest of the city

@export_group("Look")
@export var roof_color := Color(1.0, 0.7, 0.0)              # the plate on a building of yours
@export var border_color := Color(1.0, 1.0, 1.0, 0.85)
@export var controlled_border_color := Color(1.0, 0.7, 0.0, 1.0)
@export var border_width := 2.0
