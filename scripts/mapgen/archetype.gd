class_name Archetype
extends Resource
## One kind of neighbourhood that recurs in big cities (research: city archetypes).
## The generator gives every district one; later systems read its numbers for
## wealth, buildings and who lives there.

@export var id := &""
@export var title := ""
## How well off it is, 1 = average: scales rent, shop income and the price of buying people out.
@export var wealth := 1.0
## How likely this kind is at a corner, a side and the centre of the district grid.
@export var ring_weights := Vector3.ONE
## Skyline factor range, 0 (walk-ups) to 1 (the tallest towers), for the blocks in it.
@export var skyline := Vector2(0.0, 0.3)
## Share of its buildings that stand empty from the start.
@export_range(0.0, 1.0) var abandoned := 0.04
## Colour on the map preview.
@export var tint := Color.WHITE
