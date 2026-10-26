extends Node3D
## A building on fire: flames from the windows and roof, smoke, a flickering
## orange light. Rain puts it out; a building that burned stays charred until
## a healing miracle rebuilds it. A fire can also burn on a spot in the street.

const Sfx = preload("res://scripts/sfx.gd")

signal extinguished

## 1 = blazing, 0 = out.
var heat := 1.0
## People in danger from this fire (on the roof, inside). A miracle that puts
## it out has helped them.
var endangered: Array = []
var building: Node3D
## Seconds until the fire burns out by itself (INF: until someone puts it out).
var burn_time := INF

var _flames: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _t := 0.0
var _crackle := 0.0
var _smolder := 10.0      # seconds of smoke after the fire is out
var _window_flames: Array[CPUParticles3D] = []
var _original_materials := {}   # mesh -> its material before it was charred


## Set `building` alight. `size` is its box (width, height, depth).
func ignite(p_building: Node3D, size: Vector3) -> void:
	building = p_building
	position = p_building.position + Vector3.UP * size.y / 2.0
	_build(size, true)


## A fire `width` metres across on the street at `where`.
func ignite_spot(where: Vector3, width: float) -> void:
	position = where
	_build(Vector3(width, 0.0, width), false)
	_light.omni_range = width * 6.0 + 8.0


func _build(size: Vector3, from_windows: bool) -> void:
	add_to_group("fires")

	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.albedo_texture = _soft_dot()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 4.0)
	quad.material = flame_mat
	# Flames over the whole roof...
	_flames = CPUParticles3D.new()
	_flames.mesh = quad
	_flames.amount = 140
	_flames.lifetime = 0.9
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(size.x / 2.0, 0.5, size.z / 2.0)
	_flames.position = Vector3.UP * 0.8
	_flames.direction = Vector3.UP
	_flames.spread = 15.0
	_flames.gravity = Vector3.UP * 4.0
	_flames.initial_velocity_min = 2.0
	_flames.initial_velocity_max = 5.0
	_flames.scale_amount_min = 0.6
	_flames.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.4, 0.95))
	ramp.add_point(0.4, Color(1.0, 0.45, 0.1, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.1, 0.05, 0.0))
	_flames.color_ramp = ramp
	add_child(_flames)
	# ...and out of the top-floor windows on both street sides.
	for side in ([-1.0, 1.0] if from_windows else []):
		var windows := _flames.duplicate() as CPUParticles3D
		windows.amount = 50
		windows.emission_box_extents = Vector3(size.x / 2.0 - 0.5, size.y / 6.0, 0.1)
		windows.position = Vector3(0, -size.y / 6.0, side * (size.z / 2.0 + 0.6))
		windows.initial_velocity_max = 3.0
		add_child(windows)
		_window_flames.append(windows)

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.albedo_texture = _soft_dot()
	var puff := QuadMesh.new()
	puff.size = Vector2(5, 5)
	puff.material = smoke_mat
	_smoke = CPUParticles3D.new()
	_smoke.mesh = puff
	_smoke.amount = 40
	_smoke.lifetime = 5.0
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(size.x / 2.0, 1.0, size.z / 2.0)
	_smoke.direction = Vector3.UP
	_smoke.spread = 20.0
	_smoke.gravity = Vector3(1.5, 3.0, 0.5)
	_smoke.initial_velocity_min = 2.0
	_smoke.initial_velocity_max = 4.0
	_smoke.scale_amount_min = 1.0
	_smoke.scale_amount_max = 3.0
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.15, 0.13, 0.12, 0.6))
	smoke_ramp.set_color(1, Color(0.3, 0.3, 0.32, 0.0))
	_smoke.color_ramp = smoke_ramp
	add_child(_smoke)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = maxf(size.x, size.z) * 2.5 + 20.0
	_light.position = Vector3.UP * 2.0
	add_child(_light)


## A round blob that fades to transparent at the edge, so particles aren't squares.
static func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


## Put out `amount` of the fire's heat (rain does this every frame).
func douse(amount: float) -> void:
	if heat <= 0.0:
		return
	heat = maxf(heat - amount, 0.0)
	if heat == 0.0:
		_flames.emitting = false
		for w in _window_flames:
			w.emitting = false
		_char()
		extinguished.emit()


## Set a burnt-out fire going again (the building stays charred).
func rekindle() -> void:
	heat = 1.0
	_smolder = 10.0
	_flames.emitting = true
	_smoke.emitting = true
	for w in _window_flames:
		w.emitting = true


func is_burning() -> bool:
	return heat > 0.0


func _char() -> void:
	if building == null:
		return
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.18, 0.16, 0.15)
	for mesh in building.find_children("*", "MeshInstance3D", false, false):
		_original_materials[mesh] = mesh.material_override
		mesh.material_override = burnt


## Put the fire out and give the building back its old look.
func restore() -> void:
	douse(heat)
	for mesh in _original_materials:
		if is_instance_valid(mesh):
			mesh.material_override = _original_materials[mesh]
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	if burn_time < INF:
		douse(delta / burn_time)
	# Flames shrink as the fire dies.
	for p in [_flames] + _window_flames:
		p.scale_amount_min = 0.6 * heat
		p.scale_amount_max = 0.3 + 1.3 * heat
	_light.light_energy = heat * (5.0 + sin(_t * 17.0) * 0.8 + sin(_t * 7.3) * 1.0)
	_crackle -= delta
	if heat > 0.0 and _crackle <= 0.0:
		_crackle = randf_range(0.15, 0.5)
		Sfx.play(get_tree(), global_position, &"fire", 0.5 * heat)
	if heat == 0.0:
		_smolder -= delta
		_smoke.emitting = _smolder > 0.0
