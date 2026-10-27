class_name Miracles
extends Node
## Casts the miracles: water, fire, roaches, money, block party, rain of frogs.
##
## Every miracle spends belief from the pool and is reported to the witnesses
## (faith.gd): this is the only way the god changes what people believe.
## A burning building is lost if it burns long enough, and saved, to its
## residents' awe, if water puts it out first.
##
## A miracle's power comes from the believers near the spot it is cast on:
## among them it is bigger, lasts longer and costs less; among skeptics it is
## small, short and dear. power_here is the power under the hand right now.

const M = preload("res://data/miracles.tres")
const B = preload("res://data/balance.tres")
const Sfx = preload("res://scripts/sfx.gd")
const RainScript = preload("res://scripts/rain.gd")
const FireScript = preload("res://scripts/fire.gd")
const RoachScript = preload("res://scripts/roaches.gd")
const MoneyScript = preload("res://scripts/money_rain.gd")
const PartyScript = preload("res://scripts/block_party.gd")
const FrogScript = preload("res://scripts/frog_rain.gd")
const DivineSign = preload("res://scripts/divine_sign.gd")

## A miracle was cast: `kind`, and the node that performs it.
signal miracle_cast(kind: StringName, miracle: Node3D)
## A miracle could not be cast: &"no_belief" or &"no_target".
signal miracle_failed(reason: StringName)
## A building burned out or was overrun by roaches or frogs: its people have
## left for good.
signal building_abandoned(building: Node3D)
## Water put out a burning building in time.
signal building_saved(building: Node3D)

const RAY_LENGTH := 3000.0
const LAYER_WORLD := 1
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
		{"id": &"roaches", "label": "Roaches", "color": Color(0.6, 0.42, 0.25), "cost": cost(&"roaches")},
		{"id": &"money", "label": "Money", "color": Color(0.55, 0.85, 0.45), "cost": cost(&"money")},
		{"id": &"party", "label": "Block Party", "color": Color(1.0, 0.45, 0.85), "cost": cost(&"party")},
		{"id": &"frogs", "label": "Rain of Frogs", "color": Color(0.4, 0.8, 0.3), "cost": cost(&"frogs")},
	]


## What `kind` costs at `power` (by default, the power under the hand).
func cost(kind: StringName, power := -1.0) -> float:
	if power < 0.0:
		power = power_here
	var scale := lerpf(M.weak_cost, M.strong_cost, power)
	match kind:
		&"water": return M.water_cost * scale
		&"fire": return M.fire_cost * scale
		&"roaches": return M.roach_cost * scale
		&"money": return M.money_cost * scale
		&"party": return M.party_cost * scale
		&"frogs": return M.frog_cost * scale
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
		&"roaches": miracle = _roaches(building, size, length)
		&"money": miracle = _money(ground, power, size, length)
		&"party": miracle = _party(ground, size, length)
		&"frogs": miracle = _frogs(ground, size, length)
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
		fire.burned_down.connect(_on_burned.bind(building))  # a burnt building stands empty
		fire.put_out.connect(_on_saved.bind(building, fire))
	fire.burn_time = M.fire_burn_time * length
	return fire


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


func _party(ground: Vector3, size: float, length: float) -> Node3D:
	var party: Node3D = PartyScript.new()
	city.add_child(party)
	party.start(ground, size, length)
	var dancers: Array = []
	var most := roundi(M.party_dancers * size)
	for c in _people_near(ground, M.party_radius * size):
		if dancers.size() < most and c.can_answer():
			dancers.append(c)
	for i in dancers.size():
		var spot: Vector3 = party.dance_spot(i, dancers.size())
		dancers[i].send_on_errand(spot, ground, M.party_time * length,
				M.party_lines[randi() % M.party_lines.size()], Color(1.0, 0.6, 0.9))
	faith.report(party, &"see_party", M.party_intensity, M.party_situation, M.party_time * length,
			true, M.party_deniability, dancers, M.party_seen_from)
	return party


## Chaos: people scatter or get knocked flat, a building under the frogs may be
## overrun (yours too), and the city reads it as a blessing or a curse, which
## nobody can tell beforehand.
func _frogs(ground: Vector3, size: float, length: float) -> Node3D:
	var frogs: Node3D = FrogScript.new()
	city.add_child(frogs)
	frogs.start(ground, size, length)
	var radius := M.frog_radius * size
	for c in _people_near(ground, radius):
		if randf() < M.frog_knock_chance:
			var away := Vector3(randf_range(-1.0, 1.0), 0.6, randf_range(-1.0, 1.0))
			c.knock_over(away.normalized() * M.frog_push)
		else:
			c.flee(c.global_position + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0)))
	for b in _buildings_near(ground, radius):
		if randf() < M.frog_overrun_chance:
			FloatingNote.pop(city, _roof(b), "Overrun by frogs!", Color(0.5, 0.9, 0.35))
			_abandon(b)
	var situation := randf_range(M.frog_situation_min, M.frog_situation_max)
	faith.report(frogs, &"see_frogs", M.frog_intensity, situation, M.frog_time * length, true,
			M.frog_deniability, [], M.frog_seen_from)
	return frogs


## Water put the fire out before the building was lost: its people saw the god
## save their home.
func _on_saved(building: Node3D, fire: Node3D) -> void:
	if not is_instance_valid(building) or fire.lost:
		return
	FloatingNote.pop(city, _roof(building), "Saved!", Color(1.0, 0.85, 0.3))
	var size := DivineSign.building_size(building)
	var helped: Array = fire.endangered.filter(func(c): return is_instance_valid(c))
	for c in _people_near(building.global_position, maxf(size.x, size.z) / 2.0 + 6.0):
		if not c in helped:
			helped.append(c)
	faith.report(fire, &"see_saved", M.saved_intensity, M.saved_situation, 3.0, true,
			M.saved_deniability, helped, M.saved_seen_from)
	building_saved.emit(building)


func _roof(building: Node3D) -> Vector3:
	return building.global_position + Vector3.UP * (DivineSign.building_size(building).y / 2.0 + 3.0)


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


func _buildings_near(p: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < radius:
			out.append(b)
	return out


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


func _people_near(p: Vector3, radius: float) -> Array:
	var out := []
	for c in get_tree().get_nodes_in_group("citizens"):
		if Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length() < radius:
			out.append(c)
	return out
