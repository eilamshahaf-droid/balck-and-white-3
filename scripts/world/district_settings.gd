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
	"Chelsea Docks", "Park Edge", "Riverside Heights",
]

@export_group("Buildings changing sides")
@export var tick := 0.5                     # seconds between updates
@export var believer_radius := 18.0         # believers on the street this close lean on a building
@export var believer_rate := 0.01           # faith per second from each believer nearby
## Buildings this close count as neighbours: across a street (14 m from
## facade to facade) yes, across an avenue (19 m) no, so the spread stops there.
@export var neighbor_gap := 16.0
@export var neighbor_rate := 0.012          # faith per second from each neighbour that is already yours
@export var decay := 0.03                   # faith lost per second, always
@export_range(0.0, 1.0) var lose_below := 0.5      # a building of yours goes back below this
@export_range(0.0, 1.0) var control_share := 0.6   # share of a district's buildings that makes it yours

@export_group("Look")
@export var roof_color := Color(1.0, 0.55, 0.1)
@export var border_color := Color(1.0, 1.0, 1.0, 0.6)
@export var controlled_border_color := Color(1.0, 0.6, 0.1, 1.0)
@export var border_width := 1.5
