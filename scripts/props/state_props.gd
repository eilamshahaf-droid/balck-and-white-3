class_name StateProps
extends Node3D
## Shows who holds every building, with Meshy props on top of the building
## (never in place of it), changed live as the building changes hands:
## - yours: the cult's purple banner down the front and its flag on the roof;
## - abandoned: boarded-up windows and rubble on the sidewalk;
## - luxury (the decree): flower boxes under most windows and topiary planters
##   by the entrance canopy;
## - inhabited: a few flower boxes, more in rich districts; laundry lines in
##   poor ones.
## Each kind is a MultiMesh per chunk of town that is rewritten when one of
## its buildings changes, which happens a few times a minute at most.

const SETTINGS_PATH := "res://data/city_props.tres"
const D: DecreeSettings = preload("res://data/decrees.tres")
const DivineSign := preload("res://scripts/divine_sign.gd")

## The props already on the city: their window grid, and which windows have an
## air conditioner (no flower box goes there).
@export var city_props: CityProps
## Who holds each building; its signals redress a building.
@export var districts: Districts
## Floors and luxury change a building's look.
@export var decrees: Decrees

var _s: CityPropsSettings
var _pools := {}      # [PropKind, Vector2i chunk] -> Pool
var _dressed := {}    # building (Node3D) -> Array[Pool] it has props in


## One kind of prop in one chunk of town.
class Pool:
	var multimesh := MultiMesh.new()
	var by_building := {}   # building (Node3D) -> Array[Transform3D]


func _ready() -> void:
	_s = load(SETTINGS_PATH)
	await city_props.dressed
	districts.building_changed.connect(_on_building_changed)
	districts.building_abandoned.connect(_on_building_abandoned)
	if decrees:
		decrees.decree_issued.connect(_on_decree_issued)
	var touched := {}
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Node3D
		building.tree_exiting.connect(_on_building_gone.bind(building))
		_dress(building, touched)
	_redraw(touched)


## Takes `building`'s props off and puts on the ones for how it is now.
func refresh(building: Node3D) -> void:
	var touched := {}
	_dress(building, touched)
	_redraw(touched)


func _on_building_changed(index: int, _yours: bool) -> void:
	var building := districts.buildings[index]
	if building:
		refresh(building)


func _on_building_abandoned(index: int) -> void:
	refresh(districts.buildings[index])


func _on_decree_issued(kind: StringName, building: Node3D) -> void:
	if kind == &"floors":
		# Redress once the new floors have risen.
		await get_tree().create_timer(D.grow_time).timeout
	elif kind != &"luxury":
		return
	if is_instance_valid(building):
		refresh(building)


func _on_building_gone(building: Node3D) -> void:
	var touched := {}
	_undress(building, touched)
	_redraw(touched)


# --- Choosing the props ---

func _dress(building: Node3D, touched: Dictionary) -> void:
	_undress(building, touched)
	var size := DivineSign.building_size(building)
	var index := districts.index_of(building)
	var abandoned := index >= 0 and districts.is_abandoned(index)
	var luxury: bool = building.get_meta(&"decree_luxury", false)
	var wealth := districts.wealth_of(districts.district_at(building.global_position))
	# The same building always draws the same windows.
	var rng := RandomNumberGenerator.new()
	rng.seed = building.get_instance_id()
	if abandoned:
		_on_windows(building, size, _s.boarded_window, _s.boarded_share, rng,
				_s.window_middle - PropModel.of(_s.boarded_window).size.y / 2.0, touched)
		_rubble(building, size, rng, touched)
	elif luxury:
		_on_windows(building, size, _s.flower_box, _s.luxury_flower_chance, rng, _s.sill_height,
				touched)
		_planters(building, size, touched)
	elif wealth < _s.poor_wealth:
		_on_windows(building, size, _s.laundry, _s.laundry_chance, rng, _s.laundry_height, touched)
	else:
		_on_windows(building, size, _s.flower_box, _s.flower_chance * wealth, rng, _s.sill_height,
				touched)
	if districts.owns(building):
		_banner(building, size, touched)
		_flag(building, size, touched)


## `kind` under `chance` of the windows above the ground floor that have no air
## conditioner, `height` metres above each floor.
func _on_windows(building: Node3D, size: Vector3, kind: PropKind, chance: float,
		rng: RandomNumberGenerator, height: float, touched: Dictionary) -> void:
	if size.y > _s.facade_max_height:
		return
	var grid := CityProps.facade_grid(size)
	var units := city_props.ac_slots(building)
	var wall := PropModel.of(kind).against_wall()
	for side: float in [-1.0, 1.0]:
		for f in range(1, grid.y):
			for c in grid.x:
				if rng.randf() >= chance or CityProps.slot_key(side, f, c) in units:
					continue
				var frame := CityProps.window_frame(building, size, side, f, c, height)
				_add(building, kind, frame * wall, touched)


func _rubble(building: Node3D, size: Vector3, rng: RandomNumberGenerator,
		touched: Dictionary) -> void:
	# At a corner, clear of the door near the middle of the front.
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var x := (size.x / 2.0 - PropModel.of(_s.rubble).size.x / 2.0 - 0.5) * signf(rng.randf() - 0.5)
	var at := _ground(building, size) + Vector3(x, 0.0, side * (size.z / 2.0 + _s.wall_gap))
	var turn := Basis(Vector3.UP, rng.randf() * TAU)
	_add(building, _s.rubble, Transform3D(turn, at) * PropModel.of(_s.rubble).offset, touched)


func _planters(building: Node3D, size: Vector3, touched: Dictionary) -> void:
	# Either side of decree_looks.gd's canopy, which is half the front wide.
	var model := PropModel.of(_s.planter)
	var out := _s.wall_gap + model.size.z / 2.0
	for side: float in [-1.0, 1.0]:
		for across: float in [-1.0, 1.0]:
			var x := across * (size.x * 0.25 + model.size.x / 2.0 + 0.3)
			var at := _ground(building, size) + Vector3(x, 0.0, side * (size.z / 2.0 + out))
			_add(building, _s.planter, Transform3D(Basis.IDENTITY, at) * model.offset, touched)


func _banner(building: Node3D, size: Vector3, touched: Dictionary) -> void:
	# On the line between the first two bays, where no window prop or facade
	# stripe sits; down from just under the roof.
	var model := PropModel.of(_s.banner)
	var grid := CityProps.facade_grid(size)
	var x := -size.x / 2.0 + size.x / grid.x if grid.x > 1 else 0.0
	var top := size.y / 2.0 - _s.banner_drop - model.size.y
	for side: float in [-1.0, 1.0]:
		var facing := Basis(Vector3.UP, 0.0 if side > 0.0 else PI)
		var at := building.global_position + Vector3(x, top, side * size.z / 2.0)
		_add(building, _s.banner, Transform3D(facing, at) * model.against_wall(), touched)


func _flag(building: Node3D, size: Vector3, touched: Dictionary) -> void:
	# In a corner of the roof, clear of a penthouse and a rooftop use sign.
	var model := PropModel.of(_s.flag)
	var inset := _s.roof_margin + model.size.x / 2.0
	var corner := Vector3(size.x / 2.0 - inset, size.y / 2.0, -size.z / 2.0 + inset)
	var at := building.global_position + corner
	_add(building, _s.flag, Transform3D(Basis.IDENTITY, at) * model.offset, touched)


func _ground(building: Node3D, size: Vector3) -> Vector3:
	return building.global_position - Vector3.UP * size.y / 2.0


# --- Drawing ---

func _add(building: Node3D, kind: PropKind, transform: Transform3D, touched: Dictionary) -> void:
	var o := transform.origin
	var key := [kind, Vector2i(floori(o.x / _s.chunk_size), floori(o.z / _s.chunk_size))]
	var pool: Pool = _pools.get(key)
	if pool == null:
		pool = _new_pool(kind)
		_pools[key] = pool
	if not pool.by_building.has(building):
		pool.by_building[building] = []
		if not _dressed.has(building):
			_dressed[building] = []
		(_dressed[building] as Array).append(pool)
	(pool.by_building[building] as Array).append(transform)
	touched[pool] = true


func _undress(building: Node3D, touched: Dictionary) -> void:
	for pool: Pool in _dressed.get(building, []):
		pool.by_building.erase(building)
		touched[pool] = true
	_dressed.erase(building)


func _new_pool(kind: PropKind) -> Pool:
	var pool := Pool.new()
	pool.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	pool.multimesh.mesh = PropModel.of(kind).mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = pool.multimesh
	mmi.material_override = PropModel.of(kind).material
	mmi.visibility_range_end = _s.visible_distance
	add_child(mmi)
	return pool


func _redraw(touched: Dictionary) -> void:
	for pool: Pool in touched:
		var mm := pool.multimesh
		var count := 0
		for transforms: Array in pool.by_building.values():
			count += transforms.size()
		if count > mm.instance_count:
			mm.instance_count = maxi(count, mm.instance_count * 2)   # clears the old ones
		mm.visible_instance_count = count
		var i := 0
		for transforms: Array in pool.by_building.values():
			for t: Transform3D in transforms:
				mm.set_instance_transform(i, t)
				i += 1
