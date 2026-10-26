class_name DecreeSettings
extends Resource
## Every tunable number for the divine decrees. Open data/decrees.tres in
## Godot and change values in the Inspector.
##
## Costs are in belief for now (money and influence come later). Like the
## miracles, a decree is cheaper among believers (see "Miracle power" in
## data/miracles.tres).

@export_group("Whose building")
@export_range(0.0, 1.0) var owner_share := 0.5   # share of a building's residents who must believe for it to be yours

@export_group("Add floors: the building grows overnight")
@export var floors_cost := 30.0
@export var floors_exposure := 0.04          # three new floors by morning: people notice
@export var floors_per_decree := 3
@export var max_floor_decrees := 3
@export var grow_time := 2.5                 # seconds the growth takes on screen

@export_group("Luxury: marble lobby, doorman, penthouse")
@export var luxury_cost := 40.0
@export var luxury_exposure := 0.02

@export_group("Facade: banners and lights in your colours")
@export var facade_cost := 10.0
@export var facade_exposure := 0.01
@export var facade_color := Color(0.55, 0.25, 0.75)

@export_group("Change use: the building does something else for you")
@export var use_cost := 25.0
@export var use_exposure := 0.02
@export var uses: Array[String] = ["Prayer House", "Course Center", "Free Personality Test"]

@export_group("Preserve: no demolition, no buying it from under you")
@export var preserve_cost := 20.0
@export var preserve_exposure := 0.005       # paperwork nobody reads
