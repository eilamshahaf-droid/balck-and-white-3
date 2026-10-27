class_name Police
extends Node3D
## The police (design doc: "המשטרה והעירייה: לא רנדומלי"). They don't demolish
## and they don't convert anyone; they keep the peace. The cult's crews add to
## a building's hidden `Heat` while they work it (fighters scaring people out
## most of all); when `Heat` calls the police the street in front of the
## building is closed, and the campaign waits until the roadblock is gone.
## Poor districts are soft, rich ones hard, and districts that are yours are
## left alone. Exposure makes them jumpier.

const S: PoliceSettings = preload("res://data/police.tres")
const BARRIER := Vector3(3.2, 1.0, 0.3)
const CAR := Vector3(2.0, 1.4, 4.4)
const STREET_WIDTH := 10.0              # the carriageway between the two barriers
const PROPS_LAYER := 4                   # physics layer 3: taxis, litter, trees

@export var campaigns: Campaigns
@export var districts: Districts
@export var faith: Node
@export var heat: Heat

var _blocks := {}           # building -> Roadblock
var _timer := 0.0
var _white := _mat(S.barrier_color)
var _red := _mat(S.stripe_color)
var _blue := _mat(S.car_color)
var _dented := _mat(S.dented_color)
var _closed := _tile_mat(S.closed_street_color)
var _count := 0                  # roadblocks raised so far, for their names


class Roadblock:
	var node: Node3D
	var label: Label3D
	var number := 0
	var shown := -1
	var left := 0.0
	var hp := 0.0
	var stage := 0                       # 0 intact, 1 dented, 2 wrecked
	var parts: Array[MeshInstance3D] = []


func _ready() -> void:
	heat.police_called.connect(_on_police_called)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.check_interval
	_lift_roadblocks()
	_wear_down()
	for b in campaigns.marked():
		var crew := campaigns.crew_at(b)
		if crew == 0 or _blocks.has(b) or _is_safe(b):
			continue
		heat.set_hardness(b, _hardness_of(b))
		var strain := crew + S.doubter_share * _doubters_in(b)
		if campaigns.route_of(b) == Campaigns.Route.FORCE:
			strain *= S.force_multiplier
		strain *= 1.0 + faith.exposure * S.exposure_multiplier
		heat.raise(b, Heat.Reason.CROWD, strain * S.check_interval)


## For the HUD: what the police are doing.
func status_text() -> String:
	if _blocks.is_empty():
		return "quiet"
	return "%d street%s closed" % [_blocks.size(), "" if _blocks.size() == 1 else "s"]


func _on_police_called(building: Node3D, _reason: Heat.Reason) -> void:
	if _blocks.has(building) or _is_safe(building):
		return
	_close_street(building)


func _is_safe(building: Node3D) -> bool:
	var i := districts.index_of(building)
	return i < 0 or districts.is_controlled(districts.district_at(building.global_position)) or districts.leaves_alone(districts.district_at(building.global_position))


func _doubters_in(building: Node3D) -> int:
	var i := districts.index_of(building)
	return districts.residents_in(i) - districts.believers_at(i)


func _hardness_of(building: Node3D) -> float:
	return clampf(districts.wealth_at(districts.index_of(building)) / S.hardest_wealth, 0.0, 1.0)


## Does a roadblock stand at `building`? Its output (money, belief) stops meanwhile.
func is_blockaded(building: Node3D) -> bool:
	return _blocks.has(building)


## Is the street at `point` shut by a roadblock? Commuters ask this before they cross.
func is_closed_at(point: Vector3) -> bool:
	for b: Node3D in _blocks.keys():
		var local := (_blocks[b] as Roadblock).node.to_local(point)
		if absf(local.x) <= S.closed_half_length and absf(local.z - 1.5) <= STREET_WIDTH / 2.0:
			return true
	return false


## A frog lands at `point` (Miracles rolls the chance): a roadblock within `radius` is
## smashed and its campaign goes on, and the police notice. True when one broke.
func break_near(point: Vector3, radius: float) -> bool:
	for b: Node3D in _blocks.keys():
		var roadblock: Roadblock = _blocks[b]
		if roadblock.node.global_position.distance_to(point) > radius:
			continue
		_remove(b)
		campaigns.block(b, 0.0)
		heat.raise(b, Heat.Reason.CROWD, S.break_heat)
		return true
	return false


## Anything that harms a roadblock near `point` (frogs, a thrown taxi, a blaze).
func damage_near(point: Vector3, radius: float, amount: float) -> void:
	for b: Node3D in _blocks.keys():
		var roadblock: Roadblock = _blocks[b]
		if roadblock.node.global_position.distance_to(point) <= radius:
			_hurt(b, amount)


func _close_street(building: Node3D) -> void:
	var parts: Array[MeshInstance3D] = []
	campaigns.block(building, S.roadblock_time)
	var spot := campaigns.spot_outside(building)
	var block := Node3D.new()
	add_child(block)
	block.global_position = spot
	block.look_at(Vector3(building.global_position.x, spot.y, building.global_position.z), Vector3.UP, true)
	for side in [-1.0, 1.0]:
		var end: float = side * S.closed_half_length
		parts.append(_part(block, BARRIER, Vector3(end, BARRIER.y / 2.0, 1.5), _white))
		_part(block, Vector3(BARRIER.x, 0.25, BARRIER.z * 1.1), Vector3(end, BARRIER.y * 0.7, 1.5), _red)
	_part(block, CAR, Vector3(-S.closed_half_length + 3.0, CAR.y / 2.0, 1.5), _blue)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 16
	label.pixel_size = S.label_size
	label.modulate = S.stripe_color.lightened(0.3)
	label.position = Vector3(0.0, 3.5, 1.5)
	block.add_child(label)
	_part(block, Vector3(S.closed_half_length * 2.0, 0.06, STREET_WIDTH), Vector3(0.0, 0.03, 1.5), _closed)
	var roadblock := Roadblock.new()
	roadblock.node = block
	roadblock.label = label
	roadblock.parts = parts
	roadblock.hp = S.roadblock_hp
	var hit_area := Area3D.new()
	hit_area.collision_layer = 0
	hit_area.collision_mask = PROPS_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(S.closed_half_length * 2.0, 3.0, STREET_WIDTH)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 1.5)
	hit_area.add_child(shape)
	block.add_child(hit_area)
	hit_area.body_entered.connect(_on_thrown_at.bind(building))
	_count += 1
	roadblock.number = _count
	roadblock.left = S.roadblock_time
	_blocks[building] = roadblock


## Fire and a believer crowd wear a roadblock down every tick.
func _wear_down() -> void:
	for b: Node3D in _blocks.keys():
		var roadblock: Roadblock = _blocks[b]
		for fire: Node3D in get_tree().get_nodes_in_group("fires"):
			if fire.global_position.distance_to(roadblock.node.global_position) <= S.fire_radius:
				_hurt(b, S.fire_damage * S.check_interval)
				if not _blocks.has(b):
					break
		if not _blocks.has(b):
			continue
		var crowd := districts.believers_in(b)
		if crowd >= S.crowd_size:
			_hurt(b, S.crowd_damage * crowd * S.check_interval)


func _on_thrown_at(body: Node3D, building: Node3D) -> void:
	var thing := body as RigidBody3D
	if thing and thing.linear_velocity.length() >= S.break_speed:
		_hurt(building, S.throw_damage * thing.linear_velocity.length())


func _hurt(building: Node3D, amount: float) -> void:
	var roadblock: Roadblock = _blocks.get(building)
	if roadblock == null:
		return
	roadblock.hp -= amount
	if roadblock.hp <= 0.0:
		_remove(building)
		campaigns.block(building, 0.0)
		return
	var stage := 0 if roadblock.hp > S.roadblock_hp * 0.66 else (1 if roadblock.hp > S.roadblock_hp * 0.33 else 2)
	if stage == roadblock.stage:
		return
	roadblock.stage = stage
	for i in roadblock.parts.size():
		var part := roadblock.parts[i]
		part.material_override = _dented
		part.rotation.z = deg_to_rad(S.wreck_tilt * stage) * (1.0 if i == 0 else -1.0)


func _remove(building: Node3D) -> void:
	var roadblock: Roadblock = _blocks[building]
	roadblock.node.queue_free()
	_blocks.erase(building)


func _lift_roadblocks() -> void:
	for b: Node3D in _blocks.keys():
		var roadblock: Roadblock = _blocks[b]
		roadblock.left -= S.check_interval
		if roadblock.left <= 0.0 or not is_instance_valid(b):
			_remove(b)
			continue
		var seconds := ceili(roadblock.left)
		if seconds != roadblock.shown:
			roadblock.shown = seconds
			roadblock.label.text = "ROADBLOCK %d\nstreet closed, %d s" % [roadblock.number, seconds]


func _part(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SharedMeshes.box(Vector3.ONE)
	mesh.material_override = material
	mesh.scale = size
	mesh.position = at
	parent.add_child(mesh)
	return mesh


static func _tile_mat(color: Color) -> StandardMaterial3D:
	var m := _mat(color)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
