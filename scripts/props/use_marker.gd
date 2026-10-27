class_name UseMarker
extends Resource
## One prop that shows what a building is used for: a statue on the roof of a
## Prayer House, an easel by the door of a Course Center.

## The Change Use name it belongs to (Decrees.uses).
@export var use_name := ""
@export var kind: PropKind
## On the roof (true) or in front of the building, by the street (false).
@export var on_roof := false
