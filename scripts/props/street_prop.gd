class_name StreetProp
extends RigidBody3D
## A thing on the sidewalk the hand can pick up and throw: a trash can, a
## hydrant, a bench. A model with a "squash" blend shape (see PropModel) (the trash bag) also
## gives way: it flattens under whatever lies on it and when it lands hard,
## then slowly puffs back up.

var _settings: CityPropsSettings
var _squash_index := -1
var _mesh: MeshInstance3D
var _load := 0        # bodies resting on top
var _impact := 0.0    # extra squash from the last hard landing, fading out
var _shown := 0.0


func build(kind: PropKind, settings: CityPropsSettings, layer: int, mask: int) -> void:
	_settings = settings
	add_to_group("god_grabbable")
	collision_layer = layer
	collision_mask = mask
	mass = kind.mass
	set_meta("surface", kind.surface)
	var model := PropModel.of(kind)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = model.size
	shape.shape = box
	add_child(shape)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = model.mesh
	_mesh.material_override = model.material
	# The body's origin is the middle of its box; the model stands on its base.
	_mesh.transform = Transform3D(Basis.IDENTITY, Vector3.DOWN * model.size.y / 2.0) * model.offset
	_mesh.visibility_range_end = settings.visible_distance
	add_child(_mesh)
	_squash_index = model.squash_shape
	if _squash_index >= 0:
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _ready() -> void:
	# Nothing to animate until something lands on it.
	set_process(false)


## True for models that give way (they have a "squash" blend shape).
func is_squashy() -> bool:
	return _squash_index >= 0


## How flat it looks right now, 0 (as made) to 1 (fully squashed).
func squash_amount() -> float:
	return _shown


func _process(delta: float) -> void:
	_impact = maxf(0.0, _impact - _settings.squash_recover * delta)
	var target := clampf(_load * _settings.squash_per_load + _impact, 0.0, 1.0)
	_shown = move_toward(_shown, target, _settings.squash_follow * delta)
	_mesh.set_blend_shape_value(_squash_index, _shown)
	if _impact == 0.0 and is_equal_approx(_shown, target):
		set_process(false)


func _on_body_entered(body: Node) -> void:
	var other := body as Node3D
	if other.global_position.y > global_position.y:
		_load += 1
	var speed := linear_velocity.length()
	if body is RigidBody3D:
		speed = maxf(speed, (body as RigidBody3D).linear_velocity.length())
	_impact = maxf(_impact, speed * _settings.squash_per_speed)
	set_process(true)


func _on_body_exited(body: Node) -> void:
	var other := body as Node3D
	# Bodies leaving the tree (freed, or the game closing) say goodbye too.
	if not is_inside_tree() or not other.is_inside_tree():
		return
	if other.global_position.y > global_position.y:
		_load = maxi(0, _load - 1)
	set_process(true)
