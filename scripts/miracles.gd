extends Node
## Casts the five prototype miracles: water, fire, lightning, shield, heal.
##
## Every miracle spends belief from the pool and is reported to the witnesses
## (faith.gd): this is the only way the god changes what people believe.
## Fire and lightning are harmful, so a shield stops them.

const M = preload("res://data/miracles.tres")
const B = preload("res://data/balance.tres")
const Sfx = preload("res://scripts/sfx.gd")
const RainScript = preload("res://scripts/rain.gd")
const FireScript = preload("res://scripts/fire.gd")
const LightningScript = preload("res://scripts/lightning.gd")
const ShieldScript = preload("res://scripts/shield.gd")
const HealScript = preload("res://scripts/heal.gd")
const DivineSign = preload("res://scripts/divine_sign.gd")

## A miracle was cast: `kind`, and the node that performs it.
signal miracle_cast(kind: StringName, miracle: Node3D)
## A miracle could not be cast: &"no_belief", &"shielded" or &"no_target".
signal miracle_failed(reason: StringName)

const RAY_LENGTH := 3000.0
const LAYER_WORLD := 1
const HARMFUL: Array[StringName] = [&"fire", &"lightning"]

@onready var faith: Node = get_node("../Faith")
@onready var rig: Node3D = get_node("../CameraRig")
@onready var city: Node3D = get_parent()


## The wheel's slices, in order.
func wheel_items() -> Array[Dictionary]:
	return [
		{"id": &"water", "label": "Water", "color": Color(0.45, 0.7, 1.0), "cost": M.water_cost},
		{"id": &"fire", "label": "Fire", "color": Color(1.0, 0.5, 0.2), "cost": M.fire_cost},
		{"id": &"lightning", "label": "Lightning", "color": Color(0.85, 0.85, 1.0), "cost": M.lightning_cost},
		{"id": &"shield", "label": "Shield", "color": Color(0.5, 0.95, 0.9), "cost": M.shield_cost},
		{"id": &"heal", "label": "Heal", "color": Color(1.0, 0.85, 0.35), "cost": M.heal_cost},
	]


func cost(kind: StringName) -> float:
	match kind:
		&"water": return M.water_cost
		&"fire": return M.fire_cost
		&"lightning": return M.lightning_cost
		&"shield": return M.shield_cost
		&"heal": return M.heal_cost
	return 0.0


## Cast `kind` at the spot under `screen_pos`. Water aimed near a fire (within
## `screen_radius` pixels) goes onto the fire: that is what the god meant.
func cast_at_screen(kind: StringName, screen_pos: Vector2, screen_radius := 40.0) -> void:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_pos) * RAY_LENGTH, LAYER_WORLD)
	query.exclude = rig.faded_rids()
	var hit := city.get_world_3d().direct_space_state.intersect_ray(query)
	var building: Node3D = hit.collider if hit and hit.collider.is_in_group("buildings") else null
	var target: Vector3 = hit.position if hit else Vector3.INF
	if kind == &"water":
		var fire := _fire_near(camera, screen_pos, screen_radius * 1.3)
		if fire:
			target = fire.global_position
	if target == Vector3.INF:
		miracle_failed.emit(&"no_target")
		return
	cast(kind, target, building)


## Cast `kind` at `ground`; `building` is the building there, if any.
func cast(kind: StringName, ground: Vector3, building: Node3D) -> void:
	if kind in HARMFUL and _shield_over(ground):
		Sfx.play(get_tree(), ground, &"hum", 0.8)
		miracle_failed.emit(&"shielded")
		return
	if not faith.spend(cost(kind)):
		miracle_failed.emit(&"no_belief")
		return
	var miracle: Node3D
	match kind:
		&"water": miracle = _water(ground)
		&"fire": miracle = _fire(ground, building)
		&"lightning": miracle = _lightning(ground)
		&"shield": miracle = _shield(ground)
		&"heal": miracle = _heal(ground)
	miracle_cast.emit(kind, miracle)


func _water(ground: Vector3) -> Node3D:
	var rain: Node3D = RainScript.new()
	city.add_child(rain)
	rain.start(ground)
	Sfx.play(get_tree(), rain.global_position, &"chime", 0.6)
	faith.report(rain, &"see_rain", M.water_intensity, B.spectacle_situation, M.rain_time, true,
			M.water_deniability, rain.helped(), M.rain_seen_from)
	return rain


func _fire(ground: Vector3, building: Node3D) -> Node3D:
	var fire: Node3D = _fire_on(building) if building else null
	if fire:
		fire.rekindle()  # a burnt-out building catches again
	else:
		fire = FireScript.new()
		city.add_child(fire)
		if building:
			var size := DivineSign.building_size(building)
			fire.ignite(building, size)
			fire.endangered = _people_near(building.global_position, maxf(size.x, size.z) / 2.0 + 3.0)
		else:
			fire.ignite_spot(ground, M.street_fire_size)
	fire.burn_time = M.fire_burn_time
	faith.report(fire, &"see_fire", M.fire_intensity, M.fire_situation, 4.0, true,
			M.fire_deniability, [], M.fire_seen_from)
	return fire


func _lightning(ground: Vector3) -> Node3D:
	var bolt: Node3D = LightningScript.new()
	city.add_child(bolt)
	bolt.strike(ground)
	faith.report(bolt, &"see_lightning", M.lightning_intensity, M.lightning_situation, 1.5, true,
			M.lightning_deniability, [], M.lightning_seen_from)
	return bolt


func _shield(ground: Vector3) -> Node3D:
	var shield: Node3D = ShieldScript.new()
	city.add_child(shield)
	shield.raise(ground)
	faith.report(shield, &"see_shield", M.shield_intensity, M.shield_situation, M.shield_time, true,
			M.shield_deniability, shield.helped(), M.shield_seen_from)
	return shield


func _heal(ground: Vector3) -> Node3D:
	var heal: Node3D = HealScript.new()
	city.add_child(heal)
	var helped: Array = heal.bless(ground)
	faith.report(heal, &"see_heal", M.heal_intensity, M.heal_situation, M.heal_time, true,
			M.heal_deniability, helped, M.heal_seen_from)
	return heal


func _fire_near(camera: Camera3D, screen_pos: Vector2, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire.is_burning() and not camera.is_position_behind(fire.global_position):
			var d := camera.unproject_position(fire.global_position).distance_to(screen_pos)
			if d < best_d:
				best_d = d
				best = fire
	return best


func _fire_on(building: Node3D) -> Node3D:
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire.building == building:
			return fire
	return null


func _shield_over(p: Vector3) -> bool:
	for shield in get_tree().get_nodes_in_group("shields"):
		if shield.covers(p):
			return true
	return false


func _people_near(p: Vector3, radius: float) -> Array:
	var out := []
	for c in get_tree().get_nodes_in_group("citizens"):
		if Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length() < radius:
			out.append(c)
	return out
