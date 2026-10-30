class_name CityBlocks
extends RefCounted
## The blocks between the streets, found by painting the streets onto a grid of
## cells and filling every patch of cells they enclose. Cheap and robust for a
## preview; the road graph (step 5 of the plan) will replace it with exact polygons.
## Cell (x, y) covers the square from origin + (x, y) * cell, y running north.

const EMPTY := -3
const MAIN_ROAD := -2
const SIDE_ROAD := -1

var cell: float
var size: Vector2i
var origin: Vector2
var labels := PackedInt32Array()          # block index per cell, or a road kind
var areas := PackedFloat32Array()         # game m² per block
var centres := PackedVector2Array()
var on_main_road := PackedByteArray()     # 1 if the block fronts a main street
var at_edge := PackedByteArray()          # 1 if the block runs into the map edge
var main_road_length := 0.0
var side_road_length := 0.0


static func find(major: Array[PackedVector2Array], minor: Array[PackedVector2Array],
		field_size: Vector2, settings: MapLabSettings) -> CityBlocks:
	var out := CityBlocks.new()
	out._find(major, minor, field_size, settings)
	return out


func count() -> int:
	return areas.size()


func label_at(x: int, y: int) -> int:
	return labels[y * size.x + x]


func _find(major: Array[PackedVector2Array], minor: Array[PackedVector2Array],
		field_size: Vector2, settings: MapLabSettings) -> void:
	cell = settings.cell_size
	size = Vector2i(ceili(field_size.x / cell), ceili(field_size.y / cell))
	origin = -field_size / 2.0
	labels.resize(size.x * size.y)
	labels.fill(EMPTY)
	# Side streets first, so a main street painted over them keeps its kind.
	side_road_length = _paint(minor, settings.side_road_width, SIDE_ROAD)
	main_road_length = _paint(major, settings.main_road_width, MAIN_ROAD)
	for n in labels.size():
		if labels[n] == EMPTY:
			_fill(n)


## Paints every line `width` wide and returns their total length.
func _paint(lines: Array[PackedVector2Array], width: float, kind: int) -> float:
	var radius := width / 2.0 / cell
	var reach := ceili(radius)
	var length := 0.0
	for line in lines:
		for n in line.size() - 1:
			var a := (line[n] - origin) / cell
			var b := (line[n + 1] - origin) / cell
			var steps := maxi(1, ceili(a.distance_to(b)))
			length += line[n].distance_to(line[n + 1])
			for s in steps + 1:
				_stamp(a.lerp(b, float(s) / steps), radius, reach, kind)
	return length


func _stamp(at: Vector2, radius: float, reach: int, kind: int) -> void:
	var cx := floori(at.x)
	var cy := floori(at.y)
	for y in range(maxi(cy - reach, 0), mini(cy + reach + 1, size.y)):
		for x in range(maxi(cx - reach, 0), mini(cx + reach + 1, size.x)):
			if at.distance_squared_to(Vector2(x + 0.5, y + 0.5)) <= radius * radius:
				labels[y * size.x + x] = kind


## Floods the patch of empty cells around `start` and records it as a block.
func _fill(start: int) -> void:
	var block := areas.size()
	var stack := PackedInt32Array([start])
	labels[start] = block
	var cells := 0
	var sum := Vector2.ZERO
	var main := 0
	var edge := 0
	while not stack.is_empty():
		var n := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := n % size.x
		var y := floori(float(n) / size.x)
		cells += 1
		sum += Vector2(x + 0.5, y + 0.5)
		if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
			edge = 1
		for next: int in [n - 1 if x > 0 else -1, n + 1 if x < size.x - 1 else -1,
				n - size.x if y > 0 else -1, n + size.x if y < size.y - 1 else -1]:
			if next < 0:
				continue
			var label := labels[next]
			if label == EMPTY:
				labels[next] = block
				stack.append(next)
			elif label == MAIN_ROAD:
				main = 1
	areas.append(cells * cell * cell)
	centres.append(origin + sum / cells * cell)
	on_main_road.append(main)
	at_edge.append(edge)
