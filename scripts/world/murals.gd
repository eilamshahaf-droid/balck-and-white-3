class_name Murals
extends Node3D
## The Vandalist's street art. Set him down by a building and he paints a mural on its
## nearest wall; murals give believers living near them pleasure, and the district
## notices. After each one the neighbourhood answers (painted over, a fine, a camera),
## each answer more likely the more it has been used, and some answers end in his arrest.
## Set down by a landmark he marks it instead (longer, paid, no answer, Landmarks).

## A mural went up on building `index`.
signal painted(index: int)
## The neighbourhood answered the mural on building `index` with answer `answer`.
signal answered(index: int, answer: int)

const A: AwarenessSettings = preload("res://data/awareness.tres")
const L: LandmarkSettings = preload("res://data/landmarks.tres")
const U: UnitSettings = preload("res://data/units.tres")
## Answer order in AwarenessSettings.answer_names: what each one does.
const PAINT_OVER := 0
const FINE := 1
const CAMERA := 2

@export var population: Population
@export var districts: Districts
@export var awareness: Awareness
@export var treasury: Treasury
@export var arrests: PoliceArrests
@export var landmarks: Landmarks

var _murals: Dictionary = {}     # building index -> MeshInstance3D
var _cameras: Array[int] = []    # buildings with a camera
var _painting: Array[Painting] = []
var _weights := PackedFloat32Array()
var _quad: QuadMesh
var _materials: Array[StandardMaterial3D] = []
var _camera_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


class Painting:
	var agent: Resident
	var index := -1
	var face := Vector3.ZERO   # outward normal of the wall
	var left := 0.0
	var mark := false          # marking a landmark rather than a plain mural


func _ready() -> void:
	_rng.seed = 31
	population.agent_set_down.connect(_on_agent_set_down)
	landmarks.changed.connect(_on_landmark_changed)
	for i in A.answer_count():
		_weights.append(A.answer_weight(i))
	_quad = QuadMesh.new()
	_quad.size = A.mural_size
	for i in A.mural_color_count():
		var m := StandardMaterial3D.new()
		m.albedo_color = A.mural_color(i)
		_materials.append(m)
	_camera_material = StandardMaterial3D.new()
	_camera_material.albedo_color = A.camera_color


func _physics_process(delta: float) -> void:
	for p in _painting.duplicate():
		if not population.has_body(p.agent) or arrests.is_arresting(p.agent):
			_painting.erase(p)
			continue
		p.left -= delta
		if p.left <= 0.0:
			_painting.erase(p)
			if p.mark:
				_finish_mark(p.agent, p.index, p.face)
			else:
				paint(p.agent, p.index, p.face)


## Is there a mural on building `index`?
func has_mural(index: int) -> bool:
	return _murals.has(index)


## Put a mural up on building `index` now, on the wall facing `face`, and let the
## neighbourhood answer it.
func paint(agent: Resident, index: int, face: Vector3) -> void:
	if _murals.has(index):
		_murals[index].queue_free()
	_murals[index] = _mural_on(index, face)
	_refresh_pleasure()
	awareness.add(districts.district_of(index), A.mural_awareness)
	painted.emit(index)
	_answer(agent, index, face)


func _on_landmark_changed(index: int, marked: bool) -> void:
	if not marked and _murals.has(index):
		_murals[index].queue_free()
		_murals.erase(index)
		_refresh_pleasure()


func _on_agent_set_down(agent: Resident, building: Node3D) -> void:
	var index := districts.index_of(building)
	if index < 0 or not population.has_body(agent):
		return
	for p in _painting:
		if p.agent == agent:
			_painting.erase(p)
			break
	var p := Painting.new()
	p.agent = agent
	p.index = index
	p.face = _wall_facing(index, agent.body.global_position)
	p.left = A.paint_seconds
	if landmarks.is_landmark(index):
		var top := _wall_point(index, p.face) + Vector3.UP * (A.mural_size.y + 2.0)
		if landmarks.is_marked(index):
			FloatingNote.pop(self, top, "Already marked", L.marked_color)
			return
		var cost := landmarks.mark_cost(index)
		if not treasury.spend_money(cost):
			FloatingNote.pop(self, top, "A mark needs $%d" % roundi(cost), L.sign_color)
			return
		p.mark = true
		p.left = L.mark_minutes * 60.0
	_painting.append(p)
	var spot := _wall_point(index, p.face) + p.face * 1.5
	spot.y = agent.body.global_position.y
	agent.body.send_on_errand(spot, spot - p.face, p.left, A.paint_line,
			U.color(Resident.Rank.AGENT))


## The neighbourhood answers: draw one answer by weight, make it more likely next
## time, carry it out, and maybe arrest the Vandalist.
func _answer(agent: Resident, index: int, face: Vector3) -> void:
	var total := 0.0
	for w in _weights:
		total += w
	var roll := _rng.randf() * total
	var pick := 0
	while pick < _weights.size() - 1 and roll >= _weights[pick]:
		roll -= _weights[pick]
		pick += 1
	_weights[pick] += A.growth(pick)
	var at := _wall_point(index, face) + Vector3.UP * (A.mural_size.y + 2.0)
	FloatingNote.pop(self, at, A.answer_name(pick), Color(0.85, 0.85, 0.95))
	match pick:
		PAINT_OVER:
			_murals[index].queue_free()
			_murals.erase(index)
			_refresh_pleasure()
		FINE:
			treasury.spend_money(minf(A.fine, treasury.money))
		CAMERA:
			_put_camera(index, face)
	answered.emit(index, pick)
	if population.has_body(agent) and _rng.randf() < A.arrest_chance(pick) + camera_bonus(index):
		arrests.arrest(agent)


## The arrest chance a camera within camera_steps borders of building `index` adds.
func camera_bonus(index: int) -> float:
	var near := districts.around(index, A.camera_steps)
	near.append(index)
	for c in _cameras:
		if near.has(c):
			return A.camera_arrest
	return 0.0


## A landmark mark is done: it counts for the core, shows as a mural, and he may be caught.
func _finish_mark(agent: Resident, index: int, face: Vector3) -> void:
	landmarks.mark(index)
	if _murals.has(index):
		_murals[index].queue_free()
	_murals[index] = _mural_on(index, face)
	_refresh_pleasure()
	awareness.add(districts.district_of(index), A.mural_awareness)
	if population.has_body(agent) and _rng.randf() < L.arrest_chance + camera_bonus(index):
		arrests.arrest(agent)


## Pleasure for believers: each mural reaches the homes within mural_steps borders.
func _refresh_pleasure() -> void:
	var bonus: Dictionary = {}
	for index: int in _murals:
		var reach := districts.around(index, A.mural_steps)
		reach.append(index)
		for j in reach:
			var b := districts.buildings[j]
			bonus[b] = minf(bonus.get(b, 0.0) + A.mural_pleasure, 1.0)
	population.pleasure_bonus = bonus


func _mural_on(index: int, face: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _quad
	mesh.material_override = _materials[_rng.randi() % _materials.size()]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	var at := _wall_point(index, face) + face * 0.8 + Vector3.UP * (A.mural_size.y / 2.0 + 1.0)
	mesh.global_transform = Transform3D(Basis.looking_at(-face), at)
	return mesh


func _put_camera(index: int, face: Vector3) -> void:
	_cameras.append(index)
	var cam := MeshInstance3D.new()
	cam.mesh = SharedMeshes.box(Vector3(0.5, 0.4, 0.9))
	cam.material_override = _camera_material
	add_child(cam)
	var at := _wall_point(index, face) + face * 0.5 + Vector3.UP * (A.mural_size.y + 2.0)
	cam.global_transform = Transform3D(Basis.looking_at(face), at)


## The outward normal of building `index`'s wall nearest `p` (one of the four sides).
func _wall_facing(index: int, p: Vector3) -> Vector3:
	var b := districts.buildings[index]
	var size := districts.sizes[index]
	var d := p - b.global_position
	if absf(d.x) / maxf(size.x, 0.1) > absf(d.z) / maxf(size.z, 0.1):
		return Vector3(signf(d.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(d.z) if d.z != 0.0 else 1.0)


## The middle of that wall at ground level (a building's origin is its box's centre).
func _wall_point(index: int, face: Vector3) -> Vector3:
	var b := districts.buildings[index]
	var size := districts.sizes[index]
	var c := b.global_position
	return Vector3(c.x + face.x * size.x / 2.0, c.y - size.y / 2.0, c.z + face.z * size.z / 2.0)
