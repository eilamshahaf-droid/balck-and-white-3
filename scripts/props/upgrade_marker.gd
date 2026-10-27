class_name UpgradeMarker
extends Resource
## One prop that shows a housing upgrade a building has bought (an elevator
## shaft on its side, cameras by its door). Stable names: see
## `Population.Upgrade`.

## Where on the building the prop goes.
enum Place { ROOF, WALL, STREET }

@export var upgrade := Population.Upgrade.ELEVATOR
@export var kind: PropKind
@export var place := Place.WALL
## Across the front, from the left edge (0) to the right edge (1).
@export_range(0.0, 1.0) var across := 0.5
## Metres above the ground, for a prop on the wall.
@export var height := 0.0
