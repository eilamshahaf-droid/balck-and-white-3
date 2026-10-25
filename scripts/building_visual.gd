extends RefCounted
## Builds a building's look from Kenney's CC0 "Modular Buildings" kit
## (assets/models/kenney_modular): one facade module per floor and per bay on
## every outer wall, a shopfront ground floor and a flat roof, all merged into
## a single mesh so the camera fade and the fire can treat it like the old box.
## The models are used exactly as they come from the kit for now.

const KIT := "res://assets/models/kenney_modular/"
const MODULE_WIDTH := 1.0     # every wall module is a 1 x 0.62 x 1 cube in the kit
const MODULE_HEIGHT := 0.62
const BAY := 5.0              # target metres per module across a facade (floor ≈ 3.1 m)

const GROUND := ["building-door", "building-window-large-middle", "building-window-door-window", "building-window-awnings", "building-door-window"]
const UPPER := ["building-window", "building-windows", "building-window-sill", "building-windows-sills", "building-window-wide", "building-windows-round", "building-window-wide-sill"]
const GLASS := ["building-window-large-middle"]
const TOP := ["building-windows-high-top-square", "building-windows-high-top-round"]
const ROOF := "roof-flat-center"
const SKINS := ["Textures/colormap.png", "Textures/variation-a.png", "Textures/variation-b.png"]

static var _meshes := {}
static var _skins := []


## A mesh that fills `size` (centred on the origin, like a BoxMesh of that size).
## Tall glass towers get large windows on every floor. The look has its own
## random seed so it never changes the city's layout.
static func build(size: Vector3, seed_value: int, glass: bool) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cols := maxi(1, roundi(size.x / BAY))
	var rows := maxi(1, roundi(size.z / BAY))
	var floors := maxi(1, roundi(size.y / (BAY * MODULE_HEIGHT)))
	var cell := Vector3(size.x / cols, size.y / floors / MODULE_HEIGHT, size.z / rows)
	var ground: String = _pick(GROUND, rng)
	var upper: String = _pick(GLASS if glass else UPPER, rng)
	var top: String = _pick(TOP, rng) if floors > 3 and not glass else upper

	var st := SurfaceTool.new()
	var origin := Vector3(-size.x / 2.0, -size.y / 2.0, -size.z / 2.0)
	for f in floors:
		var module := ground if f == 0 else (top if f == floors - 1 else upper)
		var y := f * MODULE_HEIGHT * cell.y
		# Long walls (facing the streets, +z and -z), then the short ends (+x, -x).
		for c in cols:
			var x := (c + 0.5) * size.x / cols
			_add(st, module, origin + Vector3(x, y, size.z - 0.5 * cell.z), 0.0, cell)
			if rows > 1:
				_add(st, module, origin + Vector3(x, y, 0.5 * cell.z), PI, cell)
		# The corner cubes already belong to the long walls.
		for r in range(1, rows - 1):
			var z := (r + 0.5) * size.z / rows
			_add(st, upper if f > 0 else module, origin + Vector3(size.x - 0.5 * cell.x, y, z), PI / 2.0, Vector3(cell.z, cell.y, cell.x))
			_add(st, upper if f > 0 else module, origin + Vector3(0.5 * cell.x, y, z), -PI / 2.0, Vector3(cell.z, cell.y, cell.x))
	for c in cols:
		for r in rows:
			var p := Vector3((c + 0.5) * size.x / cols, size.y, (r + 0.5) * size.z / rows)
			_add(st, ROOF, origin + p, 0.0, Vector3(cell.x, cell.x, cell.z))

	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _skin(rng.randi_range(0, SKINS.size() - 1))
	return mesh


static func _add(st: SurfaceTool, module: String, pos: Vector3, yaw: float, scale: Vector3) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(scale)
	st.append_from(_mesh(module), 0, Transform3D(basis, pos))


static func _mesh(module: String) -> Mesh:
	if not _meshes.has(module):
		var scene: Node = load(KIT + module + ".glb").instantiate()
		var m: MeshInstance3D = scene.find_children("*", "MeshInstance3D")[0]
		_meshes[module] = m.mesh
		scene.free()
	return _meshes[module]


static func _skin(i: int) -> StandardMaterial3D:
	if _skins.is_empty():
		var base: StandardMaterial3D = _mesh(ROOF).surface_get_material(0)
		for path in SKINS:
			var m: StandardMaterial3D = base.duplicate()
			m.albedo_texture = load(KIT + path)
			m.albedo_color = Color(0.82, 0.8, 0.8)  # the kit is bright; tone it to the city light
			m.roughness = 0.9
			_skins.append(m)
	return _skins[i]


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return list[rng.randi_range(0, list.size() - 1)]
