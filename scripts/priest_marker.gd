class_name PriestMarker
extends Node3D
## Makes the head priest easy to find: a golden ring on the ground around his
## feet and a label with his name above him, which says "preaching..." for a
## moment whenever he talks to the street. It follows his body, which comes and
## goes as the street swaps people in and out.

const M: MiracleSettings = preload("res://data/miracles.tres")

@export var population: Population

var _ring: MeshInstance3D
var _label: Label3D
var _preach_left := 0.0
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


## The priest is preaching to the street: say so for a few seconds.
func show_preaching() -> void:
	_preach_left = M.priest_preach_mark_time


func _process(delta: float) -> void:
	var priest := population.priest
	var body := priest.body if priest else null
	visible = body != null and is_instance_valid(body)
	if not visible:
		return
	global_position = body.global_position
	_preach_left = maxf(_preach_left - delta, 0.0)
	var title := "Head Priest\n%s" % priest.full_name()
	if _preach_left > 0.0:
		title += "\npreaching..."
	if title != _title:
		_title = title
		_label.text = title
