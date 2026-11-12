class_name LandmarkSettings
extends Resource
## The landmarks of the status quo (GDD "Landmarks of the status quo"): five buildings
## per district the Vandalist marks to make its core easier. Open data/landmarks.tres
## in Godot and change values in the Inspector.

## Landmark names for the start district, as many as there are landmarks.
@export var names := PackedStringArray([
	"Landlord's office", "City notice board", "Police booth", "Inspector's office", "Post office",
])
## Landmarks stand at least this many borders from the core, spread around it.
@export var min_steps := 2
## How far out the ring they stand on is, as a share of the district's reach from the core.
@export_range(0.0, 1.0) var ring := 0.75
## A mark takes the Vandalist this long and costs this much money in supplies per
## attempt; marking again a landmark City Hall scrubbed costs redo_cost.
@export var mark_minutes := 4.0
@export var mark_cost := 60.0
@export var redo_cost := 100.0
## Chance he is arrested when a mark is done.
@export var arrest_chance := 0.1
## Each standing mark multiplies the core's difficulty by this.
@export var mark_multiplier := 0.4
## A mark that has stood clean_after_minutes may be scrubbed by City Hall, this
## chance per minute.
@export var clean_after_minutes := 5.0
@export var clean_chance_per_minute := 0.15
@export var sign_color := Color(0.75, 0.75, 0.78)
@export var marked_color := Color(1.0, 0.35, 0.6)
@export var sign_lift := 3.0   # metres above the roof


# Accessors rather than reading the array from a const preload (editor parse rule).
func count() -> int:
	return names.size()


func name_of(i: int) -> String:
	return names[i]
