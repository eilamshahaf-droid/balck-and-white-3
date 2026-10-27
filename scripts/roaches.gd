extends Node3D
## The roach miracle: a swarm pours out of a building's walls and over the
## pavement. Its residents run out and nobody moves back in (miracles.gd asks
## Population to empty it, and the building is abandoned).

const M: MiracleSettings = preload("res://data/miracles.tres")
const DivineSign := preload("res://scripts/divine_sign.gd")
const Sfx := preload("res://scripts/sfx.gd")

static var _mesh: BoxMesh

var _time_left := 0.0
var _walls: CPUParticles3D
var _street: CPUParticles3D


## Swarm over `building`; `size` scales the swarm, `length` how long it lasts.
func infest(building: Node3D, size := 1.0, length := 1.0) -> void:
	var box := DivineSign.building_size(building)
	global_position = building.global_position
	_time_left = M.roach_time * length
	if _mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.14, 0.07)
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.35, 0.12, 0.55)
		_mesh.material = mat
	var count := roundi(M.roach_count * size)
	# Up and down the facades...
	_walls = _swarm(count, Vector3(box.x / 2.0 + 0.2, box.y / 2.0, box.z / 2.0 + 0.2), Vector3.UP, 0.0)
	# ...and out across the pavement around the foot of the building.
	_street = _swarm(count >> 1, Vector3(box.x / 2.0 + 3.0, 0.1, box.z / 2.0 + 3.0), Vector3.ZERO, -box.y / 2.0 + 0.3)
	_street.spread = 180.0
	Sfx.play(get_tree(), global_position, &"paper", 1.0)


## Where witnesses look: the foot of the building.
func aim_point() -> Vector3:
	return _street.global_position if _street else global_position


func _swarm(count: int, extents: Vector3, direction: Vector3, y: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh
	p.amount = maxi(count, 8)
	p.lifetime = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = direction
	p.spread = 60.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.particle_flag_align_y = true
	p.position.y = y
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_walls.emitting = _time_left > 0.0
	_street.emitting = _time_left > 0.0
	if _time_left < -3.0:
		queue_free()
