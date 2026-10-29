class_name MapSpec
extends Resource
## What kind of map to make. A level is a MapSpec saved in data/maps/ with fixed
## numbers; the sandbox makes one with a fresh `seed` each time.

@export var map_seed := 1
@export_group("Streets")
@export var avenues := 7                         # north-south roads
@export var streets := 14                        # east-west roads
@export var avenue_gaps := Vector2(64.0, 96.0)   # min, max distance between avenues
@export var street_gaps := Vector2(22.0, 36.0)
@export_group("Blocks")
@export var plazas := 4                          # blocks left half open as squares
@export var park_length := 4                     # blocks of park along the north end, 0 for none
@export_group("Districts")
@export var columns := 3
@export var rows := 3
## An archetype id per district, west to east then south to north. Leave a
## slot empty (or the array short) and the generator picks for it.
@export var archetypes: PackedStringArray = []
## Where the cult starts, a district index; -1 picks a corner.
@export var start_district := -1
