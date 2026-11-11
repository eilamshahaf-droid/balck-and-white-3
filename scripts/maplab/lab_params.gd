class_name LabParams
extends Resource
## The numbers the map lab's menu changes. Distances are real metres; MapSpec's
## metres_scale shrinks them to the game's toy-town size.

@export var map_seed := 1
## Index into MapGenSettings.street_styles, or -1 to give every district the style
## of its archetype.
@export var style := -1
@export var major_spacing := 170.0
@export var minor_spacing := 70.0
@export_range(0.0, 1.0) var dead_end_share := 0.1
## Multiplies every district's street wobble.
@export var curviness := 1.0
@export_group("Land use")
## Multiply the weight of each use in every district.
@export var homes := 1.0
@export var offices := 1.0
@export var industry := 1.0
@export var public_buildings := 1.0
@export var parks := 1.0


## The use multipliers in LandUse.Use order, squares excluded.
func use_scales() -> PackedFloat32Array:
	return PackedFloat32Array([homes, offices, industry, public_buildings, parks])
