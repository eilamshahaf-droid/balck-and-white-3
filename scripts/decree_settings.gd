class_name DecreeSettings
extends Resource
## Every tunable number for the divine decrees. Open data/decrees.tres in
## Godot and change values in the Inspector.
##
## Every decree costs belief and money. The belief part, like a miracle's, is
## cheaper among believers (see "Miracle power" in data/miracles.tres); the
## money is the builders' bill and costs the same everywhere.

@export_group("Add floors: the building grows overnight")
@export var floors_cost := 30.0
@export var floors_money := 120.0
@export var floors_money_growth := 1.8       # each further floor decree costs this many times more
@export var floors_exposure := 0.04          # three new floors by morning: people notice
@export var floors_per_decree := 3
@export var max_floor_decrees := 8            # the rising price is the real limit
@export var grow_time := 2.5                 # seconds the growth takes on screen

@export_group("Luxury: marble lobby, doorman, penthouse")
@export var luxury_cost := 40.0
@export var luxury_money := 150.0
@export var luxury_exposure := 0.02

@export_group("Facade: banners and lights in your colours")
@export var facade_cost := 10.0
@export var facade_money := 60.0
@export var facade_exposure := 0.01
@export var facade_color := Color(0.55, 0.25, 0.75)

@export_group("Change use: the building does something else for you")
@export var use_cost := 25.0
@export var use_money := 80.0
@export var use_exposure := 0.02
## Combat Training: the force route trains believers there. Shop: the only use that
## earns money (TreasurySettings.shop_use); the others cost upkeep.
## The use whose believers pray belief into the pool; no other building does.
@export var prayer_use := "Prayer House"
@export var uses: Array[String] = ["Prayer House", "Course Center", "Free Personality Test",
		"Combat Training", "Shop"]

@export_group("Preserve: no demolition, no buying it from under you")
@export var preserve_cost := 20.0
@export var preserve_money := 40.0
@export var preserve_exposure := 0.005       # paperwork nobody reads
