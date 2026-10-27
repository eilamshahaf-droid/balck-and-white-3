class_name Police
extends Node3D
## The police (design doc: "המשטרה והעירייה: לא רנדומלי"). They don't demolish
## and they don't convert anyone; they keep the peace. A street where the
## cult's crews work too hard, above all where fighters scare people out of a
## building full of non-believers, heats up, and at enough heat the police
## close it: a roadblock in front of the building, and the campaign waits until
## it is gone. Exposure makes them jumpier. Districts that are yours are left
## alone.

const S: PoliceSettings = preload("res://data/police.tres")
const LINE := "POLICE LINE - DO NOT CROSS"
const BARRIER := Vector3(3.2, 1.0, 0.3)
const CAR := Vector3(2.0, 1.4, 4.4)

@export var campaigns: Campaigns
@export var districts: Districts
@export var faith: Node

var _heat := {}             # building -> heat
var _blocks := {}           # building -> Roadblock
var _timer := 0.0
var _white := _mat(S.barrier_color)
var _red := _mat(S.stripe_color)
var _blue := _mat(S.car_color)


class Roadblock:
	var node: Node3D
	var left := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.check_interval
	_lift_roadblocks()
	var marked := campaigns.marked()
	for b: Node3D in _heat.keys():
		if not b in marked or not is_instance_valid(b):
			_heat.erase(b)
	for b in marked:
		if _blocks.has(b):
			continue
		var heat: float = _heat.get(b, 0.0) + _heat_from(b) * S.check_interval
		_heat[b] = maxf(heat, 0.0)
		if heat >= S.roadblock_heat:
			_heat[b] = 0.0
			_close_street(b)


## For the HUD: what the police are doing.
func status_text() -> String:
	if not _blocks.is_empty():
		return "%d street%s closed" % [_blocks.size(), "" if _blocks.size() == 1 else "s"]
	for b in _heat:
		if _heat[b] > S.roadblock_heat / 2.0:
			return "patrolling"
	return "quiet"


func _heat_from(building: Node3D) -> float:
	var i := districts.index_of(building)
	if i < 0 or districts.is_controlled(districts.district_at(building.global_position)):
		return -S.heat_decay
	var crew := campaigns.crew_at(building)
	if crew == 0:
		return -S.heat_decay
	var doubters := districts.residents_in(i) - districts.believers_at(i)
	var heat := S.heat_per_crew * crew + S.heat_per_doubter * doubters
	if campaigns.route_of(building) == Campaigns.Route.FORCE:
		heat *= S.force_multiplier
	return heat * (1.0 + faith.exposure * S.exposure_multiplier)


func _close_street(building: Node3D) -> void:
	campaigns.block(building, S.roadblock_time)
	var spot := campaigns.spot_outside(building)
	var block := Node3D.new()
	add_child(block)
	block.global_position = spot
	block.look_at(Vector3(building.global_position.x, spot.y, building.global_position.z), Vector3.UP, true)
	for side in [-1.0, 1.0]:
		_part(block, BARRIER, Vector3(side * 2.2, BARRIER.y / 2.0, 1.5), _white)
		_part(block, Vector3(BARRIER.x, 0.25, BARRIER.z * 1.1), Vector3(side * 2.2, BARRIER.y * 0.7, 1.5), _red)
	_part(block, CAR, Vector3(0.0, CAR.y / 2.0, 4.5), _blue)
	var label := Label3D.new()
	label.text = LINE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 16
	label.pixel_size = 0.02
	label.modulate = S.stripe_color.lightened(0.3)
	label.position = Vector3(0.0, 3.5, 1.5)
	block.add_child(label)
	var roadblock := Roadblock.new()
	roadblock.node = block
	roadblock.left = S.roadblock_time
	_blocks[building] = roadblock


func _lift_roadblocks() -> void:
	for b: Node3D in _blocks.keys():
		var roadblock: Roadblock = _blocks[b]
		roadblock.left -= S.check_interval
		if roadblock.left <= 0.0 or not is_instance_valid(b):
			roadblock.node.queue_free()
			_blocks.erase(b)


func _part(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SharedMeshes.box(Vector3.ONE)
	mesh.material_override = material
	mesh.scale = size
	mesh.position = at
	parent.add_child(mesh)


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
