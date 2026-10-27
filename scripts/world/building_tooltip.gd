class_name BuildingTooltip
extends Label
## Follows the cursor and says what the building under it is: its kind, how many
## people live there and how many believe, and what it earns when it is yours.
## A district's core building says so.

const S: DistrictSettings = preload("res://data/districts.tres")
const RAY_LENGTH := 2000.0

@export var districts: Districts
@export var treasury: Treasury
@export var decrees: Decrees
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
	if hit and hit.collider is Node3D and (hit.collider as Node3D).is_in_group("buildings"):
		return hit.collider
	return null


func _describe(building: Node3D) -> String:
	var i := districts.index_of(building)
	if i < 0:
		return ""
	var use := decrees.use_of(building)
	var kind := use if use != "" else ("Apartments" if districts.residents_in(i) > 0 else "Empty building")
	var d := districts.district_at(building.global_position)
	var lines := PackedStringArray()
	lines.append("%s%s" % [kind, "  (core of %s)" % districts.district_name(d) if districts.core_of(d) == i else ""])
	lines.append("%d residents, %d believe" % [districts.residents_in(i), districts.believers_at(i)])
	if districts.is_yours(i):
		var net := treasury.net_of(building)
		lines.append("Yours: %s $%.1f/s" % ["earns" if net >= 0.0 else "costs", absf(net)])
	else:
		lines.append("Not yours")
	return "\n".join(lines)
