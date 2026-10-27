class_name CoreMarkers
extends Node3D
## Gives each district's core building its own look: a columned portico in
## front, and a big signboard on the roof with the district's name. Moves
## them when the core is demolished and the next building takes over. The name
## is a Label3D on the blank Meshy sign, because the model can't spell.

const SETTINGS_PATH := "res://data/city_props.tres"
const DivineSign := preload("res://scripts/divine_sign.gd")

## Says which building is each district's core.
@export var districts: Districts

var _s: CityPropsSettings
var _nodes := {}   # district (int) -> Array[Node3D]


func _ready() -> void:
	_s = load(SETTINGS_PATH)
	districts.layout_ready.connect(_on_layout_ready)
	districts.core_changed.connect(_dress)


func _on_layout_ready() -> void:
	for d in districts.district_count():
		_dress(d)


func _dress(d: int) -> void:
	for node: Node3D in _nodes.get(d, []):
		node.queue_free()
	_nodes.erase(d)
	var index := districts.core_of(d)
	if index < 0 or districts.buildings[index] == null:
		return
	var building := districts.buildings[index]
	var size := DivineSign.building_size(building)
	var at := building.global_position
	var made: Array[Node3D] = []
	var portico := PropModel.of(_s.core_portico)
	var front := Vector3(0.0, -size.y / 2.0, size.z / 2.0 + _s.wall_gap)
	made.append(_prop(_s.core_portico, Transform3D(Basis.IDENTITY, at + front)
			* portico.against_wall()))
	var board := PropModel.of(_s.core_sign)
	var roof := Vector3(0.0, size.y / 2.0, 0.0)
	made.append(_prop(_s.core_sign, Transform3D(Basis.IDENTITY, at + roof) * board.offset))
	made.append(_name_label(districts.district_name(d), at + roof, board.size))
	_nodes[d] = made


func _prop(kind: PropKind, frame: Transform3D) -> MeshInstance3D:
	var model := PropModel.of(kind)
	var mesh := MeshInstance3D.new()
	mesh.mesh = model.mesh
	mesh.material_override = model.material
	mesh.transform = frame
	mesh.visibility_range_end = _s.core_visible_distance
	add_child(mesh)
	return mesh


## The district's name on the sign's front, the size of its panel.
func _name_label(text: String, roof: Vector3, board: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = _s.core_label_font_size
	label.pixel_size = _s.core_label_pixel_size
	label.modulate = _s.core_label_color
	label.outline_size = 0
	label.width = board.x * 0.85 / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = roof + Vector3(0.0, board.y * _s.core_label_height, board.z / 2.0 + 0.02)
	label.visibility_range_end = _s.core_visible_distance
	add_child(label)
	return label
