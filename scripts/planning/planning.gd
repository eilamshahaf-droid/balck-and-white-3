extends Node3D
## The city-planning sandbox: only the model, no god, no people. Zone blocks,
## place landmarks and street details, and watch the city fill in by itself.
## Colour overlays (keys 1-7) show where the belief, commerce, quality of life,
## fear and influence are. Every number lives in data/planning.tres.

const CityModel = preload("res://scripts/planning/city_model.gd")
const P: PlanningSettings = preload("res://data/planning.tres")
const FLOOR_HEIGHT := 3.2

## [tool id, button label]; the section headers are the three levels of the design doc.
const TOOL_SECTIONS := [
	["Neighbourhood", [["residential", "Homes"], ["commercial", "Shops"], ["industrial", "Industry"],
			["clear", "Clear zone"], ["denser", "Denser +"], ["sparser", "Sparser -"]]],
	["Plot (landmarks)", [["temple", "Temple"], ["station", "Station"], ["square", "Square"],
			["tower", "Tower"], ["factory", "Factory"]]],
	["Street", [["tree", "Tree"], ["bench", "Bench"], ["camera", "Camera"], ["shrine", "Shrine"],
			["remove", "Remove"]]],
]
const OVERLAYS := [["none", "None"], ["zoning", "Zoning"], ["belief", "Belief"], ["commerce", "Commerce"],
		["quality", "Quality of life"], ["fear", "Fear"], ["influence", "Influence"]]
## metric -> [value that shows as full colour, colour]; quality is two-sided.
const OVERLAY_SCALE := {
	"belief": [6.0, Color(1.0, 0.75, 0.1)],
	"commerce": [10.0, Color(0.15, 0.5, 1.0)],
	"quality": [4.0, Color(0.2, 0.8, 0.25)],
	"fear": [3.0, Color(0.85, 0.1, 0.3)],
	"influence": [5.0, Color(0.65, 0.3, 1.0)],
}
const QUALITY_BAD := Color(0.95, 0.3, 0.15)
const ZONE_COLOURS := {
	"residential": Color(0.45, 0.78, 0.4), "commercial": Color(0.3, 0.55, 0.95),
	"industrial": Color(0.9, 0.68, 0.2), "": Color(0.5, 0.5, 0.5),
}
const LANDMARK_HEIGHT := {"temple": 22.0, "station": 14.0, "square": 1.5, "factory": 18.0}

var model := CityModel.new()
var tool := "residential"
var overlay := "zoning"
var paused := false

var _lot_nodes: Array = []        # lot id -> MeshInstance3D or null
var _landmark_nodes := {}         # block -> Node3D
var _detail_nodes: Array = []     # same order as model.details
var _overlay_mesh: MultiMeshInstance3D
var _ring: MeshInstance3D
var _hover_box: MeshInstance3D
var _mats := {}
var _build_timer := 0.0
var _overlay_dirty := true
var _hover_pos := Vector3.ZERO
var _hover_valid := false
var _last_painted := -1
var _message := ""
var _message_time := 0.0

var _panels: Array[Control] = []
var _info: Label
var _stats: Label
var _tool_buttons := {}
var _overlay_buttons := {}

@onready var rig: Node3D = $CameraRig


func _ready() -> void:
	_build_environment()
	_build_ground()
	model.seed_existing_city()
	_lot_nodes.resize(model.lots.size())
	for n in model.lots.size():
		_refresh_lot(n)
	_build_overlay()
	_build_markers()
	_build_ui()
	_select_tool(tool)
	_select_overlay(overlay)


# --- Each frame ---

func _process(delta: float) -> void:
	if not paused:
		_build_timer -= delta
		while _build_timer <= 0.0:
			_build_timer += P.build_interval
			var lot_id := model.step()
			if lot_id >= 0:
				_refresh_lot(lot_id)
				_overlay_dirty = true
	_update_hover()
	if _overlay_dirty:
		_overlay_dirty = false
		_update_overlay()
	# Overlays are faint up close and strong from above, so the city stays readable.
	if overlay != "none":
		_overlay_mesh.material_override.albedo_color.a = lerpf(0.55, 1.0, rig.zoom_t())
	_message_time -= delta
	_update_texts()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_painted = -1
		if event.pressed and _hover_valid:
			_apply_tool(_hover_pos)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and _hover_valid:
		# Zones can be painted by dragging over blocks.
		if tool in ["residential", "commercial", "industrial", "clear"]:
			_apply_tool(_hover_pos)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			_select_overlay(OVERLAYS[event.keycode - KEY_1][0])
		elif event.keycode == KEY_SPACE:
			paused = not paused
		elif event.keycode == KEY_ESCAPE:
			_select_tool("inspect")


# --- Tools ---

func _apply_tool(pos: Vector3) -> void:
	var b := model.block_at(pos)
	match tool:
		"residential", "commercial", "industrial", "clear":
			if b < 0 or b == _last_painted:
				return
			_last_painted = b
			model.set_zone(b, "" if tool == "clear" else tool)
			_refresh_block(b)
		"denser", "sparser":
			if b >= 0:
				model.change_density(b, 1 if tool == "denser" else -1)
				_say("Density %d: buildings will be rebuilt to %d floors" % [model.blocks[b].density,
						P.floors_per_density[model.blocks[b].density - 1]])
		"temple", "station", "square", "tower", "factory":
			if b < 0:
				_say("Landmarks go on a block, not on the road")
			elif model.place_landmark(b, tool):
				_refresh_block(b)
				_say("%s built" % tool.capitalize())
			else:
				_say("This block already has a landmark (use Remove)")
		"tree", "bench", "camera", "shrine":
			model.place_detail(tool, pos)
			_detail_nodes.append(_make_detail(tool, pos))
			_overlay_dirty = true
		"remove":
			var n := model.remove_detail_near(pos)
			if n >= 0:
				_detail_nodes[n].queue_free()
				_detail_nodes.remove_at(n)
				_overlay_dirty = true
			elif b >= 0 and model.blocks[b].landmark != "":
				model.remove_landmark(b)
				_refresh_block(b)


func _say(text: String) -> void:
	_message = text
	_message_time = 3.0


func _select_tool(id: String) -> void:
	tool = id
	for t in _tool_buttons:
		_tool_buttons[t].button_pressed = t == id


func _select_overlay(id: String) -> void:
	overlay = id
	for o in _overlay_buttons:
		_overlay_buttons[o].button_pressed = o == id
	_overlay_mesh.visible = id != "none"
	_overlay_dirty = true
	# Under a metric overlay the buildings turn plain white, so the colour reads clearly.
	for n in model.lots.size():
		if _lot_nodes[n] != null:
			_lot_nodes[n].material_override = _lot_mat(n)


# --- Hover, preview and texts ---

func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	_hover_valid = false
	for p in _panels:
		if p.get_global_rect().has_point(mouse):
			_ring.visible = false
			_hover_box.visible = false
			return
	var cam: Camera3D = rig.camera
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return
	_hover_valid = true
	_hover_pos = hit
	var reach := model.reach_of(tool)
	_ring.visible = reach > 0.0
	if _ring.visible:
		var centre: Vector3 = _hover_pos
		var b := model.block_at(_hover_pos)
		if P.landmarks.has(tool) and b >= 0:
			centre = model.blocks[b].center   # a landmark always sits in the middle of its block
		_ring.position = centre + Vector3.UP * 0.6
		_ring.scale = Vector3(reach, 1, reach)
	var hb := model.block_at(_hover_pos)
	_hover_box.visible = hb >= 0
	if hb >= 0:
		var block: Dictionary = model.blocks[hb]
		_hover_box.position = block.center + Vector3.UP * 0.45
		_hover_box.scale = Vector3(block.size.x + 1.0, 1, block.size.y + 1.0)


func _update_texts() -> void:
	var s := model.stats()
	_stats.text = "Population  %d\nPrayer  %.1f belief / min\nJobs  %d\nQuality of life  %+.1f\nFear  %.1f\nBuilt lots  %d / %d\nLandmarks  %d%s" % [
			s.population, s.prayer, s.jobs, s.quality, s.fear, s.built, model.lots.size(), s.landmarks,
			"\n\nPAUSED (Space)" if paused else ""]
	var lines: Array[String] = []
	if _message_time > 0.0:
		lines.append(_message)
	if _hover_valid:
		var lot_id := model.lot_at(_hover_pos)
		var b := model.block_at(_hover_pos)
		if b >= 0:
			var block: Dictionary = model.blocks[b]
			var zone: String = block.zone if block.zone != "" else "no zone"
			lines.append("Block: %s, density %d%s%s" % [zone, block.density,
					", landmark: " + block.landmark if block.landmark != "" else "",
					", mixed use bonus" if model._mixed_use(b) else ""])
		if lot_id >= 0:
			var lot: Dictionary = model.lots[lot_id]
			var parts: Array[String] = []
			for m in CityModel.METRICS:
				parts.append("%s %.1f" % [m.capitalize(), model.value(m, lot_id)])
			lines.append("This lot: %d floors, %d residents   |   %s" % [lot.floors, model.residents(lot_id), "   ".join(parts)])
		# The number before placing: what this would add to the block under the cursor.
		if (P.landmarks.has(tool) or P.details.has(tool)) and b >= 0:
			var centre: Vector3 = model.blocks[b].center if P.landmarks.has(tool) else _hover_pos
			var effect := model.preview(tool, centre, b)
			var parts: Array[String] = []
			for m in effect:
				parts.append("%s %+.1f" % [m.capitalize(), effect[m]])
			lines.append("Placing %s here: %s   (reach %d m)" % [tool, "   ".join(parts), model.reach_of(tool)])
	_info.text = "\n".join(lines)


# --- Overlays ---

func _build_overlay() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plane
	mm.instance_count = model.lots.size()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_overlay_mesh = MultiMeshInstance3D.new()
	_overlay_mesh.multimesh = mm
	_overlay_mesh.material_override = mat
	_overlay_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay_mesh.add_to_group(&"no_toon")
	add_child(_overlay_mesh)


func _update_overlay() -> void:
	if overlay == "none":
		return
	var mm := _overlay_mesh.multimesh
	for n in model.lots.size():
		var lot: Dictionary = model.lots[n]
		var size := Basis.from_scale(Vector3(lot.width * 0.96, 1, lot.depth * 0.96))
		mm.set_instance_transform(n, Transform3D(size, lot.pos + Vector3.UP * (_top_of(n) + 0.35)))
		mm.set_instance_color(n, _overlay_colour(n))


func _overlay_colour(n: int) -> Color:
	if overlay == "zoning":
		var block: Dictionary = model.blocks[model.lots[n].block]
		var c: Color = ZONE_COLOURS[block.zone]
		if block.landmark != "" and n in [block.lots[2], block.lots[3]]:
			c = Color(0.95, 0.95, 0.95)
		c.a = 0.75 if model.lots[n].floors > 0 or block.landmark != "" else 0.4
		return c
	var spec: Array = OVERLAY_SCALE[overlay]
	var t: float = model.value(overlay, n) / spec[0]
	var c: Color = spec[1] if t >= 0.0 else QUALITY_BAD
	t = clampf(absf(t), 0.0, 1.0)
	if overlay != "quality" and model.value(overlay, n) < 0.0:
		t = 0.0
	return Color(c.r, c.g, c.b, 0.12 + 0.83 * t)


func _top_of(n: int) -> float:
	var block: Dictionary = model.blocks[model.lots[n].block]
	if block.landmark != "" and n in [block.lots[2], block.lots[3]]:
		return P.tower_height if block.landmark == "tower" else LANDMARK_HEIGHT[block.landmark]
	return model.lots[n].floors * FLOOR_HEIGHT


# --- 3D city ---

func _refresh_block(b: int) -> void:
	for lot_id in model.blocks[b].lots:
		_refresh_lot(lot_id)
	if _landmark_nodes.has(b):
		_landmark_nodes[b].queue_free()
		_landmark_nodes.erase(b)
	if model.blocks[b].landmark != "":
		_landmark_nodes[b] = _make_landmark(model.blocks[b])
	_overlay_dirty = true


func _refresh_lot(n: int) -> void:
	if _lot_nodes[n] != null:
		_lot_nodes[n].queue_free()
		_lot_nodes[n] = null
	var lot: Dictionary = model.lots[n]
	if lot.floors == 0:
		return
	var h: float = lot.floors * FLOOR_HEIGHT
	_lot_nodes[n] = _box(Vector3(lot.width * 0.84, h, lot.depth * 0.8), lot.pos + Vector3.UP * h / 2.0, _lot_mat(n))


func _lot_mat(n: int) -> StandardMaterial3D:
	return _mat("plain") if OVERLAY_SCALE.has(overlay) else _mat("zone_" + model.lots[n].zone)


func _make_landmark(block: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = block.center
	add_child(root)
	var w: float = model.lots[block.lots[2]].width * 2.0 * 0.9
	var d: float = block.size.y * 0.8
	match block.landmark:
		"temple":
			_box(Vector3(w, 14, d), Vector3(0, 7, 0), _mat("temple"), root)
			var roof := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(w, 8, d)
			roof.mesh = prism
			roof.position = Vector3(0, 18, 0)
			roof.material_override = _mat("gold")
			root.add_child(roof)
		"station":
			_box(Vector3(w, 10, d), Vector3(0, 5, 0), _mat("station"), root)
			_box(Vector3(w * 0.3, 14, d * 0.3), Vector3(0, 7, 0), _mat("station_roof"), root)
		"square":
			_box(Vector3(w, 0.6, d), Vector3(0, 0.3, 0), _mat("square"), root)
			_box(Vector3(3, 1.5, 3), Vector3(0, 0.75, 0), _mat("water"), root)
		"tower":
			_box(Vector3(w * 0.5, P.tower_height, d * 0.7), Vector3(0, P.tower_height / 2.0, 0), _mat("tower"), root)
		"factory":
			_box(Vector3(w, 12, d), Vector3(0, 6, 0), _mat("factory"), root)
			for x in [-0.25, 0.25]:
				_box(Vector3(2, 18, 2), Vector3(w * x, 9, d * 0.2), _mat("chimney"), root)
	return root


func _make_detail(kind: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	match kind:
		"tree":
			_box(Vector3(0.5, 3, 0.5), Vector3(0, 1.5, 0), _mat("trunk"), root)
			var crown := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 2.2
			sphere.height = 4.0
			crown.mesh = sphere
			crown.position = Vector3(0, 4.2, 0)
			crown.material_override = _mat("leaves")
			root.add_child(crown)
		"bench":
			_box(Vector3(2.4, 0.5, 0.8), Vector3(0, 0.45, 0), _mat("bench"), root)
		"camera":
			_box(Vector3(0.25, 5, 0.25), Vector3(0, 2.5, 0), _mat("chimney"), root)
			_box(Vector3(0.8, 0.5, 1.2), Vector3(0, 5, 0.3), _mat("camera"), root)
		"shrine":
			_box(Vector3(1.4, 1.6, 1.0), Vector3(0, 0.8, 0), _mat("temple"), root)
			_box(Vector3(0.6, 0.6, 0.2), Vector3(0, 1.4, 0.55), _mat("gold"), root)
	return root


func _build_markers() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.97
	torus.outer_radius = 1.0
	torus.rings = 96
	_ring.mesh = torus
	_ring.material_override = _flat(Color(1, 1, 1, 0.7))
	_ring.add_to_group(&"no_toon")
	add_child(_ring)
	_hover_box = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_hover_box.mesh = plane
	_hover_box.material_override = _flat(Color(1, 1, 1, 0.18))
	_hover_box.add_to_group(&"no_toon")
	add_child(_hover_box)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.75, 0.8, 0.88)
	sky_mat.ground_horizon_color = Color(0.75, 0.8, 0.88)
	sky_mat.ground_bottom_color = Color(0.6, 0.62, 0.66)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	add_child(sun)


func _build_ground() -> void:
	var hs := model.half_size
	_box(Vector3(hs.x * 2 + 120, 1, hs.y * 2 + 120), Vector3(0, -0.5, 0), _mat("asphalt"))
	_box(Vector3(4000, 1, 4000), Vector3(0, -0.6, 0), _mat("land"))
	for block in model.blocks:
		_box(Vector3(block.size.x, 0.3, block.size.y), block.center + Vector3.UP * 0.15, _mat("pavement"))


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


const MATERIAL_COLOURS := {
	"zone_residential": Color(0.76, 0.56, 0.46), "zone_commercial": Color(0.6, 0.68, 0.78),
	"zone_industrial": Color(0.58, 0.53, 0.45), "temple": Color(0.92, 0.88, 0.78),
	"gold": Color(0.85, 0.68, 0.3), "station": Color(0.62, 0.42, 0.36), "station_roof": Color(0.45, 0.55, 0.5),
	"square": Color(0.72, 0.7, 0.62), "water": Color(0.4, 0.62, 0.8), "tower": Color(0.5, 0.6, 0.7),
	"factory": Color(0.5, 0.46, 0.42), "chimney": Color(0.35, 0.33, 0.32), "trunk": Color(0.4, 0.28, 0.18),
	"leaves": Color(0.35, 0.6, 0.3), "bench": Color(0.55, 0.4, 0.25), "camera": Color(0.2, 0.2, 0.22),
	"asphalt": Color(0.3, 0.3, 0.32), "pavement": Color(0.6, 0.58, 0.55),
	"land": Color(0.5, 0.58, 0.42), "plain": Color(0.9, 0.9, 0.88),
}


func _mat(id: String) -> StandardMaterial3D:
	if not _mats.has(id):
		var m := StandardMaterial3D.new()
		m.albedo_color = MATERIAL_COLOURS[id]
		_mats[id] = m
	return _mats[id]


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m


# --- UI ---

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var left := _panel(ui, Vector2(10, 10))
	var col := VBoxContainer.new()
	left.add_child(col)
	var tools_group := ButtonGroup.new()
	_add_tool_button(col, tools_group, "inspect", "Look (Esc)")
	for section in TOOL_SECTIONS:
		var head := Label.new()
		head.text = section[0]
		head.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		col.add_child(head)
		for t in section[1]:
			_add_tool_button(col, tools_group, t[0], t[1])

	var top := _panel(ui, Vector2(200, 10))
	var row := HBoxContainer.new()
	top.add_child(row)
	var title := Label.new()
	title.text = "Overlay:"
	row.add_child(title)
	var overlay_group := ButtonGroup.new()
	for i in OVERLAYS.size():
		var o: Array = OVERLAYS[i]
		var b := _button("%d %s" % [i + 1, o[1]], overlay_group)
		b.pressed.connect(_select_overlay.bind(o[0]))
		row.add_child(b)
		_overlay_buttons[o[0]] = b

	var right := _panel(ui, Vector2.ZERO)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(get_viewport().get_visible_rect().size.x - 250, 60)
	right.custom_minimum_size = Vector2(240, 0)
	_stats = Label.new()
	right.add_child(_stats)

	_info = Label.new()
	_info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_info.position = Vector2(200, get_viewport().get_visible_rect().size.y - 110)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_info)

	var help := Label.new()
	help.text = "WASD / right-drag: move   Wheel: zoom   Q/E: turn   R/F: tilt   Left click: use tool (drag to paint zones)   Space: pause growth   V: art style"
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(200, get_viewport().get_visible_rect().size.y - 28)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(help)


func _panel(parent: Node, pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	parent.add_child(p)
	_panels.append(p)
	return p


func _button(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	return b


func _add_tool_button(parent: Node, group: ButtonGroup, id: String, text: String) -> void:
	var b := _button(text, group)
	b.pressed.connect(_select_tool.bind(id))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	_tool_buttons[id] = b
