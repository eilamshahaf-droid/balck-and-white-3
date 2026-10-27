class_name SermonAlerts
extends Node
## Shows the player where a sermon is going on: a ring on the ground around the
## preaching priest and a button on the screen that flies the camera there. When
## the police move in the ring turns red and the button says so. The hidden
## raid chance is never shown. A sermon that ends takes its ring and button away.

const M: MiracleSettings = preload("res://data/miracles.tres")

@export var population: Population
@export var camera: GodCamera

var _rings := {}     # Resident -> ring node on the ground
var _buttons := {}   # Resident -> Button on the screen
var _box: VBoxContainer
var _calm: StandardMaterial3D
var _raid: StandardMaterial3D


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.offset_top = 64.0
	layer.add_child(_box)
	_calm = _material(M.sermon_calm_color)
	_raid = _material(M.sermon_raid_color)
	population.sermons.sermon_started.connect(_on_started)
	population.sermons.sermon_ended.connect(_on_ended)
	population.sermons.police_moved_in.connect(_on_police)


func _on_started(priest: Resident, at: Vector3, _risk: float) -> void:
	var ring := MeshInstance3D.new()
	var disc := TorusMesh.new()
	disc.inner_radius = M.sermon_ring_radius - 0.3
	disc.outer_radius = M.sermon_ring_radius
	disc.rings = 24
	disc.ring_segments = 6
	ring.mesh = disc
	ring.material_override = _calm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_to_group(&"no_toon")
	add_child(ring)
	ring.global_position = at + Vector3.UP * 0.2
	_rings[priest] = ring
	_alert(priest, "%s is preaching" % priest.full_name(), at)


func _on_police(priest: Resident, at: Vector3) -> void:
	var ring: MeshInstance3D = _rings.get(priest)
	if ring:
		ring.material_override = _raid
	_alert(priest, "POLICE are arresting %s!" % priest.full_name(), at)


func _on_ended(priest: Resident) -> void:
	var ring: MeshInstance3D = _rings.get(priest)
	if ring:
		ring.queue_free()
	_rings.erase(priest)
	var button: Button = _buttons.get(priest)
	if button:
		button.queue_free()
	_buttons.erase(priest)


## One button per priest: a later alert (the raid) replaces the earlier one.
func _alert(priest: Resident, line: String, at: Vector3) -> void:
	var button: Button = _buttons.get(priest)
	if button == null:
		button = Button.new()
		_box.add_child(button)
		_buttons[priest] = button
	button.text = "%s (click to go there)" % line
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection.callable)
	button.pressed.connect(camera.fly_to.bind(at, true))


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	return mat
