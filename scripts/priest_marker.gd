class_name PriestMarker
extends Node3D
## Makes the high priest easy to find: a golden ring on the ground around his
## feet and a label with his name above him, which says "preaching..." for a
## moment whenever he talks to the street. It follows his body, which comes and
## goes as the street swaps people in and out.

const M: MiracleSettings = preload("res://data/miracles.tres")
const U: UnitSettings = preload("res://data/units.tres")

@export var population: Population

var _ring: MeshInstance3D
var _label: Label3D
var _title := ""


func _ready() -> void:
	var disc := TorusMesh.new()
	disc.inner_radius = M.priest_ring_radius - 0.15
	disc.outer_radius = M.priest_ring_radius
	disc.rings = 24
	disc.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = M.priest_ring_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	disc.material = mat
	_ring = MeshInstance3D.new()
	_ring.mesh = disc
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_to_group(&"no_toon")
	add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = M.priest_label_pixel
	_label.font_size = 36
	_label.outline_size = 12
	_label.modulate = M.priest_ring_color
	_label.position = Vector3.UP * M.priest_label_height
	add_child(_label)


func _process(_delta: float) -> void:
	var priest := population.priest
	var body := priest.body if priest else null
	visible = body != null and is_instance_valid(body)
	if not visible:
		return
	global_position = body.global_position
	var title := "%s\n%s" % [U.title(Resident.Rank.HIGH_PRIEST), priest.full_name()]
	if title != _title:
		_title = title
		_label.text = title
