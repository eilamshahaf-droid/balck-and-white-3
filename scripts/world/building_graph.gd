class_name BuildingGraph
extends RefCounted
## Which buildings (the stage map's units) border each other, set once from the map;
## Districts asks it who a building's neighbours are.

var _borders: Array[PackedInt32Array] = []


## Neighbours given outright (the stage map's units), by index.
func set_borders(lists: Array[PackedInt32Array]) -> void:
	_borders = lists.duplicate()


## The buildings `index` borders.
func of(index: int) -> PackedInt32Array:
	return _borders[index]


## Every building within `steps` borders of `index` (not `index` itself), skipping those
## `skip` marks with a non-zero byte.
func around(index: int, steps: int, skip: PackedByteArray) -> Array[int]:
	var seen := {index: true}
	var out: Array[int] = []
	var ring: Array[int] = [index]
	for step in steps:
		var next: Array[int] = []
		for i in ring:
			for j in _borders[i]:
				if not seen.has(j) and skip[j] == 0:
					seen[j] = true
					next.append(j)
		out.append_array(next)
		ring = next
	return out
