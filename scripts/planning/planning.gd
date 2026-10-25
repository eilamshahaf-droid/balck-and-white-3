extends Node3D
## The city-planning sandbox: only the model, no god, no people. The land has
## hills and a river, and the streets follow it. Draw new roads, avenues and
## paths as in BW2 (the blocks reshape around them), zone the blocks, place
## landmarks and street details, and watch the city grow and change its look
## by itself. Colour overlays (keys 1-7) show where the belief, commerce,
## quality of life, fear and influence are, as soft heat on the ground and
## tints on the buildings. Three example plans (good, evil, neutral god) show
## the planning principles of each path. Every number lives in data/planning.tres.

const CityModel = preload("res://scripts/planning/city_model.gd")
const Roads = preload("res://scripts/planning/road_network.gd")
const Visuals = preload("res://scripts/planning/planning_visuals.gd")
const Examples = preload("res://scripts/planning/planning_examples.gd")
const P: PlanningSettings = preload("res://data/planning.tres")

## [tool id, button label]; the section headers are the three levels of the design doc.
const TOOL_SECTIONS := [
	["Streets (drag to draw)", [["street", "Street"], ["avenue", "Avenue"], ["path", "Path"],
			["pedestrian", "Car-free"], ["remove_road", "Remove road"], ["straight", "Straight: off"]]],
	["Neighbourhood", [["residential", "Homes"], ["commercial", "Shops"], ["industrial", "Industry"],
			["clear", "Clear zone"], ["denser", "Denser +"], ["sparser", "Sparser -"]]],
	["Plot (landmarks)", [["temple", "Temple"], ["square", "Square"], ["park", "Park"], ["station", "Station"],
			["tower", "HQ tower"], ["factory", "Factory"], ["monument", "Monument"]]],
	["Street details", [["tree", "Tree"], ["bench", "Bench"], ["shrine", "Shrine"], ["camera", "Camera"],
			["billboard", "Billboard"], ["remove", "Remove"]]],
]
const DRAW_TOOLS := ["street", "avenue", "path"]
const OVERLAYS := [["none", "None"], ["zoning", "Zoning"], ["belief", "Belief"], ["commerce", "Commerce"],
		["quality", "Quality of life"], ["fear", "Fear"], ["influence", "Influence"]]
## metric -> [value that shows as full colour, colour]; quality is two-sided.
const OVERLAY_SCALE := {
	"belief": [6.0, Color(1.0, 0.72, 0.05)],
	"commerce": [10.0, Color(0.15, 0.45, 1.0)],
	"quality": [5.0, Color(0.15, 0.75, 0.2)],
	"fear": [3.0, Color(0.85, 0.05, 0.25)],
	"influence": [6.0, Color(0.6, 0.25, 1.0)],
}
const QUALITY_BAD := Color(0.95, 0.3, 0.1)
const ZONE_COLOURS := {
	"residential": Color(0.4, 0.75, 0.35), "commercial": Color(0.3, 0.5, 0.95),
	"industrial": Color(0.9, 0.65, 0.15), "": Color(0.6, 0.6, 0.6),
}
const LANDMARK_HEIGHT := {"temple": 20.0, "square": 1.5, "park": 1.0, "station": 18.0, "factory": 22.0, "monument": 55.0}
const HEAT_SIZE := Vector2i(168, 128)

var model
var vis := Visuals.new()
var tool := "inspect"
var overlay := "none"
var paused := false
var example := ""
var straight := false              # draw roads exactly as drawn, ignoring the slopes

var _city: Node3D                  # everything built from the model; rebuilt when the streets change
var _lot_nodes: Array = []         # lot id -> Node3D or null
var _landmark_nodes := {}          # landmark dictionary -> Node3D
var _detail_nodes: Array = []      # same order as model.details
var _heat: MeshInstance3D
var _heat_image: Image
var _heat_texture: ImageTexture
var _cell_block := PackedInt32Array()
var _ring: MeshInstance3D
var _lines: MeshInstance3D         # road being drawn and the outline of the block under the cursor
var _drawing := PackedVector2Array()
var _build_timer := 0.0
var _overlay_dirty := true
var _overlay_timer := 0.0
var _hover_pos := Vector3.ZERO
var _hover_valid := false
var _last_painted := -1
var _message := ""
var _message_time := 0.0

var _panels: Array[Control] = []
var _info: Label
var _stats: Label
var _story: Label
var _tool_buttons := {}
var _overlay_buttons := {}

@onready var rig: Node3D = $CameraRig


func _ready() -> void:
	_build_environment()
	_build_markers()
	_build_ui()
	load_city("")
	_select_tool(tool)
	_select_overlay(overlay)


## Start again from the existing city, and apply an example plan if given
## ("good", "evil", "neutral"; "" for the plain starting city).
func load_city(which: String) -> void:
	example = which
	var first: bool = model == null
	model = CityModel.new()
	model.seed_existing_city()
	if which != "":
		Examples.apply(model, which)
	if first:
		var land := Node3D.new()
		add_child(land)
		vis.terrain_mesh(model.terrain, land)
		vis.water(model.terrain, land)
		_heat = vis.terrain_mesh(model.terrain, land, 0.7)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_heat.material_override = mat
		_heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_heat.visible = false
	_story.text = "%s\n%s" % [Examples.TITLES[which], Examples.TEXTS[which]] if which != "" else \
			"The existing city: its streets follow the hills and cross the river on a few bridges. Draw new streets, avenues and paths, zone the blocks, or load an example plan."
	_rebuild_city()


## Build every visible thing again from the model (after the streets changed).
func _rebuild_city() -> void:
	if _city:
		_city.free()
	_city = Node3D.new()
	add_child(_city)
	vis.roads(model.roads, _city)
	_lot_nodes.clear()
	_lot_nodes.resize(model.lots.size())
	_landmark_nodes.clear()
	_detail_nodes.clear()
	for n in model.lots.size():
		_refresh_lot(n)
	for lm in model.landmarks:
		_landmark_nodes[lm] = vis.landmark(lm, model.terrain, _landmark_height(lm.kind), _city)
	for d in model.details:
		_detail_nodes.append(vis.detail(d.kind, d.pos, _city))
	_build_cell_blocks()
	_overlay_dirty = true
	_overlay_timer = 0.0
	_apply_overlay_to_buildings()


# --- Each frame ---

func _process(delta: float) -> void:
	if not paused:
		_build_timer -= delta
		var budget := 4
		while _build_timer <= 0.0 and budget > 0:
			_build_timer += P.build_interval
			budget -= 1
			var lot_id: int = model.step()
			if lot_id >= 0:
				_refresh_lot(lot_id)
				_overlay_dirty = true
		_build_timer = maxf(_build_timer, -P.build_interval)
	_update_hover()
	_draw_lines()
	_overlay_timer -= delta
	if _overlay_dirty and _overlay_timer <= 0.0:
		_overlay_dirty = false
		_overlay_timer = 0.3
		_update_heat()
		_apply_overlay_to_buildings()
	# The heat is faint up close and strong from above, so the city stays readable.
	_heat.material_override.albedo_color.a = lerpf(0.6, 1.0, rig.zoom_t())
	# The camera rides over the hills.
	rig.position.y = lerpf(rig.position.y, model.terrain.height_at(rig.position.x, rig.position.z), minf(delta * 4.0, 1.0))
	_message_time -= delta
	_update_texts()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_painted = -1
		if tool in DRAW_TOOLS:
			if event.pressed and _hover_valid:
				_drawing = PackedVector2Array([Vector2(_hover_pos.x, _hover_pos.z)])
			elif not event.pressed and _drawing.size() > 0:
				_finish_road()
		elif event.pressed and _hover_valid:
			_apply_tool(_hover_pos)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and _hover_valid:
		if tool in DRAW_TOOLS and _drawing.size() > 0:
			var p := Vector2(_hover_pos.x, _hover_pos.z)
			if p.distance_to(_drawing[_drawing.size() - 1]) > 4.0:
				_drawing.append(p)
		elif tool in ["residential", "commercial", "industrial", "clear"]:
			_apply_tool(_hover_pos)   # zones can be painted by dragging over blocks
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			_select_overlay(OVERLAYS[event.keycode - KEY_1][0])
		elif event.keycode == KEY_SPACE:
			paused = not paused
		elif event.keycode == KEY_ESCAPE:
			_drawing = PackedVector2Array()
			_select_tool("inspect")


# --- Tools ---

## A drawn road joins the network: it bends around slopes (unless Straight is
## on), splits the roads it crosses, and the blocks reshape around it.
func draw_road(points: PackedVector2Array, kind: String, follow_terrain := true) -> void:
	var before: int = model.roads.edges.size()
	var knocked: Array = model.add_road(points, kind, follow_terrain)
	if model.roads.edges.size() == before:
		_say("Too short, or the same as a road that is already there")
		return
	_rebuild_city()
	if knocked.size() > 0:
		_say("The new road ran through %d landmark(s) and knocked them down" % knocked.size())


func _finish_road() -> void:
	var pts := _drawing
	_drawing = PackedVector2Array()
	if pts.size() >= 2:
		draw_road(pts, tool, not straight)


func _apply_tool(pos: Vector3) -> void:
	var b: int = model.block_at(pos)
	match tool:
		"residential", "commercial", "industrial", "clear":
			if b < 0 or b == _last_painted:
				return
			_last_painted = b
			model.set_zone(b, "" if tool == "clear" else tool)
			for lot_id in model.blocks[b].lots:
				_refresh_lot(lot_id)
			_overlay_dirty = true
		"denser", "sparser":
			if b >= 0:
				model.change_density(b, 1 if tool == "denser" else -1)
				_say("Density %d: buildings will be rebuilt up to about %d floors" % [model.blocks[b].density,
						P.floors_per_density[model.blocks[b].density - 1]])
		"pedestrian":
			if model.toggle_pedestrian_near(pos):
				_rebuild_city()
			else:
				_say("Click a street (not an avenue) to close it to cars, or open it again")
		"remove_road":
			if model.remove_road_near(pos):
				_rebuild_city()
		"remove":
			_remove_at(pos)
		_:
			if P.landmarks.has(tool):
				var lm: Dictionary = model.place_landmark(tool, pos)
				if lm.is_empty():
					_say("It doesn't fit here: it needs room along a street, on dry and fairly flat land")
				else:
					for lot_id in lm.lots:
						_refresh_lot(lot_id)
					_landmark_nodes[lm] = vis.landmark(lm, model.terrain, _landmark_height(lm.kind), _city)
					_overlay_dirty = true
			elif P.details.has(tool):
				model.place_detail(tool, pos)
				_detail_nodes.append(vis.detail(tool, model.details[model.details.size() - 1].pos, _city))
				_overlay_dirty = true


func _remove_at(pos: Vector3) -> void:
	var n: int = model.remove_detail_near(pos)
	if n >= 0:
		_detail_nodes[n].queue_free()
		_detail_nodes.remove_at(n)
	else:
		var lm: Dictionary = model.remove_landmark_at(pos)
		if lm.is_empty():
			return
		_landmark_nodes[lm].queue_free()
		_landmark_nodes.erase(lm)
	_overlay_dirty = true


func _say(text: String) -> void:
	_message = text
	_message_time = 3.5


func _select_tool(id: String) -> void:
	if id == "straight":
		straight = not straight
		_tool_buttons.straight.text = "Straight: on" if straight else "Straight: off"
		_tool_buttons.straight.button_pressed = false
		_tool_buttons[tool].button_pressed = true
		return
	tool = id
	for t in _tool_buttons:
		_tool_buttons[t].button_pressed = t == id


func _select_overlay(id: String) -> void:
	overlay = id
	for o in _overlay_buttons:
		_overlay_buttons[o].button_pressed = o == id
	_heat.visible = id != "none"
	_overlay_dirty = true
	_overlay_timer = 0.0


# --- Hover, preview and texts ---

func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	_hover_valid = false
	_ring.visible = false
	for p in _panels:
		if p.get_global_rect().has_point(mouse):
			return
	var cam: Camera3D = rig.camera
	var hit = model.terrain.raycast(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return
	_hover_valid = true
	_hover_pos = hit
	var centre := _placement_centre()
	var reach: float = model.reach_of(tool, centre) if centre != Vector3.INF else 0.0
	_ring.visible = reach > 0.0
	if _ring.visible:
		_ring.position = centre + Vector3.UP * 1.0
		_ring.scale = Vector3(reach, 1, reach)


## Where the current tool would put its structure.
func _placement_centre() -> Vector3:
	if P.landmarks.has(tool):
		var fp: Dictionary = model.landmark_footprint(tool, _hover_pos)
		return Vector3.INF if fp.is_empty() else fp.pos
	return _hover_pos


## The road being drawn, coloured by how steep it is, and the block under the cursor.
func _draw_lines() -> void:
	var im: ImmediateMesh = _lines.mesh
	im.clear_surfaces()
	var t = model.terrain
	if _drawing.size() >= 2 or (_drawing.size() == 1 and _hover_valid):
		var pts := _drawing.duplicate()
		if _hover_valid:
			pts.append(Vector2(_hover_pos.x, _hover_pos.z))
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in pts.size():
			var grade := 0.0
			if k > 0 and pts[k].distance_to(pts[k - 1]) > 0.5:
				grade = absf(t.road_height(pts[k]) - t.road_height(pts[k - 1])) / pts[k].distance_to(pts[k - 1])
			var c := Color(0.2, 0.9, 0.3)
			if grade > P.road_max_grade:
				c = Color(1.0, 0.2, 0.15)
			elif grade > P.road_max_grade * 0.5:
				c = Color(1.0, 0.8, 0.2)
			im.surface_set_color(c)
			im.surface_add_vertex(Vector3(pts[k].x, t.road_height(pts[k]) + 1.5, pts[k].y))
		im.surface_end()
	if _hover_valid and tool not in DRAW_TOOLS:
		var b: int = model.block_at(_hover_pos)
		if b >= 0:
			var poly: PackedVector2Array = model.blocks[b].polygon
			im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for k in poly.size() + 1:
				var p := poly[k % poly.size()]
				im.surface_set_color(Color(1, 1, 1, 0.8))
				im.surface_add_vertex(Vector3(p.x, t.road_height(p) + 1.2, p.y))
			im.surface_end()


func _update_texts() -> void:
	var s: Dictionary = model.stats()
	_stats.text = "Population  %d\nJobs  %d\nQuality of life  %+.1f\nFear  %.1f\n\nPer minute:\n  Prayer  %.1f\n  Migrants (good)  %.1f\n  Power (evil)  %.1f\n  Money (neutral)  %.0f\n\nBuildings looking\n  good %d   evil %d   neutral %d\nStreets %.1f km, %d blocks\nBuilt lots  %d / %d%s" % [
			s.population, s.jobs, s.quality, s.fear, s.prayer, s.migrants, s.power, s.money,
			s.looks.good, s.looks.evil, s.looks.grey, s.roads_km, s.blocks, s.built, s.lots,
			"\n\nPAUSED (Space)" if paused else ""]
	var lines: Array[String] = []
	if _message_time > 0.0:
		lines.append(_message)
	if _hover_valid:
		var lot_id: int = model.lot_at(_hover_pos)
		var b: int = model.block_at(_hover_pos)
		var ground := "height %d m, slope %d%%" % [roundi(_hover_pos.y), roundi(model.terrain.slope_at(Vector2(_hover_pos.x, _hover_pos.z)) * 100.0)]
		if b >= 0:
			var block: Dictionary = model.blocks[b]
			var zone: String = block.zone if block.zone != "" else ("water" if block.water else "no zone")
			lines.append("Block: %s, density %d, %d lots%s   |   %s" % [zone, block.density, block.lots.size(),
					", mixed use bonus" if model.mixed_use(b) else "", ground])
		else:
			lines.append("Ground: " + ground)
		if lot_id >= 0:
			var lot: Dictionary = model.lots[lot_id]
			var parts: Array[String] = []
			for m in CityModel.METRICS:
				parts.append("%s %.1f" % [m.capitalize(), model.value(m, lot_id)])
			var what: String = "landmark: " + lot.landmark.kind if lot.landmark != null else \
					"%d floors, %d residents, looks %s" % [lot.floors, model.residents(lot_id), _look_name(lot.character)]
			lines.append("This lot: %s   |   %s" % [what, "   ".join(parts)])
		# The number before placing: what this would add to the block under the cursor.
		var centre := _placement_centre()
		if model.definition(tool).size() > 0 and centre != Vector3.INF and tool != "pedestrian":
			var pb: int = model.block_at(centre) if b < 0 else b
			if pb >= 0:
				var effect: Dictionary = model.preview(tool, centre, pb)
				var parts: Array[String] = []
				for m in effect:
					parts.append("%s %+.1f" % [m.capitalize(), effect[m]])
				lines.append("Placing %s here: %s   (reach %d m)" % [tool, "   ".join(parts), model.reach_of(tool, centre)])
	if tool in DRAW_TOOLS:
		lines.append("Hold the left button and drag to draw. Green is gentle, yellow steep, red too steep. %s" %
				("Straight is on: the road goes exactly where drawn." if straight else "The road bends around slopes."))
	_info.text = "\n".join(lines)


func _look_name(character: String) -> String:
	return {"good": "good", "evil": "evil", "grey": "neutral"}.get(character, "ordinary")


# --- Overlays ---

## Soft heat on the ground, sampled from the model's fields.
func _update_heat() -> void:
	if overlay == "none":
		return
	if _heat_image == null:
		_heat_image = Image.create(HEAT_SIZE.x, HEAT_SIZE.y, false, Image.FORMAT_RGBA8)
	var hs: Vector2 = model.terrain.half_size
	for y in HEAT_SIZE.y:
		for x in HEAT_SIZE.x:
			var c: Color
			if overlay == "zoning":
				var b := _cell_block[y * HEAT_SIZE.x + x]
				c = ZONE_COLOURS[model.blocks[b].zone] if b >= 0 else Color(0, 0, 0, 0)
				c.a = 0.55 if b >= 0 and model.blocks[b].zone != "" else 0.0
			else:
				var p := _heat_point(x, y, hs)
				c = _metric_colour(model.field_at(overlay, Vector3(p.x, 0, p.y)))
			_heat_image.set_pixel(x, y, c)
	if _heat_texture == null:
		_heat_texture = ImageTexture.create_from_image(_heat_image)
		_heat.material_override.albedo_texture = _heat_texture
	else:
		_heat_texture.update(_heat_image)


func _heat_point(x: int, y: int, hs: Vector2) -> Vector2:
	return Vector2((x + 0.5) / HEAT_SIZE.x, (y + 0.5) / HEAT_SIZE.y) * hs * 2.0 - hs


func _metric_colour(v: float) -> Color:
	var spec: Array = OVERLAY_SCALE[overlay]
	var t: float = v / spec[0]
	if overlay != "quality" and t < 0.0:
		t = 0.0
	var c: Color = spec[1] if t >= 0.0 else QUALITY_BAD
	t = clampf(absf(t), 0.0, 1.0)
	return Color(c.r, c.g, c.b, 0.05 + 0.85 * t)


## Under an overlay, building bodies are tinted: white where the value is low,
## full colour where it is high. With no overlay they get their own colours back.
func _apply_overlay_to_buildings() -> void:
	for n in _lot_nodes.size():
		if _lot_nodes[n] != null:
			_tint(_lot_nodes[n], model.lots[n].pos, model.lots[n].zone)
	for lm in _landmark_nodes:
		_tint(_landmark_nodes[lm], lm.pos, "")


func _tint(node: Node3D, pos: Vector3, zone: String) -> void:
	var colour := Color.WHITE
	if overlay == "zoning":
		colour = Color.WHITE.lerp(ZONE_COLOURS[zone], 0.75) if zone != "" else Color(0.95, 0.95, 0.95)
	elif overlay != "none":
		var c := _metric_colour(model.field_at(overlay, pos))
		# A few steps of colour, so the buildings share a handful of materials.
		colour = Color.WHITE.lerp(Color(c.r, c.g, c.b), snappedf(c.a, 0.1))
	for body in node.get_meta("bodies", []):
		if not body.has_meta("own"):
			body.set_meta("own", body.material_override)
		body.material_override = body.get_meta("own") if overlay == "none" else vis.material(colour)


func _build_cell_blocks() -> void:
	var hs: Vector2 = model.terrain.half_size
	_cell_block.resize(HEAT_SIZE.x * HEAT_SIZE.y)
	for y in HEAT_SIZE.y:
		for x in HEAT_SIZE.x:
			var p := _heat_point(x, y, hs)
			_cell_block[y * HEAT_SIZE.x + x] = model.block_at(Vector3(p.x, 0, p.y))


# --- 3D city ---

func _refresh_lot(n: int) -> void:
	if _lot_nodes[n] != null:
		_lot_nodes[n].queue_free()
		_lot_nodes[n] = null
	var lot: Dictionary = model.lots[n]
	if lot.floors == 0:
		return
	_lot_nodes[n] = vis.building(lot, _city)
	if overlay != "none":
		_tint(_lot_nodes[n], lot.pos, lot.zone)


func _landmark_height(kind: String) -> float:
	return P.tower_height if kind == "tower" else LANDMARK_HEIGHT[kind]


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
	_lines = MeshInstance3D.new()
	_lines.mesh = ImmediateMesh.new()
	var mat := _flat(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_lines.material_override = mat
	_lines.add_to_group(&"no_toon")
	add_child(_lines)


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
	var screen := get_viewport().get_visible_rect().size

	var left := _panel(ui, Vector2(10, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	left.add_child(col)
	var tools_group := ButtonGroup.new()
	_add_tool_button(col, tools_group, "inspect", "Look (Esc)")
	for section in TOOL_SECTIONS:
		var head := Label.new()
		head.text = section[0]
		head.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		head.add_theme_font_size_override("font_size", 13)
		col.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		col.add_child(grid)
		for t in section[1]:
			_add_tool_button(grid, null if t[0] == "straight" else tools_group, t[0], t[1])

	var top := _panel(ui, Vector2(250, 10))
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

	var ex := _panel(ui, Vector2(250, 52))
	var ex_row := HBoxContainer.new()
	ex.add_child(ex_row)
	var ex_title := Label.new()
	ex_title.text = "Example plans:"
	ex_row.add_child(ex_title)
	for which in ["good", "evil", "neutral", ""]:
		var b := Button.new()
		b.text = Examples.TITLES[which] if which != "" else "Starting city"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(load_city.bind(which))
		ex_row.add_child(b)

	var right := _panel(ui, Vector2(screen.x - 250, 10))
	right.custom_minimum_size = Vector2(240, 0)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 13)
	right.add_child(_stats)

	var story := _panel(ui, Vector2(screen.x - 250, 395))
	story.custom_minimum_size = Vector2(240, 0)
	_story = Label.new()
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.custom_minimum_size = Vector2(230, 0)
	_story.add_theme_font_size_override("font_size", 12)
	story.add_child(_story)

	_info = Label.new()
	_info.position = Vector2(250, screen.y - 104)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	_info.add_theme_font_size_override("font_size", 13)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_info)

	var help := Label.new()
	help.text = "WASD / right-drag: move   Wheel: zoom   Q/E: turn   R/F: tilt   Left: use tool   Space: pause growth   V: art style"
	help.position = Vector2(250, screen.y - 24)
	help.add_theme_font_size_override("font_size", 12)
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
	b.custom_minimum_size = Vector2(108, 0)
	b.add_theme_font_size_override("font_size", 13)
	parent.add_child(b)
	_tool_buttons[id] = b
