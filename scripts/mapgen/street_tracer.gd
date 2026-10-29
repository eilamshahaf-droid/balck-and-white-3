class_name StreetTracer
extends RefCounted
## Turns a TensorField into streets: seeds are tried over the map, and a street
## follows the field both ways until it leaves the map, runs into a street of its
## own kind or loops. Main streets are laid first, then side streets in between,
## so side streets cross the main ones the way they do in a real city.

var major: Array[PackedVector2Array] = []
var minor: Array[PackedVector2Array] = []

var _spec: MapSpec
var _field: TensorField
var _rng: RandomNumberGenerator
var _taken := {}      # Vector2i cell -> true, for the kind being traced
var _cell: float
var _half: Vector2


func _init(spec: MapSpec, field: TensorField, rng: RandomNumberGenerator) -> void:
	_spec = spec
	_field = field
	_rng = rng
	_half = spec.field_size / 2.0
	_trace_kind(true)
	_trace_kind(false)


func _trace_kind(is_major: bool) -> void:
	var spacing := _spec.major_spacing if is_major else _spec.minor_spacing
	_cell = spacing / 2.0
	_taken.clear()
	var seeds: Array[Vector2] = []
	var x := -_half.x
	while x <= _half.x:
		var z := -_half.y
		while z <= _half.y:
			seeds.append(Vector2(x, z) + Vector2(_rng.randf(), _rng.randf()) * spacing * 0.5)
			z += spacing
		x += spacing
	_shuffle(seeds)
	var out := major if is_major else minor
	for s in seeds:
		if _inside(s) and not _taken.has(_key(s)):
			var line := _trace(s, is_major)
			if line.size() >= 4:
				_claim(line)
				out.append(line)


func _trace(start: Vector2, is_major: bool) -> PackedVector2Array:
	var forward := _walk(start, 1.0, is_major)
	var back := _walk(start, -1.0, is_major)
	back.reverse()
	var line := back
	line.append(start)
	line.append_array(forward)
	return line


func _walk(start: Vector2, way: float, is_major: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var p := start
	var heading := _direction(p, is_major) * way
	var length := 0.0
	while length < _spec.max_line_length:
		var mid := p + heading * _spec.trace_step / 2.0
		var next_heading := _direction(mid, is_major)
		if next_heading.dot(heading) < 0.0:
			next_heading = -next_heading
		var next := p + next_heading * _spec.trace_step
		if not _inside(next) or _crowded(next, points) or _closes_loop(next, start, length):
			break
		points.append(next)
		p = next
		heading = next_heading
		length += _spec.trace_step
	return points


## A street that circles back to where it began is a ring around a fan centre;
## cutting it there keeps the centre from filling with tiny circles.
func _closes_loop(p: Vector2, start: Vector2, length: float) -> bool:
	return length > _spec.trace_step * 8.0 and p.distance_to(start) < _spec.trace_step * 2.0


func _direction(p: Vector2, is_major: bool) -> Vector2:
	var d := _field.major_at(p)
	return d if is_major else d.orthogonal()


## A point is crowded when it enters a cell another street of this kind holds,
## unless it is one of the last few steps of the street being walked.
func _crowded(p: Vector2, own: PackedVector2Array) -> bool:
	if not _taken.has(_key(p)):
		return false
	var recent := mini(own.size(), 6)
	for n in recent:
		if _key(own[own.size() - 1 - n]) == _key(p):
			return false
	return true


func _claim(line: PackedVector2Array) -> void:
	for p in line:
		_taken[_key(p)] = true


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _cell), floori(p.y / _cell))


func _inside(p: Vector2) -> bool:
	return absf(p.x) <= _half.x and absf(p.y) <= _half.y


func _shuffle(list: Array[Vector2]) -> void:
	for n in range(list.size() - 1, 0, -1):
		var m := _rng.randi_range(0, n)
		var tmp := list[n]
		list[n] = list[m]
		list[m] = tmp
