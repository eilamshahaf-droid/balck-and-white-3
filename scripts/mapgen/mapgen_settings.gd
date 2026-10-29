class_name MapGenSettings
extends Resource
## The kinds of neighbourhood the map generator can place. Open data/mapgen.tres
## in Godot and change values in the Inspector.

@export var archetypes: Array[Archetype] = []
## The archetype of the district the cult starts in (always at a corner).
@export var start_archetype := &"forgotten"
