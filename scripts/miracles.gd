extends Node
## Casts the five prototype miracles: water, fire, lightning, shield, heal.
##
## Every miracle spends belief from the pool and is reported to the witnesses
## (faith.gd): this is the only way the god changes what people believe.
## Fire and lightning are harmful, so a shield stops them.
##
## A miracle's power comes from the believers near the spot it is cast on:
## among them it is bigger, lasts longer and costs less; among skeptics it is
## small, short and dear. power_here is the power under the hand right now.

const M = preload("res://data/miracles.tres")
const B = preload("res://data/balance.tres")
const Sfx = preload("res://scripts/sfx.gd")
const RainScript = preload("res://scripts/rain.gd")
const FireScript = preload("res://scripts/fire.gd")
const LightningScript = preload("res://scripts/lightning.gd")
const ShieldScript = preload("res://scripts/shield.gd")
const HealScript = preload("res://scripts/heal.gd")
const RoachScript = preload("res://scripts/roaches.gd")
const MoneyScript = preload("res://scripts/money_rain.gd")
const DivineSign = preload("res://scripts/divine_sign.gd")

## A miracle was cast: `kind`, and the node that performs it.
signal miracle_cast(kind: StringName, miracle: Node3D)
## A miracle could not be cast: &"no_belief", &"shielded" or &"no_target".
signal miracle_failed(reason: StringName)
## A building burned out or was overrun by roaches: its people have left for good.
signal building_abandoned(building: Node3D)

const RAY_LENGTH := 3000.0
const LAYER_WORLD := 1
const HARMFUL: Array[StringName] = [&"fire", &"lightning", &"roaches"]
const FIRE_SNAP := 15.0       # metres: water cast this close to a fire goes onto it
const BUILDING_SNAP := 3.0    # metres: fire cast this close to a building sets it alight

@export var population: Node
## Where money from the sky goes. Optional until the money system is in the scene.
@export var treasury: Treasury

@onready var faith: Node = get_node("../Faith")
@onready var rig: Node3D = get_node("../CameraRig")
@onready var city: Node3D = get_parent()
@onready var hand: Node3D = get_node("../GodHand")

## 0..1: the power of a miracle cast under the hand now (for the wheel and HUD).
var power_here := 0.0
var _power_timer := 0.0


## The wheel's slices, in order.
func wheel_items() -> Array[Dictionary]:
	return [
		{"id": &"water", "label": "Water", "color": Color(0.45, 0.7, 1.0), "cost": cost(&"water")},
		{"id": &"fire", "label": "Fire", "color": Color(1.0, 0.5, 0.2), "cost": cost(&"fire")},
		{"id": &"lightning", "label": "Lightning", "color": Color(0.85, 0.85, 1.0), "cost": cost(&"lightning")},
		{"id": &"shield", "label": "Shield", "color": Color(0.5, 0.95, 0.9), "cost": cost(&"shield")},
		{"id": &"heal", "label": "Heal", "color": Color(1.0, 0.85, 0.35), "cost": cost(&"heal")},
		{"id": &"roaches", "label": "Roaches", "color": Color(0.6, 0.42, 0.25), "cost": cost(&"roaches")},
		{"id": &"money", "label": "Money", "color": Color(0.55, 0.85, 0.45), "cost": cost(&"money")},
	]


## What `kind` costs at `power` (by default, the power under the hand).
func cost(kind: StringName, power := -1.0) -> float:
	if power < 0.0:
		power = power_here
	var scale := lerpf(M.weak_cost, M.strong_cost, power)
	match kind:
		&"water": return M.water_cost * scale
		&"fire": return M.fire_cost * scale
		&"lightning": return M.lightning_cost * scale
		&"shield": return M.shield_cost * scale
		&"heal": return M.heal_cost * scale
		&"roaches": return M.roach_cost * scale
		&"money": return M.money_cost * scale
	return 0.0


## 0..1: how much faith the believers around `p` lend a miracle there.
func power_at(p: Vector3) -> float:
	var sum := 0.0
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.belief > B.believer_threshold \
				and Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length() < M.power_radius:
			sum += c.belief
	return clampf(sum / M.full_power_belief, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_power_timer -= delta
	if _power_timer <= 0.0:
		_power_timer = M.power_update
		power_here = power_at(hand.global_position)
		hand.set_power(power_here)


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
	if kind == &"roaches" and building == null:
		building = _building_near(ground, BUILDING_SNAP)  # roaches need walls to come out of
		if building == null:
			miracle_failed.emit(&"no_target")
			return
	var power := power_at(ground)
	if not faith.spend(cost(kind, power)):
		miracle_failed.emit(&"no_belief")
		return
	var size := lerpf(M.weak_size, M.strong_size, power)
	var length := lerpf(M.weak_time, M.strong_time, power)
	var miracle: Node3D
	match kind:
		&"water": miracle = _water(ground, size, length)
		&"fire": miracle = _fire(ground, building, size, length)
		&"lightning": miracle = _lightning(ground, size)
		&"shield": miracle = _shield(ground, size, length)
		&"heal": miracle = _heal(ground, size, length)
		&"roaches": miracle = _roaches(building, size, length)
		&"money": miracle = _money(ground, power, size, length)
	miracle_cast.emit(kind, miracle)


func _water(ground: Vector3, size: float, length: float) -> Node3D:
	var fire := _burning_near(ground, FIRE_SNAP)
	if fire:
		ground = fire.global_position  # rain next to a fire was meant for the fire
	var rain: Node3D = RainScript.new()
	city.add_child(rain)
	rain.start(ground, size, length)
	Sfx.play(get_tree(), rain.global_position, &"chime", 0.6)
	faith.report(rain, &"see_rain", M.water_intensity, B.spectacle_situation, M.rain_time * length, true,
			M.water_deniability, rain.helped(), M.rain_seen_from)
	return rain


func _fire(ground: Vector3, building: Node3D, size: float, length: float) -> Node3D:
	if building == null:
		building = _building_near(ground, BUILDING_SNAP)  # fire at a wall's foot takes the building
	var fire: Node3D
	if building:
		fire = set_alight(building, length)
	else:
		fire = FireScript.new()
		city.add_child(fire)
		fire.ignite_spot(ground, M.street_fire_size * size)
		fire.burn_time = M.fire_burn_time * length
	faith.report(fire, &"see_fire", M.fire_intensity, M.fire_situation, 4.0, true,
			M.fire_deniability, [], M.fire_seen_from)
	return fire


## Set `building` on fire, or a burnt-out one again (the fire miracle's effect).
## `length` scales how long it burns.
func set_alight(building: Node3D, length := 1.0) -> Node3D:
	var fire := fire_on(building)
	if fire:
		fire.rekindle()  # the building stays charred
	else:
		fire = FireScript.new()
		city.add_child(fire)
		var size := DivineSign.building_size(building)
		fire.ignite(building, size)
		fire.endangered = _people_near(building.global_position, maxf(size.x, size.z) / 2.0 + 3.0)
		fire.extinguished.connect(_on_burned.bind(building))  # a burnt building stands empty
	fire.burn_time = M.fire_burn_time * length
	return fire


func _lightning(ground: Vector3, size: float) -> Node3D:
	var bolt: Node3D = LightningScript.new()
	city.add_child(bolt)
	bolt.strike(ground, size)
	faith.report(bolt, &"see_lightning", M.lightning_intensity, M.lightning_situation, 1.5, true,
			M.lightning_deniability, [], M.lightning_seen_from)
	return bolt


func _shield(ground: Vector3, size: float, length: float) -> Node3D:
	var shield: Node3D = ShieldScript.new()
	city.add_child(shield)
	shield.raise(ground, size, length)
	faith.report(shield, &"see_shield", M.shield_intensity, M.shield_situation, M.shield_time * length, true,
			M.shield_deniability, shield.helped(), M.shield_seen_from)
	return shield


func _heal(ground: Vector3, size: float, length: float) -> Node3D:
	var heal: Node3D = HealScript.new()
	city.add_child(heal)
	var helped: Array = heal.bless(ground, size, length)
	faith.report(heal, &"see_heal", M.heal_intensity, M.heal_situation, M.heal_time * length, true,
			M.heal_deniability, helped, M.heal_seen_from)
	return heal


func _roaches(building: Node3D, size: float, length: float) -> Node3D:
	var swarm: Node3D = RoachScript.new()
	city.add_child(swarm)
	swarm.infest(building, size, length)
	faith.report(swarm, &"see_roaches", M.roach_intensity, M.roach_situation, M.roach_time * length, true,
			M.roach_deniability, [], M.roach_seen_from)
	_abandon(building)
	return swarm


func _money(ground: Vector3, power: float, size: float, length: float) -> Node3D:
	var notes: Node3D = MoneyScript.new()
	city.add_child(notes)
	notes.start(ground, size, length)
	# Your believers pick the notes up and hand them in; strangers keep theirs.
	if treasury:
		treasury.add_money(M.money_amount * lerpf(M.money_weak_share, 1.0, power))
	faith.report(notes, &"see_money", M.money_intensity, M.money_situation, M.money_time * length, true,
			M.money_deniability, _people_near(ground, M.money_radius * size), M.money_seen_from)
	return notes


func _on_burned(building: Node3D) -> void:
	if is_instance_valid(building):
		_abandon(building)


func _abandon(building: Node3D) -> void:
	population.evacuate(building)
	building_abandoned.emit(building)


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


func _burning_near(p: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for fire in get_tree().get_nodes_in_group("fires"):
		var d := Vector2(fire.global_position.x - p.x, fire.global_position.z - p.z).length()
		if fire.is_burning() and d < best_d:
			best_d = d
			best = fire
	return best


func _building_near(p: Vector3, margin: float) -> Node3D:
	for b in get_tree().get_nodes_in_group("buildings"):
		var half := DivineSign.building_size(b) / 2.0 + Vector3.ONE * margin
		var d: Vector3 = (p - b.global_position).abs()
		if d.x < half.x and d.z < half.z:
			return b
	return null


## The fire on `building`, burning or burnt out (null if it never burned).
func fire_on(building: Node3D) -> Node3D:
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
