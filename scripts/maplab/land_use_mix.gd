class_name LandUseMix
extends Resource
## How the blocks of one archetype's district are used, and the street style the
## district is laid out in.

@export var archetype := &""
## A StreetStyle id from data/mapgen.tres.
@export var street_style := &""
@export_group("Weights")
@export var homes := 0.6
@export var offices := 0.2
@export var industry := 0.05
@export var public_buildings := 0.05
@export var parks := 0.05


## One weight per LandUse.Use, squares excluded (they come from block size).
func weights() -> PackedFloat32Array:
	return PackedFloat32Array([homes, offices, industry, public_buildings, parks])
