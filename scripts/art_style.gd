extends Node
## The game's art style: a toy dollhouse town seen by a god.
## Runs as the autoload "ArtStyle". It gives every ordinary lit material in the
## world the soft cel shader (shaders/toon.gdshader), blurs the far background
## (shaders/depth_of_field.gdshader) and lays the tilt-shift and colour grade
## (shaders/screen_pass.gdshader) over the screen.
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
const SCREEN := preload("res://shaders/screen_pass.gdshader")
const DOF := preload("res://shaders/depth_of_field.gdshader")

var enabled := true

var _screen_mat := ShaderMaterial.new()
var _layer := CanvasLayer.new()
var _dof := MeshInstance3D.new()   # screen-covering quad that blurs the far background
var _toon := {}       # StandardMaterial3D -> its toon ShaderMaterial
var _colors := {}     # StandardMaterial3D -> albedo last copied into the toon material
var _meshes := []     # every MeshInstance3D we look after
var _pending := []    # meshes that entered the tree since the last frame
var _shot_path := ""
var _shot_frames := 120


func _ready() -> void:
	process_priority = 1000  # after gameplay scripts have swapped materials this frame
	enabled = S.enabled
	_screen_mat.shader = SCREEN
	_push_screen_params()
	_layer.layer = 0  # above the 3D world, below the HUD (layer 1)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _screen_mat
	_layer.add_child(rect)
	add_child(_layer)
	_layer.visible = enabled
	_build_dof()

	get_tree().node_added.connect(_on_node_added)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-frames="):
			_shot_frames = int(arg.trim_prefix("--shot-frames="))
		elif arg == "--no-style":
			enabled = false
			_layer.visible = false
	_dof.visible = enabled and S.dof_blur > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		enabled = not enabled
		_layer.visible = enabled
		_dof.visible = enabled and S.dof_blur > 0.0


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
	_follow_camera()

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
	elif node is DirectionalLight3D:
		_style_sun.call_deferred(node)


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
		and not mat.emission_enabled


func _toon_for(src: StandardMaterial3D) -> ShaderMaterial:
	if _toon.has(src):
		return _toon[src]
	var t := ShaderMaterial.new()
	t.shader = TOON
	t.set_meta("toon_source", src)
	_push_toon_params(t)
	t.set_shader_parameter("albedo", src.albedo_color)
	if src.albedo_texture:
		t.set_shader_parameter("albedo_tex", src.albedo_texture)
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
	t.set_shader_parameter("shadow_level", S.shadow_level)
	t.set_shader_parameter("shadow_softness", S.shadow_softness)
	t.set_shader_parameter("key_tint", S.key_tint)
	t.set_shader_parameter("rim_strength", S.rim_strength)
	t.set_shader_parameter("saturation", S.saturation)


func _push_screen_params() -> void:
	_screen_mat.set_shader_parameter("tilt_center", S.tilt_center)
	_screen_mat.set_shader_parameter("tilt_width", S.tilt_width)
	_screen_mat.set_shader_parameter("vibrance", S.vibrance)
	_screen_mat.set_shader_parameter("contrast", S.contrast)
	_screen_mat.set_shader_parameter("wash_color", S.wash_color)
	_screen_mat.set_shader_parameter("wash", S.wash)


## The higher the god looks from, the more the city looks like a miniature.
func _update_tilt_shift() -> void:
	var cam := get_viewport().get_camera_3d()
	var h := cam.global_position.y if cam else 0.0
	var k := smoothstep(S.tilt_height_min, S.tilt_height_max, h)
	_screen_mat.set_shader_parameter("tilt_blur", S.tilt_blur * k)


## Only the tone mapping: sky, ambient, fog and sun belong to the city's
## day/night cycle and are left to it.
func _style_environment(world_env: WorldEnvironment) -> void:
	var env := world_env.environment
	if env == null or not enabled:
		return
	if S.tonemap_filmic:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = S.exposure


func _build_dof() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = DOF
	mat.render_priority = Material.RENDER_PRIORITY_MAX  # after fire, rain and glows
	mat.set_shader_parameter("blur", S.dof_blur)
	mat.set_shader_parameter("start", S.dof_start)
	mat.set_shader_parameter("end", S.dof_end)
	mat.set_shader_parameter("focus_y", S.tilt_center)
	mat.set_shader_parameter("compat", RenderingServer.get_rendering_device() == null)
	quad.material = mat
	_dof.mesh = quad
	_dof.name = &"DepthOfField"
	_dof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dof.extra_cull_margin = 16384.0
	_dof.add_to_group(&"no_toon")


## The depth-of-field quad rides on whichever camera is drawing.
func _follow_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _dof.get_parent() == cam:
		return
	if _dof.get_parent():
		_dof.get_parent().remove_child(_dof)
	cam.add_child(_dof)
	_dof.position = Vector3(0.0, 0.0, -1.0)


## The god looks down on a sunny toy town: a fixed sun angle and crisp, long
## shadows. Energy and colour stay with the city's day/night cycle.
func _style_sun(sun: DirectionalLight3D) -> void:
	if not S.sun_override or not is_instance_valid(sun):
		return
	sun.rotation = Vector3(deg_to_rad(S.sun_pitch), deg_to_rad(S.sun_yaw), 0.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = S.shadow_distance
