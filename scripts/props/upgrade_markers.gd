class_name UpgradeMarkers
extends Node3D
## Shows the housing upgrades a building has bought with Meshy props: an
## elevator shaft up its side, a garden on its roof, cameras by the door and
## a gate at the street. Kept apart from the other markers so the upgrade list
## can grow without touching how states or uses look. A handful of buildings
## at most, so each prop is its own node, sharing the model's mesh and material.

const SETTINGS_PATH := "res://data/city_props.tres"
const DivineSign := preload("res://scripts/divine_sign.gd")

## Tells which building bought what.
@export var population: Population

var _s: CityPropsSettings
var _props := {}   # building (Node3D) -> Array[MeshInstance3D]


func _ready() -> void:
	_s = load(SETTINGS_PATH)
	population.upgraded.connect(_on_upgraded)


func _on_upgraded(building: Node3D, _kind: Population.Upgrade) -> void:
	_clear(building)
	var size := DivineSign.building_size(building)
	var bought := population.upgrades_of(building)
	for marker in _s.upgrade_markers:
		if marker.upgrade in bought:
			_place(building, size, marker)
	if _props.has(building) and not building.tree_exiting.is_connected(_clear):
		building.tree_exiting.connect(_clear.bind(building))


func _place(building: Node3D, size: Vector3, marker: UpgradeMarker) -> void:
	var model := PropModel.of(marker.kind)
	var at := building.global_position
	var x := (marker.across - 0.5) * size.x
	var frame: Transform3D
	match marker.place:
		UpgradeMarker.Place.ROOF:
			frame = Transform3D(Basis.IDENTITY, at + Vector3(x, size.y / 2.0, 0.0)) * model.offset
		UpgradeMarker.Place.WALL:
			var wall := at + Vector3(x, marker.height - size.y / 2.0, size.z / 2.0)
			frame = Transform3D(Basis.IDENTITY, wall) * model.against_wall()
		_:
			var out := size.z / 2.0 + _s.wall_gap + model.size.z / 2.0
			frame = Transform3D(Basis.IDENTITY, at + Vector3(x, -size.y / 2.0, out)) * model.offset
	var mesh := MeshInstance3D.new()
	mesh.mesh = model.mesh
	mesh.material_override = model.material
	mesh.transform = frame
	mesh.visibility_range_end = _s.visible_distance
	add_child(mesh)
	if not _props.has(building):
		_props[building] = []
	(_props[building] as Array).append(mesh)


func _clear(building: Node3D) -> void:
	for mesh: MeshInstance3D in _props.get(building, []):
		mesh.queue_free()
	_props.erase(building)
