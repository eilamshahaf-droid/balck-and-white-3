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
const LINE := "POLICE LINE - DO NOT CROSS"
const BARRIER := Vector3(3.2, 1.0, 0.3)
const CAR := Vector3(2.0, 1.4, 4.4)

@export var campaigns: Campaigns
@export var districts: Districts
@export var faith: Node
@export var heat: Heat

var _blocks := {}           # building -> Roadblock
var _timer := 0.0
var _white := _mat(S.barrier_color)
var _red := _mat(S.stripe_color)
var _blue := _mat(S.car_color)


class Roadblock:
	var node: Node3D
	var left := 0.0


func _ready() -> void:
	heat.police_called.connect(_on_police_called)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = S.check_interval
	_lift_roadblocks()
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


## Something big (the frogs) came down at `at`: wreck a roadblock within
## `radius`, which counts as a crowd at that building. True if one went.
func break_near(at: Vector3, radius: float) -> bool:
	for b: Node3D in _blocks.keys():
		var roadblock: Roadblock = _blocks[b]
		var flat := roadblock.node.global_position - at
		if Vector2(flat.x, flat.z).length() > radius:
			continue
		roadblock.node.queue_free()
		_blocks.erase(b)
		campaigns.unblock(b)
		heat.raise(b, Heat.Reason.CROWD, S.roadblock_break_heat)
		return true
	return false


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
