class_name BuildingGraph
extends RefCounted
## Which buildings border each other: their footprints, grown by half the gap on every
## side, overlap. Built once; Districts asks it who a building's neighbours are.

var _borders: Array[PackedInt32Array] = []


## `feet` are the buildings' footprints on the ground (x, z), by index.
func build(feet: Array[Rect2], gap: float) -> void:
	var grown: Array[Rect2] = []
	for f in feet:
		grown.append(f.grow(gap / 2.0))
	_borders.resize(feet.size())
	for i in feet.size():
		_borders[i] = PackedInt32Array()
	for i in feet.size():
		for j in range(i + 1, feet.size()):
			if grown[i].intersects(grown[j]):
				_borders[i].append(j)
				_borders[j].append(i)


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
