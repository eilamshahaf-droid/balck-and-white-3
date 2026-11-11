class_name EndJoiner
extends RefCounted
## Carries a street the tracer stopped short of another street on until it meets
## it, as real streets do; without it a block leaks into its neighbour through the
## gap. Some ends stay open as dead ends.

const STEP := 1.0      # metres marched per test
const SNAP := 1.6      # how close a point of another street counts as a hit

var _cell: float
var _points := {}      # Vector2i -> PackedInt32Array of line * 65536 + point


## Extends the ends of `lines` in place, toward any street in `lines`.
static func join(lines: Array[PackedVector2Array], reach: float, dead_end_share: float,
		rng: RandomNumberGenerator) -> void:
	var joiner := EndJoiner.new()
	joiner._index(lines)
	for n in lines.size():
		for at_start: bool in [true, false]:
			if rng.randf() >= dead_end_share:
				joiner._extend(lines, n, at_start, reach)


func _index(lines: Array[PackedVector2Array]) -> void:
	_cell = SNAP * 2.0
	for n in lines.size():
		for i in lines[n].size():
			var key := _key(lines[n][i])
			# Packed arrays are values: take, append, put back.
			var codes: PackedInt32Array = _points.get(key, PackedInt32Array())
			codes.append(n * 65536 + i)
			_points[key] = codes


func _extend(lines: Array[PackedVector2Array], n: int, at_start: bool, reach: float) -> void:
	var line := lines[n]
	if line.size() < 2:
		return
	var end := line[0] if at_start else line[line.size() - 1]
	var inner := line[1] if at_start else line[line.size() - 2]
	var heading := (end - inner).normalized()
	var marched := STEP
	while marched <= reach:
		var hit := _hit(end + heading * marched, n, lines)
		if hit != Vector2.INF:
			if at_start:
				line.insert(0, hit)
			else:
				line.append(hit)
			lines[n] = line
			return
		marched += STEP


## The nearest point of another street within SNAP of `p`, or INF.
func _hit(p: Vector2, own: int, lines: Array[PackedVector2Array]) -> Vector2:
	var key := _key(p)
	var best := Vector2.INF
	var best_d := SNAP * SNAP
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near: PackedInt32Array = _points.get(key + Vector2i(dx, dy), PackedInt32Array())
			for code in near:
				var line := code >> 16
				if line == own:
					continue
				var q := lines[line][code & 0xFFFF]
				var d := p.distance_squared_to(q)
				if d < best_d:
					best_d = d
					best = q
	return best


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _cell), floori(p.y / _cell))
