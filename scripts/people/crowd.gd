class_name Crowd
extends MultiMeshInstance3D
## Draws every person's body in one MultiMesh: hundreds of people cost one
## draw call instead of one each. A Citizen keeps its logic and collision and
## joins the crowd for its looks; each frame the crowd copies every body's
## pose and colour into one buffer.
##
## Any script may spawn a Citizen (Population, City Hall's inspectors), so
## bodies find the crowd through Crowd.join() instead of being wired by hand.

const FLOATS := 16   # per instance: a 3x4 transform, then a colour

static var _current: Crowd

var _people: Array[Citizen] = []
var _buffer := PackedFloat32Array()


static func join(c: Citizen) -> void:
	if _current:
		_current._add(c)


static func leave(c: Citizen) -> void:
	if _current:
		_current._people.erase(c)


func _ready() -> void:
	_current = self
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = SharedMeshes.capsule(0.35, 1.8)
	material_override = mat
	# Bodies move in their physics step; copy their poses after all of them have.
	process_physics_priority = 100
	# The whole city: one box, so the crowd is never culled while people walk out of it.
	custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 1000, 8000))


func _exit_tree() -> void:
	if _current == self:
		_current = null


func _physics_process(_delta: float) -> void:
	var n := _people.size()
	if n > multimesh.instance_count:
		_grow(n)
	var i := 0
	for c in _people:
		var t := c.body_transform()
		var col := c.body_color()
		_buffer[i] = t.basis.x.x
		_buffer[i + 1] = t.basis.y.x
		_buffer[i + 2] = t.basis.z.x
		_buffer[i + 3] = t.origin.x
		_buffer[i + 4] = t.basis.x.y
		_buffer[i + 5] = t.basis.y.y
		_buffer[i + 6] = t.basis.z.y
		_buffer[i + 7] = t.origin.y
		_buffer[i + 8] = t.basis.x.z
		_buffer[i + 9] = t.basis.y.z
		_buffer[i + 10] = t.basis.z.z
		_buffer[i + 11] = t.origin.z
		_buffer[i + 12] = col.r
		_buffer[i + 13] = col.g
		_buffer[i + 14] = col.b
		_buffer[i + 15] = col.a
		i += FLOATS
	multimesh.visible_instance_count = n
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buffer)


func _add(c: Citizen) -> void:
	_people.append(c)


## Room for at least `n` people; grows in steps so it rarely reallocates.
func _grow(n: int) -> void:
	var capacity := maxi(n, multimesh.instance_count * 2)
	multimesh.instance_count = capacity
	_buffer.resize(capacity * FLOATS)
