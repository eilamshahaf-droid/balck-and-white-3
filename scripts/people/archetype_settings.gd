class_name ArchetypeSettings
extends Resource
## The eight resident archetypes and what their levels mean. Open
## data/archetypes.tres in Godot and change values in the Inspector. Load it with
## load(), not preload(): its array holds a custom class.

## The number each ResidentArchetype.Level stands for: none, low, medium, high.
@export var level_values := PackedFloat32Array([0.0, 0.2, 0.5, 0.8])
@export var archetypes: Array[ResidentArchetype] = []


func value(level: ResidentArchetype.Level) -> float:
	return level_values[level]


## The archetypes living in district kind `kind`, picked by share with `rng`; null if none live there.
func pick(kind: String, rng: RandomNumberGenerator) -> ResidentArchetype:
	var total := 0.0
	for a in archetypes:
		total += a.share_in(kind)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for a in archetypes:
		roll -= a.share_in(kind)
		if roll <= 0.0 and a.share_in(kind) > 0.0:
			return a
	return archetypes[-1]
