class_name CityPropsSettings
extends Resource
## Every tunable number for the props that dress the city: air conditioners on
## facades, water tanks and cooling units on roofs, and the things on the
## sidewalks that the hand can pick up. Open data/city_props.tres in Godot.
##
## Load this with load() at run time, not preload(): its typed arrays hold
## PropKind resources.

@export_group("Facades")
## Air conditioners that hang under windows.
@export var facade_kinds: Array[PropKind] = []
## Chance that a given window above the ground floor has one.
@export_range(0.0, 1.0) var facade_chance := 0.2
## Metres from the bottom of a floor to the sill the unit rests on.
@export var sill_height := 0.9
## Towers taller than this are glass curtain walls with no windows to open.
@export var facade_max_height := 60.0

@export_group("Roofs")
@export var roof_kinds: Array[PropKind] = []
@export_range(0.0, 1.0) var roof_chance := 0.6
## Roof props keep this far from the roof's edge.
@export var roof_margin := 2.0

@export_group("Sidewalks")
@export var street_kinds: Array[PropKind] = []
## Metres between props along a building's street front (min, max).
@export var street_spacing := Vector2(12.0, 26.0)
## How far out from the wall the props stand.
@export var wall_gap := 0.7

@export_group("Squashy props (trash bags)")
## How much each thing lying on top presses a bag flat (1 = fully flat).
@export var squash_per_load := 0.45
## How much a landing at 1 m/s presses it.
@export var squash_per_speed := 0.12
## How fast a hard landing's dent springs back, per second.
@export var squash_recover := 1.5
## How fast the shape follows (per second); higher looks stiffer.
@export var squash_follow := 6.0

@export_group("Taxi")
@export var taxi: PropKind

@export_group("Drawing")
## Facade and roof props are drawn in chunks of this many metres, so the ones
## off screen are skipped as a whole.
@export var chunk_size := 120.0
## Beyond this camera distance facade, roof and street props are not drawn.
@export var visible_distance := 260.0
