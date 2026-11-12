class_name PlanBuilder
extends RefCounted
## Builds a stage's map (CityPlan) into the city: the ground with its land colours,
## the streets as ribbons along their centre lines, every building turned to face its
## street, and trees. The buildings of a unit (what the player takes) are one
## "buildings" node, its largest building, plus parts (group "building_parts") that
## point to it (BuildingBox.building_of), so every system that works on a building
## works on the whole unit.

const DoorScript := preload("res://scripts/door.gd")
const TreeScript := preload("res://scripts/swaying_tree.gd")
const BuildingVisual := preload("res://scripts/building_visual.gd")
const PARTS := &"building_parts"
const PALETTE: Array[Color] = [
	Color(0.62, 0.6, 0.57), Color(0.5, 0.42, 0.36), Color(0.7, 0.68, 0.62),
	Color(0.36, 0.45, 0.55), Color(0.45, 0.47, 0.5), Color(0.58, 0.5, 0.42),
]

## The "buildings" node of each unit, by CityPlan unit index.
var unit_nodes: Array[StaticBody3D] = []

var _city: Node3D
var _plan: CityPlan
var _s: CitySettings
var _materials := {}
var _rng := RandomNumberGenerator.new()


func _init(city: Node3D, plan: CityPlan, settings: CitySettings) -> void:
	_city = city
	_plan = plan
	_s = settings
	_rng.seed = 3


func build(layer_world: int, layer_props: int) -> void:
	_build_ground_colours()
	_build_streets()
	_build_units(layer_world)
	_plant_trees(layer_props)


func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[color] = m
	return _materials[color]


# --- Ground ---

## The land use painted on one plane over the asphalt: lots, parks, squares, water.
func _build_ground_colours() -> void:
	var w := _plan.ground_size.x
	var h := _plan.ground_size.y
	var image := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			image.set_pixel(x, y, _s.ground_color(_plan.ground[y * w + x]))
	image.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = 0.9
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, h) * _plan.ground_cell
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = m
	mesh.position = Vector3(plane.size.x - _plan.size.x, 0.0, plane.size.y - _plan.size.y) / 2.0 \
			+ Vector3.UP * 0.01
	_city.add_child(mesh)


# --- Streets ---

## Every street as two ribbons (sidewalks, then asphalt on top) and a dashed centre
## line, all merged into three meshes.
func _build_streets() -> void:
	var walks := SurfaceTool.new()
	var asphalt := SurfaceTool.new()
	var lines := SurfaceTool.new()
	for st in [walks, asphalt, lines]:
		(st as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	for road in _plan.roads:
		_ribbon(walks, road.points, road.width, _s.sidewalk_lift)
		_ribbon(asphalt, road.points, road.road, _s.asphalt_lift)
		if not road.one_way and road.road >= _s.dashed_from:
			_dashes(lines, road.points)
	for pair: Array in [[walks, _s.sidewalk_color], [asphalt, _s.asphalt_color], [lines, _s.line_color]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.material_override = material(pair[1])
		mesh.set_meta("surface", &"asphalt")
		_city.add_child(mesh)


## A flat strip `width` wide along `points`, mitred at the bends.
static func _ribbon(st: SurfaceTool, points: PackedVector2Array, width: float, lift: float) -> void:
	if points.size() < 2:
		return
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in points.size():
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, points.size() - 1)]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x) * width / 2.0
		left.append(Vector3(points[i].x + side.x, lift, points[i].y + side.y))
		right.append(Vector3(points[i].x - side.x, lift, points[i].y - side.y))
	for i in points.size() - 1:
		for v in [left[i], right[i], left[i + 1], right[i], right[i + 1], left[i + 1]]:
			st.add_vertex(v)


func _dashes(st: SurfaceTool, points: PackedVector2Array) -> void:
	var carry := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var at := carry
		while at < length:
			var end := minf(at + _s.dash.x, length)
			_ribbon(st, PackedVector2Array([a.lerp(b, at / length), a.lerp(b, end / length)]),
					_s.dash.z, _s.asphalt_lift + 0.01)
			at += _s.dash.x + _s.dash.y
		carry = at - length


# --- Buildings ---

func _build_units(layer: int) -> void:
	for u in _plan.units.size():
		var members := _plan.units[u].buildings
		var main := members[0]
		for b in members:
			if _volume(b) > _volume(main):
				main = b
		var node := _building(_plan.buildings[main], layer)
		node.add_to_group("buildings")
		node.set_meta(&"unit", u)
		unit_nodes.append(node)
		var parts: Array[Node3D] = []
		for b in members:
			if b != main:
				var part := _building(_plan.buildings[b], layer)
				part.add_to_group(PARTS)
				part.set_meta(&"building", node)
				parts.append(part)
		node.set_meta(&"parts", parts)


func _volume(b: int) -> float:
	var p := _plan.buildings[b]
	return p.size.x * p.size.y * p.floors * p.storey


## One building: a box turned to its street, dressed in the Kenney facades, with a
## door on the street side (local -z).
func _building(p: CityPlan.Building, layer: int) -> StaticBody3D:
	var height := p.floors * p.storey * _s.vertical_scale
	var size := Vector3(p.size.x - _s.party_wall_gap, height, p.size.y - _s.party_wall_gap)
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = Vector3(p.centre.x, height / 2.0, p.centre.y)
	body.rotation.y = -p.angle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var glass := _s.glass_kinds.has(String(p.kind))
	body.add_child(BuildingVisual.build(size, hash(body.position), glass))
	body.set_meta("surface", &"glass" if glass else &"concrete")
	body.set_meta(&"kind", p.kind)
	body.set_meta(&"facade", p.facade)
	_city.add_child(body)
	# The door stands on the street, not on the building, so it stays put when a decree
	# raises the building.
	var door: Node3D = DoorScript.new()
	door.build(material(Color(0.3, 0.2, 0.14)))
	_city.add_child(door)
	door.transform = body.transform * Transform3D(Basis(Vector3.UP, PI),
			Vector3(-0.7, -height / 2.0, -size.z / 2.0 - 0.07))
	return body


# --- Trees ---

func _plant_trees(layer: int) -> void:
	var trunk := material(Color(0.35, 0.25, 0.15))
	var crown := material(Color(0.2, 0.42, 0.18))
	for t in _plan.trees:
		if _rng.randf() >= _s.tree_share:
			continue
		var tree: StaticBody3D = TreeScript.new()
		tree.collision_layer = layer
		tree.collision_mask = 0
		tree.build(trunk, crown, maxf(t.z, 1.0))
		tree.position = Vector3(t.x, 0.0, t.y)
		_city.add_child(tree)
