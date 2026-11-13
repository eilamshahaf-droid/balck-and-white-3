class_name BuildingTooltip
extends Label
## Follows the cursor and says what the building under it is: its kind, how many
## people live there and how many of them believe ("X of Y", from Population), its staff,
## what it yields and what it earns when it is yours.
## A district's core building says so.

const S: DistrictSettings = preload("res://data/districts.tres")
const RAY_LENGTH := 2000.0

@export var districts: Districts
@export var followers: Followers
@export var decrees: Decrees
@export var population: Population
@export var camera: Camera3D

var _timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		if followers.has_shop(i):
			lines.append("Sellers %d of %d" % [followers.sellers_in(i), followers.shop_slots(i)])
	elif districts.is_key(i):
		lines[0] = districts.key_name(i)
		lines.append("Key building: inspectors come from here")
		lines.append("It will take more than a Rep")
	elif districts.wants_you(i) and districts.can_claim(i):
		lines.append("Wants you: set a Rep down here to manage it")
	elif not districts.borders_yours(i):
		lines.append("Too far: it must border a building of yours")
	elif not districts.can_claim(i):
		lines.append("Take the buildings around it first")
	elif districts.meter_of(i) > 0.0:
		lines.append("Takeover %d%%: keep a Rep at its door" % floori(districts.meter_of(i) * 100.0))
	else:
		lines.append("Set a Rep down at its door to take it")
	return "\n".join(lines)
