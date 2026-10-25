extends RefCounted
## The land under the planning city: hills, a river valley and a flatter core,
## as a height grid. Roads, blocks and buildings all sit on it, and roads are
## laid out around its slopes like real ones. Water level is 0.

const P: PlanningSettings = preload("res://data/planning.tres")
const CELL := 5.0

var half_size := Vector2(420, 320)
var size := Vector2i.ZERO          # vertices along x and z
var heights := PackedFloat32Array()


func _init(seed_value := 3) -> void:
	size = Vector2i(roundi(half_size.x * 2.0 / CELL) + 1, roundi(half_size.y * 2.0 / CELL) + 1)
	heights.resize(size.x * size.y)
	var hills := FastNoiseLite.new()
	hills.seed = seed_value
	hills.frequency = 0.0035
	hills.fractal_octaves = 3
	for z in size.y:
		for x in size.x:
			var p := Vector2(x, z) * CELL - half_size
			# Hills grow towards the edges; the old core by the river is flatter.
			var edge := smoothstep(90.0, 380.0, Vector2(p.x * 0.8, p.y).length())
			var h := (hills.get_noise_2d(p.x, p.y) * 0.5 + 0.55) * P.hill_height * lerpf(0.3, 1.0, edge)
			var d := absf(p.y - river_z(p.x))
			var valley := 1.0 - smoothstep(P.river_width * 0.5, P.river_width * 0.5 + 80.0, d)
			h = lerpf(h, 1.0, valley)
			if d < P.river_width * 0.5:
				h = lerpf(-3.0, 1.0, smoothstep(P.river_width * 0.3, P.river_width * 0.5, d))
			heights[z * size.x + x] = h


## The river's centre line: z for a given x.
func river_z(x: float) -> float:
	return -40.0 + 70.0 * sin(x * 0.006 + 0.8)


func height_at(x: float, z: float) -> float:
	var g := (Vector2(x, z) + half_size) / CELL
	var ix := clampi(floori(g.x), 0, size.x - 2)
	var iz := clampi(floori(g.y), 0, size.y - 2)
	var fx := clampf(g.x - ix, 0.0, 1.0)
	var fz := clampf(g.y - iz, 0.0, 1.0)
	var i := iz * size.x + ix
	return lerpf(lerpf(heights[i], heights[i + 1], fx), lerpf(heights[i + size.x], heights[i + size.x + 1], fx), fz)


func height2(p: Vector2) -> float:
	return height_at(p.x, p.y)


## Where a road surface is: on the ground, or on a bridge over water.
func road_height(p: Vector2) -> float:
	return maxf(height2(p), P.bridge_height)


func is_water(p: Vector2) -> bool:
	return height2(p) < 0.0


func inside(p: Vector2, margin := 0.0) -> bool:
	return absf(p.x) < half_size.x - margin and absf(p.y) < half_size.y - margin


## Steepest slope at a point (rise over run).
func slope_at(p: Vector2) -> float:
	var dx := height_at(p.x + 3.0, p.y) - height_at(p.x - 3.0, p.y)
	var dz := height_at(p.x, p.y + 3.0) - height_at(p.x, p.y - 3.0)
	return Vector2(dx, dz).length() / 6.0


## The first point where a ray from the camera meets the ground, or null.
func raycast(from: Vector3, dir: Vector3) -> Variant:
	var t := 0.0
	var step := 4.0
	var prev := from
	while t < 4000.0:
		t += step
		var p := from + dir * t
		if p.y <= height_at(p.x, p.z):
			# Narrow down between the last point above ground and this one.
			var a := prev
			var b := p
			for n in 12:
				var m := (a + b) / 2.0
				if m.y <= height_at(m.x, m.z):
					b = m
				else:
					a = m
			return b
		prev = p
	return null
