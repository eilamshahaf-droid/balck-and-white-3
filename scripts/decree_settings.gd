class_name DecreeSettings
extends Resource
## Every tunable number for the divine decrees. Open data/decrees.tres in
## Godot and change values in the Inspector.
##
## Every decree costs belief and money. The belief part, like a miracle's, is
## cheaper among believers (see "Miracle power" in data/miracles.tres); the
## money is the builders' bill and costs the same everywhere.

@export_group("Add floors: the building grows overnight, with room for more followers")
@export var floors_cost := 30.0              # paperwork
@export var floors_money := 120.0
@export var floors_money_growth := 1.8       # each further floor decree costs this many times more
@export var floors_per_decree := 3
@export var max_floor_decrees := 8            # the rising price is the real limit
@export var grow_time := 2.5                 # seconds the growth takes on screen

@export_group("Open a shop")
@export var use_cost := 25.0                 # paperwork
@export var use_money := 80.0
## The name on the roof sign, and the key the shop props are listed under.
@export var shop_use := "Shop"
