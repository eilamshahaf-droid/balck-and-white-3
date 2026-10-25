extends Node
## The game's art style: a dollhouse painted in watercolour.
## Runs as the autoload "ArtStyle". It gives every ordinary lit material in the
## world the soft cel shader (shaders/toon.gdshader) and lays the watercolour
## paper pass (shaders/watercolor_paper.gdshader) over the screen.
##
## Gameplay code keeps creating plain StandardMaterial3D and changing its colour;
## this node swaps in a matching toon material and keeps the colour in sync, so
## the look stays separate from the logic. Unshaded, transparent, billboard and
## glowing materials (the hand's shadow and ring, fire, rain, phone screens) and
## the whole god's hand are left alone: they belong to the god layer.
## V toggles the style to compare with the plain look.

const S: ArtStyleSettings = preload("res://data/art_style.tres")
const TOON := preload("res://shaders/toon.gdshader")
const GHOST := preload("res://shaders/toon_ghost.gdshader")
const PAPER := preload("res://shaders/watercolor_paper.gdshader")

var enabled := true

var _wash: NoiseTexture2D
var _paper_noise: NoiseTexture2D
var _paper_mat := ShaderMaterial.new()
var _layer := CanvasLayer.new()
var _toon := {}       # StandardMaterial3D -> its toon ShaderMaterial
var _colors := {}     # StandardMaterial3D -> albedo last copied into the toon material
var _meshes := []     # every MeshInstance3D we look after
var _pending := []    # meshes that entered the tree since the last frame
var _shot_path := ""
var _shot_frames := 120


func _ready() -> void:
	process_priority = 1000  # after gameplay scripts have swapped materials this frame
	enabled = S.enabled
	_wash = _noise_texture(256, 0.012, 4, 11)
	_paper_noise = _noise_texture(512, 0.02, 6, 23)

	_paper_mat.shader = PAPER
	_push_paper_params()
	_layer.layer = 0  # above the 3D world, below the HUD (layer 1)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _paper_mat
	_layer.add_child(rect)
	add_child(_layer)
	_layer.visible = enabled

	get_tree().node_added.connect(_on_node_added)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-frames="):
			_shot_frames = int(arg.trim_prefix("--shot-frames="))
		elif arg == "--no-style":
			enabled = false
			_layer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		enabled = not enabled
		_layer.visible = enabled


func _process(_delta: float) -> void:
	for m in _pending:
		if is_instance_valid(m) and _belongs_to_world(m):
			_meshes.append(m)
	_pending.clear()

	var i := _meshes.size() - 1
	while i >= 0:
		var m = _meshes[i]
		if not is_instance_valid(m):
			_meshes.remove_at(i)
		else:
			_apply(m)
		i -= 1

	# Gameplay changes colours on the plain material (belief tint, burnt
	# buildings); copy them over.
	for src in _toon:
		var c: Color = src.albedo_color
		if c != _colors[src]:
			_colors[src] = c
			_toon[src].set_shader_parameter("albedo", c)

	_update_tilt_shift()

	if _shot_path != "":
		_shot_frames -= 1
		if _shot_frames <= 0:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


## A see-through copy of a building's material, for the camera's fade.
func make_ghost(mat: Material) -> Material:
	if mat is ShaderMaterial and mat.has_meta("toon_source"):
		var g: ShaderMaterial = mat.duplicate()
		g.shader = GHOST
		return g
	var s: BaseMaterial3D = mat.duplicate()
	s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return s


func set_ghost_alpha(mat: Material, a: float) -> void:
	if mat is ShaderMaterial:
		mat.set_shader_parameter("alpha", a)
	elif mat is BaseMaterial3D:
		mat.albedo_color.a = a


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		_pending.append(node)
	elif node is WorldEnvironment:
		_style_environment.call_deferred(node)


func _belongs_to_world(m: Node) -> bool:
	var n := m
	while n != null:
		if n.name == &"GodHand" or n.is_in_group(&"no_toon"):
			return false
		n = n.get_parent()
	return true


func _apply(m: MeshInstance3D) -> void:
	var mat := m.material_override
	if enabled:
		if mat is StandardMaterial3D and _convertible(mat):
			m.material_override = _toon_for(mat)
	elif mat is ShaderMaterial and mat.has_meta("toon_source"):
		m.material_override = mat.get_meta("toon_source")


func _convertible(mat: StandardMaterial3D) -> bool:
	return mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
		and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
		and mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED \
		and not mat.emission_enabled \
		and mat.albedo_texture == null


func _toon_for(src: StandardMaterial3D) -> ShaderMaterial:
	if _toon.has(src):
		return _toon[src]
	var t := ShaderMaterial.new()
	t.shader = TOON
	t.set_meta("toon_source", src)
	_push_toon_params(t)
	t.set_shader_parameter("albedo", src.albedo_color)
	_toon[src] = t
	_colors[src] = src.albedo_color
	return t


func _push_toon_params(t: ShaderMaterial) -> void:
	t.set_shader_parameter("band_low", S.band_low)
	t.set_shader_parameter("band_mid", S.band_mid)
	t.set_shader_parameter("band_high", S.band_high)
	t.set_shader_parameter("step1", S.step1)
	t.set_shader_parameter("step2", S.step2)
	t.set_shader_parameter("softness", S.softness)
	t.set_shader_parameter("shadow_tint", S.shadow_tint)
	t.set_shader_parameter("ambient_amount", S.ambient_amount)
	t.set_shader_parameter("paper_color", S.paper_color)
	t.set_shader_parameter("pigment_lift", S.pigment_lift)
	t.set_shader_parameter("saturation", S.saturation)
	t.set_shader_parameter("wash_tex", _wash)
	t.set_shader_parameter("wash_scale", S.wash_scale)
	t.set_shader_parameter("wash_strength", S.wash_strength)


func _push_paper_params() -> void:
	_paper_mat.set_shader_parameter("paper_noise", _paper_noise)
	_paper_mat.set_shader_parameter("paper_color", S.paper_color)
	_paper_mat.set_shader_parameter("bleed", S.bleed)
	_paper_mat.set_shader_parameter("edge_strength", S.edge_strength)
	_paper_mat.set_shader_parameter("edge_threshold", S.edge_threshold)
	_paper_mat.set_shader_parameter("grain", S.grain)
	_paper_mat.set_shader_parameter("paper_strength", S.paper_strength)
	_paper_mat.set_shader_parameter("wobble", S.wobble)
	_paper_mat.set_shader_parameter("vignette", S.vignette)
	_paper_mat.set_shader_parameter("tilt_center", S.tilt_center)
	_paper_mat.set_shader_parameter("tilt_width", S.tilt_width)


## The higher the god looks from, the more the city looks like a miniature.
func _update_tilt_shift() -> void:
	var cam := get_viewport().get_camera_3d()
	var h := cam.global_position.y if cam else 0.0
	var k := smoothstep(S.tilt_height_min, S.tilt_height_max, h)
	_paper_mat.set_shader_parameter("tilt_blur", S.tilt_blur * k)


## Only the tone mapping: sky, ambient, fog and sun belong to the city's
## day/night cycle and are left to it.
func _style_environment(world_env: WorldEnvironment) -> void:
	var env := world_env.environment
	if env == null or not enabled:
		return
	if S.tonemap_filmic:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = S.exposure


func _noise_texture(size: int, frequency: float, octaves: int, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.seed = seed_value
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.noise = noise
	return tex
