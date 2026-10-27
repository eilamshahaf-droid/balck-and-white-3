class_name TypeMarkers
extends Node3D
## Shows what a building is used for with a prop on its roof or by its front:
## the Change Use decree today. Kept apart from StateProps so the source of a
## building's type can change (home, work, seminary, ...) without touching how
## the states look. A handful of buildings at most, so each marker is its own
## node, sharing the prop's mesh and material.

const SETTINGS_PATH := "res://data/city_props.tres"
const DivineSign := preload("res://scripts/divine_sign.gd")

## Decrees tell which building changed its use.
@export var decrees: Decrees

var _s: CityPropsSettings
var _markers := {}   # building (Node3D) -> Array[MeshInstance3D]


func _ready() -> void:
	_s = load(SETTINGS_PATH)
	decrees.decree_issued.connect(_on_decree_issued)


func _on_decree_issued(kind: StringName, building: Node3D) -> void:
	if kind != &"use":
		return
	_clear(building)
	var use: String = building.get_meta(&"decree_use", "")
	var size := DivineSign.building_size(building)
	for marker in _s.use_markers:
		if marker.use_name == use:
			_place(building, size, marker)
	if _markers.has(building) and not building.tree_exiting.is_connected(_clear):
		building.tree_exiting.connect(_clear.bind(building))


func _place(building: Node3D, size: Vector3, marker: UseMarker) -> void:
	var model := PropModel.of(marker.kind)
	var at := building.global_position
	var frame: Transform3D
	if marker.on_roof:
		# Over the middle of the roof, where a penthouse or the use sign doesn't sit.
		frame = Transform3D(Basis.IDENTITY, at + Vector3(0.0, size.y / 2.0, size.z * 0.15)) \
				* model.offset
	else:
		# At the street end of the front, clear of the door.
		var x := size.x / 2.0 - model.size.x / 2.0 - 0.5
		var out := size.z / 2.0 + _s.wall_gap + model.size.z / 2.0
		frame = Transform3D(Basis.IDENTITY, at + Vector3(x, -size.y / 2.0, out)) * model.offset
	var mesh := MeshInstance3D.new()
	mesh.mesh = model.mesh
	mesh.material_override = model.material
	mesh.transform = frame
	mesh.visibility_range_end = _s.visible_distance
	add_child(mesh)
	if not _markers.has(building):
		_markers[building] = []
	(_markers[building] as Array).append(mesh)


func _clear(building: Node3D) -> void:
	for mesh: MeshInstance3D in _markers.get(building, []):
		mesh.queue_free()
	_markers.erase(building)
