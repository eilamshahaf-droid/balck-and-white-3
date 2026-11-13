class_name Inspector
extends RigidBody3D
## One City Hall inspector: he walks the streets from a key building to the door he was
## sent to. The hand can lift him and set him down (or throw him) somewhere else; he
## lies there a moment, gets up and starts walking again. Inspectors decides what
## happens when he arrives.

enum State { WALKING, HELD, FLYING }

const I: InspectorSettings = preload("res://data/inspectors.tres")
const BODY := Vector3(0.6, 1.0, 0.4)
const HEAD := Vector3(0.38, 0.38, 0.38)
const HAT := Vector3(0.5, 0.12, 0.5)
const HEIGHT := 1.8
const REST_SPEED := 0.4
const LOST_BELOW := -30.0

## The building he is after, and whether he audits it (a building of yours) or checks
## the papers of a Rep at its door.
var building: Node3D
var audit := false
var arrived := false
## Seconds since he left his office.
var age := 0.0
## Fell off the world.
var lost := false

var _state := State.WALKING
var _city: City
var _goal := Vector3.ZERO
var _route: Array[Vector3] = []
var _rest := 0.0


func build(coat: Material, skin: Material) -> void:
	add_to_group("god_grabbable")
	set_meta("surface", &"flesh")
	mass = I.mass
	collision_layer = 4
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BODY.x, HEIGHT, BODY.z)
	shape.shape = box
	shape.position.y = HEIGHT / 2.0
	add_child(shape)
	_part(BODY, Vector3(0.0, 0.5 + BODY.y / 2.0, 0.0), coat)
	_part(HEAD, Vector3(0.0, 0.5 + BODY.y + HEAD.y / 2.0, 0.0), skin)
	_part(HAT, Vector3(0.0, 0.5 + BODY.y + HEAD.y + HAT.y / 2.0, 0.0), coat)
	_part(Vector3(BODY.x * 0.8, 0.5, BODY.z), Vector3(0.0, 0.25, 0.0), coat)
	var alert := Label3D.new()
	alert.text = I.alert_text
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.no_depth_test = true
	# The same size on screen from any height, so he is never lost in the streets.
	alert.fixed_size = true
	alert.font_size = I.alert_font_size
	alert.pixel_size = I.alert_pixel_size
	alert.modulate = I.alert_color
	alert.outline_size = 12
	alert.outline_modulate = Color(0, 0, 0, 0.8)
	alert.position.y = HEIGHT + 1.2
	add_child(alert)


## Walk along the streets of `city` to `goal`, from wherever he stands now.
func head_for(city: City, goal: Vector3) -> void:
	_city = city
	_goal = goal
	_route.clear()
	for n in city.route(city.nearest_node(global_position), city.nearest_node(goal)):
		_route.append(city.node_position(n))
	_route.append(Vector3(goal.x, 0.0, goal.z))
	arrived = false
	_state = State.WALKING


func _physics_process(delta: float) -> void:
	age += delta
	match _state:
		State.WALKING:
			_walk(delta)
		State.FLYING:
			_fly(delta)


func on_grabbed() -> void:
	_state = State.HELD
	arrived = false
	freeze = false


func on_released(_throw_velocity: Vector3) -> void:
	_state = State.FLYING
	_rest = 0.0


## Where the hand should aim to pick him.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * (HEIGHT / 2.0)


func _walk(delta: float) -> void:
	if _route.is_empty():
		arrived = true
		return
	var to_point := _route[0] - global_position
	to_point.y = 0.0
	var reach := I.arrive_radius if _route.size() == 1 else I.speed * delta + 0.5
	if to_point.length() <= reach:
		_route.pop_front()
		return
	var dir := to_point.normalized()
	rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)
	global_position = Vector3(global_position.x + dir.x * I.speed * delta, 0.0,
			global_position.z + dir.z * I.speed * delta)


## Thrown or dropped: once he has come to rest he lies there a moment, then gets up.
func _fly(delta: float) -> void:
	if global_position.y < LOST_BELOW:
		lost = true
		return
	if linear_velocity.length() > REST_SPEED:
		_rest = 0.0
		return
	_rest += delta
	if _rest < I.stun_seconds:
		return
	freeze = true
	global_position.y = 0.0
	head_for(_city, _goal)


func _part(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SharedMeshes.box(Vector3.ONE)
	mesh.material_override = material
	mesh.scale = size
	mesh.position = at
	add_child(mesh)
