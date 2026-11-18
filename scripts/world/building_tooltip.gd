class_name BuildingTooltip
extends Label
## Follows the cursor and says what the building under it is: its kind, how many
## people live there and how many of them believe ("X of Y", from Population), its staff,
## what it yields and what it earns when it is yours. People work where they live, so
## desks and shop places with nobody living there to fill them say so (the housing rule).
## A building you could take shows the impression your buildings make on it.
## A district's core building says so.

const S: DistrictSettings = preload("res://data/districts.tres")
const RAY_LENGTH := 2000.0

@export var districts: Districts
@export var followers: Followers
@export var decrees: Decrees
@export var population: Population
@export var camera: Camera3D
@export var impression: Impression

var _timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"TagLabel"
	visible = false


func _process(delta: float) -> void:
	_timer -= delta
	var mouse := get_viewport().get_mouse_position()
	position = mouse + S.tooltip_offset
	if _timer > 0.0:
		return
	_timer = S.tooltip_interval
	var building := _building_under(mouse)
	if building == null:
		visible = false
		return
	var line := _describe(building)
	if text != line:
		text = line
	visible = true


func _building_under(mouse: Vector2) -> Node3D:
	var from := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
			from, from + camera.project_ray_normal(mouse) * RAY_LENGTH, 1)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit and BuildingBox.building_of(hit.collider):
		return BuildingBox.building_of(hit.collider)
	return null


func _describe(building: Node3D) -> String:
	var i := districts.index_of(building)
	if i < 0:
		return ""
	var use := decrees.use_of(building)
	var kind := "The Office" if districts.is_base(building) else (use if use != "" else "Homes")
	var d := districts.district_at(building.global_position)
	var lines := PackedStringArray()
	lines.append("%s%s" % [kind, "  (core of %s)" % districts.district_name(d) if districts.core_of(d) == i else ""])
	if districts.is_yours(i):
		var manager := population.manager_of(building)
		if manager:
			lines.append("Manager: " + manager.full_name())
		lines.append("Followers %d of %d" % [followers.count_of(i), followers.room_of(i)])
		var desks := followers.desks_in(i)
		if desks > 0:
			lines.append(_staffed("Clerks", followers.clerks_in(i), desks, followers.clerks_in(i)))
		if followers.has_shop(i):
			lines.append(_staffed("Sellers", followers.sellers_in(i), followers.shop_slots(i),
					followers.sellers_possible(i)))
	elif districts.is_key(i):
		lines[0] = districts.key_name(i)
		lines.append("Key building: inspectors come from here")
		lines.append("Open: send a Rep to take it" if districts.is_key_open(i)
				else "The Fixer must open it before a Rep can take it")
	elif districts.wants_you(i) and districts.can_claim(i):
		lines.append("Wants you: set a Rep down here to manage it")
	elif not districts.can_claim(i):
		lines.append("Out of reach: more followers reach further")
	else:
		var have := impression.of(i)
		var need := impression.required(districts.district_of(i))
		lines.append("Impression %d of %d" % [floori(have), ceili(need)])
		if have < need:
			lines.append("Fit homes or shops in your buildings near it")
		elif districts.meter_of(i) > 0.0:
			lines.append("Takeover %d%%: keep a Rep at its door" % floori(districts.meter_of(i) * 100.0))
		else:
			lines.append("Set a Rep down at its door to take it")
	return "\n".join(lines)


## "Clerks 2 of 4", and when fewer live here than there are places (`possible`), that
## people work where they live.
static func _staffed(what: String, working: int, places: int, possible: int) -> String:
	var line := "%s %d of %d" % [what, working, places]
	return line + ": needs homes here" if possible < places else line
