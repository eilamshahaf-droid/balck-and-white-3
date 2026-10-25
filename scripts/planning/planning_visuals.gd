extends RefCounted
## Placeholder looks for the planning scene, kept apart from the model so real
## art can replace them: one function per thing, each returns a Node3D.
##
## A building's look follows its zone and its character, the god its street
## belongs to (design doc, "neighbourhood colour"):
##   good - warm colours, roof gardens, awnings over shop fronts, human height,
##   evil - grey slabs, red neon at street level, a red light on the roof,
##   grey - glass, stepped towers, billboards on the roofs,
##   none - the ordinary city: brick, limestone, water tanks on the roofs.

const FLOOR_HEIGHT := 3.2

const PALETTES := {
	"residential": [Color(0.72, 0.45, 0.38), Color(0.62, 0.5, 0.42), Color(0.8, 0.7, 0.58), Color(0.7, 0.6, 0.55)],
	"commercial": [Color(0.78, 0.76, 0.7), Color(0.62, 0.66, 0.72), Color(0.7, 0.68, 0.64)],
	"industrial": [Color(0.58, 0.53, 0.45), Color(0.5, 0.5, 0.48)],
	"good": [Color(0.86, 0.5, 0.32), Color(0.9, 0.7, 0.35), Color(0.8, 0.45, 0.4), Color(0.92, 0.78, 0.5)],
	"evil": [Color(0.42, 0.42, 0.45), Color(0.36, 0.36, 0.4), Color(0.48, 0.46, 0.46)],
	"grey": [Color(0.5, 0.68, 0.82), Color(0.42, 0.58, 0.72), Color(0.6, 0.75, 0.85)],
}
const AWNINGS := [Color(0.85, 0.3, 0.3), Color(0.3, 0.6, 0.4), Color(0.3, 0.45, 0.75), Color(0.9, 0.7, 0.3)]

var _box := BoxMesh.new()
var _mats := {}


# --- Buildings ---

## The building on a lot. Its main volumes are listed in the "bodies" meta so
## overlays can tint them.
func building(lot: Dictionary, parent: Node) -> Node3D:
	var root := Node3D.new()
	root.position = lot.pos
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lot.seed * 1000003.0) + lot.floors
	var h: float = lot.floors * FLOOR_HEIGHT
	var w: float = lot.width - rng.randf_range(0.5, 1.6)
	var d: float = lot.depth * rng.randf_range(0.8, 0.95)
	var look: String = lot.character if lot.character != "" else lot.zone
	var palette: Array = PALETTES[look]
	var colour: Color = palette[rng.randi() % palette.size()]
	var bodies: Array = []
	var front := d / 2.0

	if lot.character == "grey" and lot.floors > 6:
		# Stepped tower, like the 1916 zoning setbacks.
		var h1 := h * rng.randf_range(0.45, 0.65)
		bodies.append(block(root, Vector3(w, h1, d), Vector3(0, h1 / 2.0, 0), colour))
		bodies.append(block(root, Vector3(w * 0.7, h - h1, d * 0.7), Vector3(0, h1 + (h - h1) / 2.0, 0), colour.lightened(0.1)))
	else:
		bodies.append(block(root, Vector3(w, h, d), Vector3(0, h / 2.0, 0), colour))

	match lot.character:
		"good":
			block(root, Vector3(w * 0.8, 0.5, d * 0.75), Vector3(0, h + 0.25, 0), Color(0.33, 0.52, 0.27))
			if rng.randf() < 0.6:
				block(root, Vector3(0.9, 0.9, 0.9), Vector3(w * 0.2, h + 0.95, d * 0.1), Color(0.35, 0.58, 0.3))
			if lot.zone != "industrial":
				var awning: Color = AWNINGS[rng.randi() % AWNINGS.size()]
				block(root, Vector3(w * 0.85, 0.3, 1.4), Vector3(0, 3.2, front + 0.7), awning)
				block(root, Vector3(w * 0.85, 0.3, 1.4), Vector3(0, 3.2, -front - 0.7), awning)
		"evil":
			block(root, Vector3(0.6, 0.6, 0.6), Vector3(w * 0.3, h + 0.3, 0), Color(1.0, 0.15, 0.1), true)
			if rng.randf() < 0.5:
				block(root, Vector3(w * 0.6, 0.5, 0.2), Vector3(0, 4.0, front + 0.1), Color(1.0, 0.2, 0.25), true)
			if lot.zone == "industrial":
				block(root, Vector3(1.6, 12, 1.6), Vector3(-w * 0.3, h + 6, 0), Color(0.25, 0.24, 0.24))
		"grey":
			if rng.randf() < 0.25:
				block(root, Vector3(0.3, 3, 0.3), Vector3(0, h + 1.5, 0), Color(0.3, 0.3, 0.32))
				block(root, Vector3(minf(w * 0.8, 9.0), 3.2, 0.25), Vector3(0, h + 4.2, 0), Color(1.0, 0.85, 0.3), true)
		_:
			if lot.zone == "residential" and rng.randf() < 0.4:
				block(root, Vector3(1.8, 2.2, 1.8), Vector3(w * 0.25, h + 2.1, 0), Color(0.45, 0.33, 0.22))
				block(root, Vector3(1.6, 1.0, 1.6), Vector3(w * 0.25, h + 0.5, 0), Color(0.3, 0.3, 0.3))
			elif lot.zone == "industrial" and rng.randf() < 0.5:
				block(root, Vector3(1.2, 7, 1.2), Vector3(-w * 0.3, h + 3.5, 0), Color(0.45, 0.4, 0.38))
			elif lot.zone == "commercial":
				block(root, Vector3(w * 0.9, 2.6, 0.2), Vector3(0, 1.5, front + 0.1), colour.darkened(0.35))
	root.set_meta("bodies", bodies)
	return root


# --- Landmarks ---

func landmark(lm: Dictionary, depth: float, height: float, parent: Node) -> Node3D:
	var root := Node3D.new()
	root.position = lm.pos
	parent.add_child(root)
	var w: float = lm.width * 0.92
	var d: float = depth * 0.9
	var bodies: Array = []
	match lm.kind:
		"temple":
			block(root, Vector3(w, 1.2, d), Vector3(0, 0.6, 0), Color(0.85, 0.82, 0.74))
			bodies.append(block(root, Vector3(w * 0.8, 12, d * 0.7), Vector3(0, 7.2, 0), Color(0.95, 0.92, 0.84)))
			prism(root, Vector3(w * 0.85, 7, d * 0.75), Vector3(0, 16.7, 0), Color(0.88, 0.7, 0.3))
			for x in [-0.42, 0.42]:
				tree(root, Vector3(w * x, 0, d * 0.4), 1.6)
		"square":
			bodies.append(block(root, Vector3(w, 0.4, d), Vector3(0, 0.2, 0), Color(0.82, 0.78, 0.68)))
			block(root, Vector3(4, 1.2, 4), Vector3(0, 0.6, 0), Color(0.7, 0.7, 0.68))
			block(root, Vector3(3.2, 0.2, 3.2), Vector3(0, 1.25, 0), Color(0.45, 0.68, 0.85))
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				tree(root, Vector3(c.x * w * 0.35, 0, c.y * d * 0.3), 1.8)
		"park":
			bodies.append(block(root, Vector3(w, 0.4, d), Vector3(0, 0.2, 0), Color(0.45, 0.68, 0.35)))
			block(root, Vector3(w * 0.95, 0.45, 1.5), Vector3(0, 0.22, 0), Color(0.8, 0.74, 0.6))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(lm.pos.x * 13.0 + lm.pos.z * 7.0)
			for n in 10:
				tree(root, Vector3(rng.randf_range(-w, w) * 0.45, 0, rng.randf_range(-d, d) * 0.4), rng.randf_range(1.6, 2.6))
		"station":
			bodies.append(block(root, Vector3(w, 9, d * 0.8), Vector3(0, 4.5, 0), Color(0.68, 0.5, 0.42)))
			block(root, Vector3(w * 1.05, 0.6, d), Vector3(0, 9.3, 0), Color(0.55, 0.7, 0.75))
			bodies.append(block(root, Vector3(3.5, 18, 3.5), Vector3(w * 0.3, 9, 0), Color(0.72, 0.55, 0.45)))
			block(root, Vector3(2.4, 2.4, 0.2), Vector3(w * 0.3, 15.5, 1.8), Color(0.98, 0.95, 0.85), true)
		"tower":
			bodies.append(block(root, Vector3(w * 0.85, height * 0.8, d * 0.8), Vector3(0, height * 0.4, 0), Color(0.45, 0.62, 0.78)))
			bodies.append(block(root, Vector3(w * 0.55, height * 0.2, d * 0.5), Vector3(0, height * 0.9, 0), Color(0.55, 0.7, 0.85)))
			block(root, Vector3(w * 0.5, 3, 0.3), Vector3(0, height * 0.75, d * 0.4 + 0.2), Color(1.0, 0.85, 0.3), true)
		"factory":
			bodies.append(block(root, Vector3(w, 9, d * 0.85), Vector3(0, 4.5, 0), Color(0.52, 0.48, 0.44)))
			for n in 3:
				prism(root, Vector3(w / 3.2, 3, d * 0.8), Vector3(w * (n - 1) / 3.0, 10.5, 0), Color(0.45, 0.42, 0.4))
			for x in [-0.3, 0.3]:
				block(root, Vector3(2, 22, 2), Vector3(w * x, 11, d * 0.25), Color(0.3, 0.28, 0.28))
		"monument":
			block(root, Vector3(w, 0.5, d), Vector3(0, 0.25, 0), Color(0.4, 0.4, 0.42))
			bodies.append(block(root, Vector3(9, 5, 9), Vector3(0, 3.0, 0), Color(0.25, 0.25, 0.28)))
			bodies.append(prism(root, Vector3(7, height - 5.5, 7), Vector3(0, 5.5 + (height - 5.5) / 2.0, 0), Color(0.2, 0.2, 0.23)))
			block(root, Vector3(1.2, 1.2, 1.2), Vector3(0, height + 0.6, 0), Color(1.0, 0.1, 0.05), true)
	root.set_meta("bodies", bodies)
	return root


# --- Street ---

func detail(kind: String, pos: Vector3, parent: Node) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	match kind:
		"tree":
			tree(root, Vector3.ZERO, 2.6)
		"bench":
			block(root, Vector3(2.4, 0.5, 0.8), Vector3(0, 0.45, 0), Color(0.55, 0.4, 0.25))
		"shrine":
			block(root, Vector3(1.4, 1.6, 1.0), Vector3(0, 0.8, 0), Color(0.92, 0.88, 0.78))
			block(root, Vector3(0.6, 0.6, 0.2), Vector3(0, 1.4, 0.55), Color(0.88, 0.7, 0.3))
		"camera":
			block(root, Vector3(0.25, 5, 0.25), Vector3(0, 2.5, 0), Color(0.3, 0.3, 0.32))
			block(root, Vector3(0.8, 0.5, 1.2), Vector3(0, 5, 0.3), Color(0.15, 0.15, 0.17))
			block(root, Vector3(0.2, 0.2, 0.2), Vector3(0.3, 5.3, 0.9), Color(1.0, 0.1, 0.1), true)
		"billboard":
			block(root, Vector3(0.4, 6, 0.4), Vector3(0, 3, 0), Color(0.3, 0.3, 0.32))
			block(root, Vector3(6, 3, 0.3), Vector3(0, 7, 0), Color(1.0, 0.85, 0.3), true)
	return root


## A street segment closed to cars and paved as a plaza.
func plaza(seg: Dictionary, parent: Node) -> Node3D:
	var root := Node3D.new()
	root.position = seg.pos
	parent.add_child(root)
	var size: Vector2 = seg.size
	block(root, Vector3(size.x, 0.35, size.y), Vector3(0, 0.18, 0), Color(0.78, 0.72, 0.6))
	block(root, Vector3(size.x * 0.6, 0.4, size.y * 0.35), Vector3(0, 0.2, 0), Color(0.48, 0.7, 0.38))
	for x in [-0.35, -0.1, 0.15, 0.4]:
		tree(root, Vector3(size.x * x, 0, 0), 1.6)
	for x in [-0.22, 0.28]:
		block(root, Vector3(2.4, 0.5, 0.8), Vector3(size.x * x, 0.45, size.y * 0.3), Color(0.55, 0.4, 0.25))
	return root


# --- Pieces ---

func block(parent: Node3D, size: Vector3, pos: Vector3, colour: Color, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _box
	m.scale = size
	m.position = pos
	m.material_override = material(colour, glow)
	parent.add_child(m)
	return m


func prism(parent: Node3D, size: Vector3, pos: Vector3, colour: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.position = pos
	m.material_override = material(colour)
	parent.add_child(m)
	return m


func tree(parent: Node3D, pos: Vector3, crown: float) -> void:
	block(parent, Vector3(0.45, 2.8, 0.45), pos + Vector3(0, 1.4, 0), Color(0.4, 0.28, 0.18))
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = crown
	sphere.height = crown * 1.8
	sphere.radial_segments = 12
	sphere.rings = 6
	m.mesh = sphere
	m.position = pos + Vector3(0, 2.8 + crown * 0.7, 0)
	m.material_override = material(Color(0.36, 0.6, 0.3))
	parent.add_child(m)


## Shared materials, one per colour. Glowing ones (neon, billboards, warning
## lights) are unshaded, so the art style leaves them bright.
func material(colour: Color, glow := false) -> StandardMaterial3D:
	var key := "%s%s" % [colour.to_html(false), "g" if glow else ""]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		if glow:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]
