extends Node3D
## A divine sign on a building, from the design doc: a beam of light means
## blessed, a storm cloud means cursed, a ring of light means protected.
## Believers answer it (sign_followers.gd), each by the sign and the god's path.

const M = preload("res://data/miracles.tres")

const META := &"divine_sign"
const KINDS: Array[StringName] = [&"blessed", &"cursed", &"protected"]

var kind: StringName
var _size := Vector3.ONE
var _t := randf() * 10.0
var _beam_mat: StandardMaterial3D
var _ring: Node3D
var _flash: OmniLight3D
var _next_flash := 0.0


## The signs' slices of the building wheel, in order.
static func wheel_items() -> Array[Dictionary]:
	return [
		{"id": &"blessed", "label": "Blessed", "note": "beam of light", "color": Color(1.0, 0.88, 0.45)},
		{"id": &"cursed", "label": "Cursed", "note": "storm cloud", "color": Color(0.55, 0.5, 0.7)},
		{"id": &"protected", "label": "Protected", "note": "ring of light", "color": Color(0.55, 0.95, 1.0)},
	]


## Give `building` the sign `p_kind`, replacing any it had. &"clear" removes it.
static func mark(building: Node3D, p_kind: StringName) -> void:
	if building.has_meta(META):
		var old: Node = building.get_meta(META)
		if is_instance_valid(old):
			old.queue_free()
		building.remove_meta(META)
	if not p_kind in KINDS:
		return
	var script: GDScript = load("res://scripts/divine_sign.gd")
	var sign: Node3D = script.new()
	sign.kind = p_kind
	sign._size = building_size(building)
	building.add_child(sign)
	building.set_meta(META, sign)


## A building's box (width, height, depth), from its collision shape.
static func building_size(building: Node3D) -> Vector3:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape.size
	return Vector3.ONE * 10.0


func _ready() -> void:
	add_to_group("divine_signs")
	var roof := _size.y / 2.0
	match kind:
		&"blessed": _build_beam(roof)
		&"cursed": _build_cloud(roof)
		&"protected": _build_ring(roof)


func _build_beam(roof: float) -> void:
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(1.0, 0.78, 0.3, 0.45)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = minf(_size.x, _size.z) * 0.3
	cylinder.bottom_radius = cylinder.top_radius
	cylinder.height = M.beam_height
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	_add_mesh(cylinder, _beam_mat, Vector3.UP * (roof + M.beam_height / 2.0))
	# A bright core, so the beam reads against a pale sky too.
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.9, 0.55)
	var core := cylinder.duplicate() as CylinderMesh
	core.top_radius = cylinder.top_radius * 0.3
	core.bottom_radius = core.top_radius
	_add_mesh(core, core_mat, Vector3.UP * (roof + M.beam_height / 2.0))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.omni_range = maxf(_size.x, _size.z) * 1.5
	glow.light_energy = 2.0
	glow.position = Vector3.UP * (roof + 2.0)
	add_child(glow)


func _build_cloud(roof: float) -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.34, 0.34, 0.4)
	var spread := maxf(_size.x, _size.z) * 0.45
	for n in 8:
		var puff := SphereMesh.new()
		var r := randf_range(2.0, 3.5)
		puff.radius = r
		puff.height = r * 1.5
		_add_mesh(puff, grey, Vector3(randf_range(-spread, spread), roof + 9.0 + randf_range(-0.6, 0.8), randf_range(-spread, spread) * 0.6))
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.75, 0.8, 1.0)
	_flash.omni_range = spread * 3.0 + 10.0
	_flash.light_energy = 0.0
	_flash.position = Vector3.UP * (roof + 7.0)
	add_child(_flash)
	_next_flash = randf_range(0.5, M.cloud_flash_interval)


func _build_ring(roof: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.85, 1.0)
	var r := Vector2(_size.x, _size.z).length() * 0.5 + 2.0
	var torus := TorusMesh.new()
	torus.inner_radius = r - 1.0
	torus.outer_radius = r
	torus.rings = 64
	_ring = _add_mesh(torus, mat, Vector3.UP * (roof + 3.0))
	_ring.rotation.x = 0.12  # tilted a little, so its spin shows


func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = pos
	add_child(node)
	return node


func _process(delta: float) -> void:
	_t += delta
	match kind:
		&"blessed":
			_beam_mat.albedo_color.a = 0.4 + 0.1 * sin(_t * 2.0)
		&"cursed":
			_next_flash -= delta
			if _next_flash <= 0.0:
				_next_flash = randf_range(0.5, 2.0) * M.cloud_flash_interval
				_flash.light_energy = 6.0
			_flash.light_energy = maxf(_flash.light_energy - delta * 30.0, 0.0)
		&"protected":
			_ring.rotation.y += M.ring_spin * delta
			_ring.position.y = _size.y / 2.0 + 3.0 + sin(_t * 1.5) * 0.4
