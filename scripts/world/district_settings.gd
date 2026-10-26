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
	"Battery Flats", "Garment Row", "Canal Street",
	"Little Lisbon", "Midtown South", "Murray Rise",
	"Chelsea Docks", "Park Edge", "Spin Cycle Flats",
]

@export_group("Claim meter")
## Every building has a claim meter, 0..claim_full; at full it is yours
## (design doc: "איך משתלטים על מקום"). Only the power route fills it so far.
@export var tick := 0.5                     # seconds between updates
@export var claim_full := 100.0
@export var resident_rate := 2.0            # claim per second for each believer who lives there
@export var believer_radius := 18.0         # believers on the street this close lean on a building
@export var street_rate := 1.0              # claim per second for each believer on the street nearby
## Your influence zone: buildings this close to one of yours. Across a street
## (14 m from facade to facade) yes, across an avenue (19 m) no, so the spread stops there.
@export var neighbor_gap := 16.0
@export var zone_rate := 1.2                # claim per second for each neighbour that is already yours
@export var decay := 1.0                    # claim lost per second while nothing holds it
@export var lose_below := 50.0              # a building of yours goes back below this
@export_range(0.0, 1.0) var control_share := 0.6   # share of a district's buildings that makes it yours

@export_group("Start district")
## The cult starts in the district of its headquarters (the home of most of
## its believers). Abandoned places are the only ones you can claim outside
## your influence zone.
@export_range(0.0, 1.0) var abandoned_start := 0.3      # share of the start district's buildings
@export_range(0.0, 1.0) var abandoned_elsewhere := 0.04  # scattered through the rest of the city

@export_group("Look")
@export var roof_color := Color(1.0, 0.7, 0.0)
@export var abandoned_color := Color(0.42, 0.4, 0.38)   # roof plate on an abandoned place nobody holds
@export var border_color := Color(1.0, 1.0, 1.0, 0.85)
@export var controlled_border_color := Color(1.0, 0.7, 0.0, 1.0)
@export var border_width := 2.0
