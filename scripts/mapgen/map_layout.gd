class_name MapLayout
extends RefCounted
## A generated map: pure data, no nodes, so the same map can be drawn as a
## preview, built into the 3D city, or checked by a test. Blocks are indexed
## (i, j) = (west to east, south to north) between the road centre lines.

enum Block { BUILT, PARK, PLAZA }

var spec: MapSpec
var avenue_x := PackedFloat32Array()      # road centre lines, west to east
var street_z := PackedFloat32Array()      # south to north
var blocks := PackedByteArray()           # Block per block, j * blocks_x + i
var skyline := PackedFloat32Array()       # 0..1 per block: how tall it builds
var block_district := PackedInt32Array()  # district index per block
var district_archetype: Array[Archetype] = []
var start_district := -1


func blocks_x() -> int:
	return avenue_x.size() - 1


func blocks_z() -> int:
	return street_z.size() - 1


func block_at(i: int, j: int) -> int:
	return blocks[j * blocks_x() + i]


func skyline_at(i: int, j: int) -> float:
	return skyline[j * blocks_x() + i]


func district_of(i: int, j: int) -> int:
	return block_district[j * blocks_x() + i]


func district_count() -> int:
	return district_archetype.size()


## Wealth per district, for Districts.
func wealth() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for a in district_archetype:
		out.append(a.wealth)
	return out


## The middle of block (i, j) on the ground, as (x, z).
func block_center(i: int, j: int) -> Vector2:
	return Vector2((avenue_x[i] + avenue_x[i + 1]) / 2.0, (street_z[j] + street_z[j + 1]) / 2.0)
