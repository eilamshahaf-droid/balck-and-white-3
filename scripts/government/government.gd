extends Node
## City Hall (design doc: "הממשלה כאויב", and "המשטרה והעירייה: לא רנדומלי").
## It watches the building code, quietly: floors past what the code allows,
## luxury piled on top, a fight club. The player never sees the rule, only
## that City Hall turns up when a building is pushed too far. Then it sends a
## building inspector to the worst offender (never a preserved one). He posts a
## demolition notice, and when it runs out a bulldozer comes (bulldozer.gd
## says what stops it). Picking the inspector up before he gets there also
## works, for a while.

enum Step { QUIET, INSPECTING, NOTICE, BULLDOZER }

const G = preload("res://data/government.tres")
const CitizenScript = preload("res://scripts/citizen.gd")
const BulldozerScript = preload("res://scripts/government/bulldozer.gd")
const NoticeScript = preload("res://scripts/government/demolition_notice.gd")
const DivineSign = preload("res://scripts/divine_sign.gd")

const OFF_KERB := 3.5          # where people stand in front of a building: sidewalk + a step
const NOTICE_LIFT := 6.0       # above the roof, so other towers don't hide it from the sky
const INSPECTOR_LINE := "Department of Buildings. Routine inspection."
const INSPECTOR_COLOR := Color(0.85, 0.9, 1.0)

var _step := Step.QUIET
var _suspicion := 0.0
var _total_violations := 0.0
var _flagged := {}             # building -> true while its breach has been reported to Heat
var _cooldown := 0.0
var _target: Node3D
var _front := Vector3.ZERO     # the road in front of the target
var _inspector: CitizenScript
var _inspected := false
var _leaving: Array[CharacterBody3D] = []   # inspectors walking off, freed once the hand lets go
var _notice: NoticeScript
var _notice_left := 0.0
var _bulldozer: BulldozerScript
var _news := ""
var _news_left := 0.0
var _yellow := _mat(Color(0.95, 0.72, 0.1))
var _dark := _mat(Color(0.2, 0.2, 0.22))
var _rubble := _mat(Color(0.5, 0.47, 0.42))

@onready var city: Node3D = get_parent()
@onready var districts: Districts = get_node("../Districts")
@onready var decrees: Decrees = get_node("../Decrees")
@onready var heat: Heat = get_node("../Heat")


func _ready() -> void:
	districts.district_controlled.connect(_on_district_controlled)


## For the HUD: what City Hall is up to right now.
func status_text() -> String:
	if _news_left > 0.0:
		return _news
	match _step:
		Step.INSPECTING:
			return "an inspector is on his way"
		Step.NOTICE:
			return "demolition notice, %d s left" % ceili(_notice_left)
		Step.BULLDOZER:
			return _bulldozer.status_text()
	return "watching" if _suspicion >= G.suspicion_visit / 2.0 else "quiet"


func _physics_process(delta: float) -> void:
	_news_left -= delta
	_cooldown -= delta
	_dismiss_inspectors()
	if _step != Step.QUIET and not is_instance_valid(_target):
		_end_visit("", G.retry_cooldown)
		return
	if _step == Step.NOTICE and not _demolishable(_target):
		_end_visit("the building was declared a landmark", G.retry_cooldown)
		return
	match _step:
		Step.QUIET:
			_maybe_visit()
		Step.INSPECTING:
			_inspect()
		Step.NOTICE:
			_notice_left -= delta
			_notice.show_seconds(_notice_left)
			if _notice_left <= 0.0:
				_send_bulldozer()


func _maybe_visit() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = G.check_interval
	_target = _pick_target()
	if _target == null:
		_suspicion = 0.0
		return
	_suspicion = maxf(_suspicion + (G.suspicion_rate * _total_violations - G.suspicion_decay) * G.check_interval, 0.0)
	if _suspicion < G.suspicion_visit:
		return
	_suspicion = 0.0
	var size := DivineSign.building_size(_target)
	var p := _target.global_position
	_front = Vector3(p.x, 0.0, p.z + size.z / 2.0 + OFF_KERB)
	_send_inspector()


## The building of yours that breaks the code worst (never a preserved one),
## or null when none breaks it. Also adds up every violation.
func _pick_target() -> Node3D:
	var worst: Node3D = null
	var worst_score := 0.0
	_total_violations = 0.0
	for b in districts.converted_buildings():
		if not _demolishable(b):
			continue
		var score := _violations(b)
		_total_violations += score
		if score > 0.0 and not _flagged.has(b):
			_flagged[b] = true
			heat.raise(b, Heat.Reason.CODE_BREACH, score)
		elif score == 0.0:
			_flagged.erase(b)
		if score > worst_score:
			worst_score = score
			worst = b
	return worst


func _violations(building: Node3D) -> float:
	var past: int = maxi(building.get_meta(&"decree_floors", 0) - G.code_floor_levels, 0)
	var score := G.level_violation * past
	if past > 0 and building.get_meta(&"decree_luxury", false):
		score += G.luxury_violation
	if decrees.use_of(building) == Campaigns.S.training_use:
		score += G.training_violation
	return score


## A Preserve decree makes a building a landmark, and a district whose core
## building is yours is left alone: City Hall can't touch either.
func _demolishable(building: Node3D) -> bool:
	return not building.is_in_group(Decrees.PRESERVED) \
			and not districts.leaves_alone(districts.district_at(building.global_position))


## He walks down the avenue to the corner, then to the door.
func _send_inspector() -> void:
	var corner: Vector2i = city.nearest_grid(_front)
	var start := Vector2i(corner.x, corner.y + G.inspector_walk_blocks)
	if start.y >= city.STREETS:
		start.y = corner.y - G.inspector_walk_blocks
	var c: CitizenScript = CitizenScript.new()
	c.city = city
	c.grid = start
	c.collision_layer = city.LAYER_CITIZENS
	c.collision_mask = city.LAYER_WORLD
	city.add_child(c)
	c.belief = -0.9
	c.skepticism = 1.0
	c.add_child(_hard_hat())
	c.send_on_errand(_front, _target.global_position, G.inspection_time, INSPECTOR_LINE, INSPECTOR_COLOR)
	_inspector = c
	_inspected = false
	_step = Step.INSPECTING


func _inspect() -> void:
	if not is_instance_valid(_inspector):
		_end_visit("", G.retry_cooldown)
		return
	if _inspector.errand_arrived:
		_inspected = true
	if _inspector.on_errand:
		return
	# The errand is over: either he finished, or the hand picked him up on the way.
	_leaving.append(_inspector)
	_inspector = null
	if not _inspected:
		_end_visit("the inspector filed a complaint about the weather", G.retry_cooldown)
		return
	_notice = NoticeScript.new()
	_target.add_child(_notice)
	var roof := _target.global_position.y + DivineSign.building_size(_target).y / 2.0
	_notice.global_position = Vector3(_target.global_position.x, roof + NOTICE_LIFT, _target.global_position.z)
	_notice_left = G.notice_time
	_notice.show_seconds(_notice_left)
	_step = Step.NOTICE


func _send_bulldozer() -> void:
	if is_instance_valid(_bulldozer) and not _bulldozer.held:
		_bulldozer.queue_free()  # last visit's, left lying around
	var corner: Vector2i = city.nearest_grid(_front)
	var start := Vector2i(corner.x, clampi(corner.y + G.bulldozer_start_blocks, 0, city.STREETS - 1))
	if start == corner:
		start.y = maxi(corner.y - G.bulldozer_start_blocks, 0)
	var route: Array[Vector3] = [city.intersection(start), city.intersection(corner), _front]
	_bulldozer = BulldozerScript.new()
	_bulldozer.build(route, _target, _yellow, _dark)
	city.add_child(_bulldozer)
	_bulldozer.finished.connect(_on_bulldozer_finished, CONNECT_ONE_SHOT)
	_notice.queue_free()
	_step = Step.BULLDOZER


func _on_bulldozer_finished(demolished: bool) -> void:
	if _step != Step.BULLDOZER:
		return
	if not demolished:
		_end_visit("the demolition was called off", G.retry_cooldown)
		return
	_demolish(_target)
	_end_visit("a building was demolished", G.visit_cooldown)


func _demolish(building: Node3D) -> void:
	var size := DivineSign.building_size(building)
	var rubble := StaticBody3D.new()
	rubble.collision_layer = city.LAYER_WORLD
	rubble.set_meta("surface", &"concrete")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 1.2, size.z)
	shape.shape = box
	rubble.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.material_override = _rubble
	rubble.add_child(mesh)
	city.add_child(rubble)
	var p := building.global_position
	rubble.global_position = Vector3(p.x, 0.8, p.z)
	districts.remove_building(building)
	building.queue_free()


func _end_visit(news: String, cooldown: float) -> void:
	if is_instance_valid(_notice):
		_notice.queue_free()
	if is_instance_valid(_inspector):
		_inspector.end_errand()
		_leaving.append(_inspector)
	_inspector = null
	_target = null
	_step = Step.QUIET
	_cooldown = cooldown
	if news != "":
		_news = news
		_news_left = G.news_time


## Inspectors go back to the office once they are on their feet and nobody holds them.
func _dismiss_inspectors() -> void:
	for i in range(_leaving.size() - 1, -1, -1):
		var c := _leaving[i]
		if not is_instance_valid(c):
			_leaving.remove_at(i)
		elif c.can_answer():
			_leaving.remove_at(i)
			c.queue_free()


## Taking a district is exactly what City Hall notices.
func _on_district_controlled(_district: int) -> void:
	_cooldown = 0.0


func _hard_hat() -> MeshInstance3D:
	var hat := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.28
	cylinder.bottom_radius = 0.42
	cylinder.height = 0.22
	hat.mesh = cylinder
	hat.material_override = _mat(Color(0.97, 0.97, 0.95))
	hat.position.y = 1.9
	return hat


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m
