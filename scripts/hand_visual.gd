extends Node3D
## The god's hand: a white cloth glove whose arm crumbles away into holes.
## The model is the WebXR generic hand (MIT), made into a glove in Blender with
## sculpted seams and creases baked into its maps (see assets/models/god_hand).
## Gameplay only calls set_pose(), set_power() and strain(); each pose curls the
## glove's finger bones.

enum Pose { OPEN, POINT, GRAB, TAP }

const MODEL := preload("res://assets/models/god_hand/god_hand.glb")
const AO_TEX := preload("res://assets/models/god_hand/glove_ao.png")
const NORMAL_TEX := preload("res://assets/models/god_hand/glove_normal.png")
const HOLES_TEX := preload("res://assets/models/god_hand/arm_holes.png")

const FINGERS := ["index-finger", "middle-finger", "ring-finger", "pinky-finger"]
const PHALANGES := ["phalanx-proximal", "phalanx-intermediate", "phalanx-distal"]
const THUMB := ["thumb-metacarpal", "thumb-phalanx-proximal", "thumb-phalanx-distal"]
const SPREAD := [0.2, 0.04, -0.1, -0.24]   # how far each finger fans out in a fully open hand
## Per pose: curl of index, middle, ring, pinky (3 joints each), thumb flex (3 joints),
## how far the thumb swings out from under the palm, and how far the fingers fan out.
const POSES := {
	Pose.OPEN: [0.02, 0.04, 0.03, 0.02, 0.04, 0.03, 0.03, 0.05, 0.04, 0.04, 0.06, 0.05,
		0.0, 0.05, 0.05, 0.75, 1.0],
	Pose.POINT: [0.0, 0.02, 0.0, 1.35, 1.3, 0.55, 1.4, 1.3, 0.55, 1.45, 1.25, 0.55,
		0.35, 0.4, 0.3, 0.25, 0.2],
	Pose.GRAB: [0.75, 0.85, 0.55, 0.8, 0.9, 0.55, 0.8, 0.9, 0.55, 0.85, 0.9, 0.55,
		0.3, 0.35, 0.3, 0.45, 0.55],
	Pose.TAP: [0.55, 0.4, 0.25, 1.35, 1.3, 0.55, 1.4, 1.3, 0.55, 1.45, 1.25, 0.55,
		0.35, 0.4, 0.3, 0.25, 0.2],
}
const CURL_SPEED := 14.0
## Where the hand sits relative to its hotspot, so the index fingertip is at the origin.
const FINGERTIP_OFFSET := Vector3(0.4, 0.085, 1.23)
## Wrist to fingertip, in the hand's own units.
const LENGTH := 1.8
const WEAK_GLOVE := Color(0.74, 0.73, 0.77)    # far from your believers: dull and grey
const STRONG_GLOVE := Color(1.0, 0.98, 0.94)   # among them: bright, with a warm glow
const GLOW := Color(1.0, 0.85, 0.6)

var pose := Pose.OPEN
var _skeleton: Skeleton3D
var _bones := PackedInt32Array()        # 12 finger joints, then 3 thumb joints
var _rest: Array[Quaternion] = []
var _lift_axis := Vector3.UP            # the thumb's swing axis, in the thumb's own space
var _cur := PackedFloat32Array()
var _settled := false
var _glove := StandardMaterial3D.new()
var _arm := StandardMaterial3D.new()
var _strain := 0.0


func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_build_materials()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _arm if mesh.name == &"Forearm" else _glove

	for f: String in FINGERS:
		for p: String in PHALANGES:
			_bones.append(_skeleton.find_bone(f + "-" + p))
	for t: String in THUMB:
		_bones.append(_skeleton.find_bone(t))
	for i in _bones:
		_rest.append(_skeleton.get_bone_rest(i).basis.get_rotation_quaternion())

	# Turn the model so the fingers point forward (-Z) and the back of the glove up,
	# a wrist-to-fingertip LENGTH long, with the middle of the palm at the origin.
	var wrist := _rest_pos("wrist")
	var reach := _rest_pos("middle-finger-tip") - wrist
	var back := _skeleton.get_bone_global_rest(_skeleton.find_bone("middle-finger-phalanx-proximal")).basis.z
	var fwd := reach.normalized()
	back = (back - fwd * back.dot(fwd)).normalized()
	var turn := Basis(back.cross(-fwd), back, -fwd).inverse()
	var k := LENGTH / reach.length()
	model.basis = turn.scaled(Vector3.ONE * k)
	model.position = -(model.basis * (wrist + _rest_pos("middle-finger-phalanx-proximal")) * 0.5)
	var thumb_rest := _skeleton.get_bone_global_rest(_bones[12]).basis
	_lift_axis = (thumb_rest.inverse() * fwd).normalized()

	_cur = PackedFloat32Array(POSES[Pose.OPEN])
	_apply()
	set_power(0.3)


func set_pose(p: Pose) -> void:
	if p != pose:
		_settled = false
	pose = p


## 0 = no believers near, 1 = deep in your own neighbourhood.
func set_power(t: float) -> void:
	var power := clampf(t, 0.0, 1.0)
	_glove.albedo_color = WEAK_GLOVE.lerp(STRONG_GLOVE, power)
	_arm.albedo_color = _glove.albedo_color
	# a faint warm glow even when weak, so the glove never turns icy blue in the shade
	_glove.emission_energy_multiplier = 0.06 + power * power * 0.25


## The hand tried something too heavy for it here: it trembles a moment.
func strain() -> void:
	_strain = 0.5


func _process(delta: float) -> void:
	if not _settled:
		var goal: Array = POSES[pose]
		var w := 1.0 - exp(-CURL_SPEED * delta)
		var moved := 0.0
		for i in _cur.size():
			var v := lerpf(_cur[i], goal[i], w)
			moved = maxf(moved, absf(v - _cur[i]))
			_cur[i] = v
		_settled = moved < 0.0005
		_apply()
	_strain = maxf(_strain - delta, 0.0)
	rotation.z = sin(_strain * 90.0) * 0.12 * _strain / 0.5


## Curl every finger joint around its own side axis, fan the knuckles out around
## the back of the hand, and swing the thumb out before it bends.
func _apply() -> void:
	for f in 4:
		for j in 3:
			var n := f * 3 + j
			var q := _rest[n]
			if j == 0:
				q *= Quaternion(Vector3.BACK, SPREAD[f] * _cur[16])
			q *= Quaternion(Vector3.RIGHT, -_cur[n])
			_skeleton.set_bone_pose_rotation(_bones[n], q)
	for j in 3:
		var q := _rest[12 + j]
		if j == 0:
			q *= Quaternion(_lift_axis, _cur[15])
		q *= Quaternion(Vector3.BACK, -_cur[12 + j])
		_skeleton.set_bone_pose_rotation(_bones[12 + j], q)


func _rest_pos(bone: String) -> Vector3:
	return _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).origin


func _build_materials() -> void:
	# Thick white cotton: the baked shade between the fingers in the colour, the
	# seams and creases in the normal map, and a soft sheen on the edges.
	_glove.albedo_texture = AO_TEX
	_glove.normal_enabled = true
	_glove.normal_texture = NORMAL_TEX
	_glove.roughness = 0.9
	_glove.rim_enabled = true
	_glove.rim = 0.35
	_glove.rim_tint = 0.6
	_glove.emission_enabled = true
	_glove.emission = GLOW
	# The glove runs on up the arm and crumbles away; through the holes you see its inside.
	_arm.albedo_texture = HOLES_TEX
	_arm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_arm.alpha_scissor_threshold = 0.5
	_arm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arm.roughness = 0.9
