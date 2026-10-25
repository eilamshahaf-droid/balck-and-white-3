extends RefCounted
## Recognises the shapes drawn with the right mouse button. Forgiving on
## purpose: the original games were criticised for gestures that failed.

const MIN_SIZE := 60.0        # pixels across
const MIN_POINTS := 8


## A loop: the path comes back near where it started after turning most of
## the way round.
static func is_circle(points: PackedVector2Array) -> bool:
	if points.size() < MIN_POINTS:
		return false
	var box := Rect2(points[0], Vector2.ZERO)
	var length := 0.0
	for i in points.size():
		box = box.expand(points[i])
		if i > 0:
			length += points[i].distance_to(points[i - 1])
	var size := maxf(box.size.x, box.size.y)
	if size < MIN_SIZE or minf(box.size.x, box.size.y) < size * 0.35:
		return false
	if points[0].distance_to(points[-1]) > size * 0.5:
		return false
	# Total turning around the centre: close to a full turn.
	var center := box.get_center()
	var turned := 0.0
	for i in range(1, points.size()):
		var a := (points[i - 1] - center).angle()
		var b := (points[i] - center).angle()
		turned += wrapf(b - a, -PI, PI)
	return absf(turned) > TAU * 0.75 and length > size * 2.2


## Average distance from the centre, in pixels.
static func radius(points: PackedVector2Array) -> float:
	var c := centroid(points)
	var sum := 0.0
	for p in points:
		sum += p.distance_to(c)
	return sum / maxf(points.size(), 1)


static func centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1)
