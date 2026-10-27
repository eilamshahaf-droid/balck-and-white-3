extends CanvasLayer
## Debug view (B): hover over a person to see who they are, and lines to
## their family (gold), friends (blue), home (green) and work (grey).
## The player never sees this; in the game people are read by how they act.

# Loaded at run time: a parse-time preload would load social_group.gd before
# its class_name is registered and break the typed groups array.
var _people: PeopleSettings = load("res://data/people.tres")
const FAMILY_COLOR := Color(1.0, 0.8, 0.2)
const FRIEND_COLOR := Color(0.4, 0.75, 1.0)
const HOME_COLOR := Color(0.4, 0.95, 0.45)
const WORK_COLOR := Color(0.75, 0.75, 0.75)
const CHEST := Vector3(0, 1.2, 0)
const STAGE_NAMES: Array[String] = ["Skeptic", "Curious", "Sympathizer", "Believer", "Zealot"]

var _shown: Resident
var _panel: PanelContainer
var _label: Label
var _lines := ImmediateMesh.new()
var _lines_node := MeshInstance3D.new()
var _refresh := 0.0

@onready var city: Node3D = get_parent()
@onready var population: Population = get_node("../Population")


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_label = Label.new()
	_panel.add_child(_label)
	add_child(_panel)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_lines_node.mesh = _lines
	_lines_node.material_override = mat
	_lines_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.add_child.call_deferred(_lines_node)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	_shown = null
	if city.show_belief:
		var cam := get_viewport().get_camera_3d()
		var ground: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
				cam.project_ray_origin(motion.position), cam.project_ray_normal(motion.position))
		if ground != null:
			_shown = population.resident_near(ground, _people.card_pick_radius)
	if _shown:
		_label.text = _describe(_shown)
		_panel.position = motion.position + Vector2(24, 24)
		_refresh = 0.0
	_panel.visible = _shown != null


func _process(delta: float) -> void:
	if not city.show_belief:
		_shown = null
		_panel.visible = false
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = _people.card_refresh
	_lines.clear_surfaces()
	if _shown == null or not is_instance_valid(_shown.body):
		return
	var from := _shown.body.global_position + CHEST
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for id in _shown.family:
		_line_to(from, population.residents[id], FAMILY_COLOR)
	for id in _shown.friends:
		_line_to(from, population.residents[id], FRIEND_COLOR)
	_line(from, _shown.home.global_position, HOME_COLOR)
	if _shown.work:
		_line(from, _shown.work.global_position, WORK_COLOR)
	_lines.surface_end()


## A line to `other`'s body, or to their home while they are indoors.
func _line_to(from: Vector3, other: Resident, color: Color) -> void:
	if is_instance_valid(other.body):
		_line(from, other.body.global_position + CHEST, color)
	else:
		_line(from, other.home.global_position, color)


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(a)
	_lines.surface_add_vertex(b)


func _describe(r: Resident) -> String:
	var work := "works near %s" % _corner(r.work) if r.work else "doesn't work"
	return "%s, %s\nLives near %s, %s\nFamily: %s\nFriends: %s\nBelief %+d%%   Skepticism %d%%" % [
		r.full_name(), r.group.title.to_lower(), _corner(r.home), work,
		_names(r.family, true), _names(r.friends, false),
		roundi(r.belief * 100.0), roundi(r.skepticism * 100.0)] \
		+ "\n%s   Wealth %d%%   Comfort %d%%   Fear %d%%" % [STAGE_NAMES[r.stage()],
				roundi(r.wealth * 100.0), roundi(r.comfort * 100.0), roundi(r.fear * 100.0)] \
		+ ("\nSitting in near %s" % _corner(r.occupying) if r.occupying else "")


func _corner(building: Node3D) -> String:
	var g: Vector2i = city.nearest_grid(building.global_position)
	return "Avenue %d & Street %d" % [g.x + 1, g.y + 1]


func _names(ids: Array[int], first_only: bool) -> String:
	if ids.is_empty():
		return "none"
	var out := PackedStringArray()
	for id in ids:
		var o: Resident = population.residents[id]
		out.append(o.first_name if first_only else o.full_name())
	return ", ".join(out)
