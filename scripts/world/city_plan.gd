class_name CityPlan
extends RefCounted
## A stage's map, made in the Map Lab and written by tools/maplab/export_map.js
## (data/maps/<stage>/map.json): streets, the graph people walk, districts, buildings,
## the units the player takes (a block or a run of one, each a few buildings) and
## trees. Pure data in game metres on the ground plane (x, z).


class Road:
	var points := PackedVector2Array()
	var tier := &""
	var width := 0.0     # kerb to kerb plus both sidewalks
	var road := 0.0      # kerb to kerb
	var walk := 0.0      # one sidewalk
	var one_way := false


class District:
	var archetype := &""
	var kind := ""
	var title := ""
	var name := ""
	var centre := Vector2.ZERO


class Building:
	var centre := Vector2.ZERO
	var size := Vector2.ONE   # along the street, back from it
	var angle := 0.0          # of the street side, from +x toward +z
	var floors := 1
	var storey := 3.2
	var kind := &""
	var district := -1
	var facade := &""
	var unit := -1


class Unit:
	var district := -1
	var core := false
	var buildings := PackedInt32Array()
	var next := PackedInt32Array()


const NODE_CELL := 12.0   # spatial hash cell for nearest_node

var size := Vector2.ONE
var roads: Array[Road] = []
var nodes := PackedVector2Array()
var neighbours: Array[PackedInt32Array] = []
var districts: Array[District] = []
var start_district := 0
var buildings: Array[Building] = []
var units: Array[Unit] = []
## x, z and crown size of every tree.
var trees := PackedVector3Array()
## Land use per ground cell (0 street, 1 + Map Lab use, 250 water), cell `ground_cell` wide.
var ground := PackedByteArray()
var ground_cell := 1.0
var ground_size := Vector2i.ZERO

var _district_cells := PackedByteArray()
var _district_cell := 1.0
var _district_size := Vector2i.ZERO
var _node_hash := {}   # Vector2i -> PackedInt32Array


static func load_file(path: String) -> CityPlan:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Can't read the stage map %s" % path)
		return null
	var plan := CityPlan.new()
	plan._read(data)
	return plan


## The district at `p` on the ground, or -1 outside every district.
func district_at(p: Vector2) -> int:
	var c := Vector2i(((p + size / 2.0) / _district_cell).floor())
	if c.x < 0 or c.y < 0 or c.x >= _district_size.x or c.y >= _district_size.y:
		return -1
	var v := _district_cells[c.y * _district_size.x + c.x]
	return -1 if v == 255 else v


## The walking node nearest `p`.
func nearest_node(p: Vector2) -> int:
	var key := Vector2i((p / NODE_CELL).floor())
	var best := -1
	var best_d := INF
	for ring in 64:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				for n: int in _node_hash.get(key + Vector2i(dx, dy), PackedInt32Array()):
					var d := nodes[n].distance_squared_to(p)
					if d < best_d:
						best_d = d
						best = n
		# Anything in the next ring is at least `ring` cells away.
		if best >= 0 and sqrt(best_d) <= ring * NODE_CELL:
			return best
	return best if best >= 0 else 0


func _read(data: Dictionary) -> void:
	size = _vec(data.size)
	for r: Dictionary in data.roads:
		if r.get("fast", false):
			continue
		var road := Road.new()
		road.points = _points(r.pts)
		road.tier = StringName(r.tier)
		road.width = r.width
		road.road = r.road
		road.walk = r.walk
		road.one_way = r.oneway
		roads.append(road)
	nodes = _points(data.nodes)
	neighbours.resize(nodes.size())
	for n in nodes.size():
		neighbours[n] = PackedInt32Array()
	var edges: Array = data.edges
	for k in range(0, edges.size(), 2):
		var a := int(edges[k])
		var b := int(edges[k + 1])
		neighbours[a].append(b)
		neighbours[b].append(a)
	for n in nodes.size():
		var key := Vector2i((nodes[n] / NODE_CELL).floor())
		var list: PackedInt32Array = _node_hash.get(key, PackedInt32Array())
		list.append(n)
		_node_hash[key] = list
	for i in data.districts.size():
		var d: Dictionary = data.districts[i]
		var district := District.new()
		district.archetype = StringName(d.archetype)
		district.kind = d.kind
		district.title = d.title
		district.name = d.name
		district.centre = _vec(d.centre)
		districts.append(district)
		if d.start:
			start_district = i
	var cells: Dictionary = data.district_cells
	_district_cell = cells.cell
	_district_size = Vector2i(int(cells.w), int(cells.h))
	_district_cells = Marshalls.base64_to_raw(cells.data)
	var g: Dictionary = data.ground
	ground_cell = g.cell
	ground_size = Vector2i(int(g.w), int(g.h))
	ground = Marshalls.base64_to_raw(g.data)
	for b: Dictionary in data.buildings:
		var building := Building.new()
		building.centre = _vec(b.c)
		building.size = _vec(b.size)
		building.angle = b.angle
		building.floors = int(b.floors)
		building.storey = b.storey
		building.kind = StringName(b.kind)
		building.district = int(b.district)
		building.facade = StringName(b.facade)
		building.unit = int(b.unit)
		buildings.append(building)
	for u: Dictionary in data.units:
		var unit := Unit.new()
		unit.district = int(u.district)
		unit.core = u.core
		unit.buildings = PackedInt32Array(u.buildings)
		unit.next = PackedInt32Array(u.next)
		units.append(unit)
	var t: Array = data.trees
	for k in range(0, t.size(), 3):
		trees.append(Vector3(t[k], t[k + 1], t[k + 2]))


static func _vec(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


static func _points(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(0, flat.size(), 2):
		out.append(Vector2(flat[k], flat[k + 1]))
	return out
