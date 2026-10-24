extends Node3D
## Placeholder look of the god's hand: a palm and five fingers made of boxes.
## Gameplay only calls set_pose(), set_power() and strain(), so a real modelled
## and animated hand can replace this script later without touching the hand logic.

enum Pose { OPEN, POINT, GRAB, TAP }

const POSE_CURL := {
	# index, middle, ring, pinky, thumb (radians of curl)
	Pose.OPEN: [0.15, 0.15, 0.15, 0.15, 0.2],
	Pose.POINT: [0.0, 1.5, 1.5, 1.5, 0.9],
	Pose.GRAB: [1.1, 1.1, 1.1, 1.1, 1.0],
	Pose.TAP: [1.7, 1.7, 1.7, 1.7, 1.3],
}
const CURL_SPEED := 14.0
## Where the hand sits relative to its hotspot, so the index fingertip is at the origin.
const FINGERTIP_OFFSET := Vector3(-0.36, 0.1, 1.25)
const WEAK_SKIN := Color(0.62, 0.6, 0.62)      # far from your believers: pale and grey
const STRONG_SKIN := Color(0.95, 0.68, 0.4)    # among them: warm, with a glow

var pose := Pose.OPEN
var _fingers: Array[Node3D] = []
var _curl := [0.15, 0.15, 0.15, 0.15, 0.2]
var _skin := StandardMaterial3D.new()
var _power := 0.0
var _strain := 0.0


func _ready() -> void:
	var skin := _skin
	skin.roughness = 0.6
	skin.emission_enabled = true
	set_power(0.3)

	_box(Vector3(1.0, 0.28, 1.0), Vector3.ZERO, self, skin)
	# Fingers point forward (-Z); the palm faces down.
	var xs := [0.36, 0.12, -0.12, -0.36]
	var lengths := [0.75, 0.82, 0.75, 0.6]
	for i in 4:
		var knuckle := Node3D.new()
		knuckle.position = Vector3(xs[i], 0, -0.5)
		add_child(knuckle)
		_box(Vector3(0.2, 0.22, lengths[i]), Vector3(0, 0, -lengths[i] / 2.0), knuckle, skin)
		_fingers.append(knuckle)
	var thumb := Node3D.new()
	thumb.position = Vector3(0.55, -0.02, 0.1)
	thumb.rotation.y = deg_to_rad(-40)
	add_child(thumb)
	_box(Vector3(0.22, 0.22, 0.6), Vector3(0, 0, -0.3), thumb, skin)
	_fingers.append(thumb)


func set_pose(p: Pose) -> void:
	pose = p


## 0 = no believers near, 1 = deep in your own neighbourhood.
func set_power(t: float) -> void:
	_power = clampf(t, 0.0, 1.0)
	_skin.albedo_color = WEAK_SKIN.lerp(STRONG_SKIN, _power)
	_skin.emission = STRONG_SKIN * 0.6
	_skin.emission_energy_multiplier = _power * _power * 0.5


## The hand tried something too heavy for it here: it trembles a moment.
func strain() -> void:
	_strain = 0.5


func _process(delta: float) -> void:
	var goal: Array = POSE_CURL[pose]
	var w := 1.0 - exp(-CURL_SPEED * delta)
	for i in _fingers.size():
		_curl[i] = lerpf(_curl[i], goal[i], w)
		_fingers[i].rotation.x = -_curl[i]
	_strain = maxf(_strain - delta, 0.0)
	rotation.z = sin(_strain * 90.0) * 0.12 * _strain / 0.5


func _box(size: Vector3, pos: Vector3, parent: Node3D, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = mat
	parent.add_child(mesh)
