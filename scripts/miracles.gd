class_name Miracles
extends Node
## Casts the miracles: water, money, block party, rain of frogs.
##
## Every miracle spends paperwork from the pool (until miracles get their own stock) and
## is reported to the witnesses (faith.gd), who react to it. A miracle never touches a
## building: it works on people and the street (a crowd gathers, people dance, banknotes
## fall). Casting one again soon costs more, and each needs a moment before the next.
##
## A miracle's power comes from the believers near the spot it is cast on:
## among them it is bigger, lasts longer and costs less; among skeptics it is
## small, short and dear. power_here is the power under the hand right now.

const M = preload("res://data/miracles.tres")
const B = preload("res://data/balance.tres")
const Sfx = preload("res://scripts/sfx.gd")
const RainScript = preload("res://scripts/rain.gd")
const MoneyScript = preload("res://scripts/money_rain.gd")
const PartyScript = preload("res://scripts/block_party.gd")
const FrogScript = preload("res://scripts/frog_rain.gd")

## A miracle was cast: `kind`, and the node that performs it.
signal miracle_cast(kind: StringName, miracle: Node3D)
## A miracle could not be cast: &"no_belief", &"cooling" or &"no_target".
signal miracle_failed(reason: StringName)
const RAY_LENGTH := 3000.0
const LAYER_WORLD := 1

## Where money from the sky goes. Optional until the money system is in the scene.
@export var treasury: Treasury
@export var districts: Districts

@onready var faith: Faith = get_node("../Faith")
@onready var rig: Node3D = get_node("../CameraRig")
@onready var city: Node3D = get_parent()
@onready var hand: Node3D = get_node("../GodHand")

## 0..1: the power of a miracle cast under the hand now (for the wheel and HUD).
var power_here := 0.0
var _power_timer := 0.0
var _proof := MiracleProof.new()


## The wheel's slices, in order.
func wheel_items() -> Array[Dictionary]:
	var all: Array[Dictionary] = [
		{"id": &"water", "label": "Water", "color": Color(0.45, 0.7, 1.0), "cost": cost(&"water")},
		{"id": &"money", "label": "Money", "color": Color(0.55, 0.85, 0.45), "cost": cost(&"money")},
		{"id": &"party", "label": "Block Party", "color": Color(1.0, 0.45, 0.85), "cost": cost(&"party")},
		{"id": &"frogs", "label": "Rain of Frogs", "color": Color(0.4, 0.8, 0.3), "cost": cost(&"frogs")},
	]
	return all.filter(func(item: Dictionary) -> bool: return M.is_offered(item.id))


## What `kind` costs at `power` (by default, the power under the hand).
func cost(kind: StringName, power := -1.0) -> float:
	if power < 0.0:
		power = power_here
	var scale := lerpf(M.weak_cost, M.strong_cost, power) * _proof.cost_scale(kind)
	match kind:
		&"water": return M.water_cost * scale
		&"money": return M.money_cost * scale
		&"party": return M.party_cost * scale
		&"frogs": return M.frog_cost * scale
	return 0.0


## 0..1: how much faith the believers around `p` lend a miracle there.
func power_at(p: Vector3) -> float:
	var sum := 0.0
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.resident.is_believer() \
				and Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length() < M.power_radius:
			sum += 1.0
	return clampf(sum / M.full_power_belief, 0.0, 1.0)


## The proof miracles left at `p`: a preacher's chance there is (1 + this) times
## as high. Can be negative where a miracle went badly.
func proof_at(p: Vector3) -> float:
	return _proof.proof_at(p)


## Seconds until `kind` can be cast again (0: ready).
func ready_in(kind: StringName) -> float:
	return _proof.ready_in(kind)


func _physics_process(delta: float) -> void:
	_proof.tick(delta)
	_power_timer -= delta
	if _power_timer <= 0.0:
		_power_timer = M.power_update
		power_here = power_at(hand.global_position)
		hand.set_power(power_here)


## Cast `kind` at the spot under `screen_pos`.
func cast_at_screen(kind: StringName, screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_pos) * RAY_LENGTH, LAYER_WORLD)
	query.exclude = rig.faded_rids()
	var hit := city.get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.position if hit else Vector3.INF
	if target == Vector3.INF:
		miracle_failed.emit(&"no_target")
		return
	cast(kind, target)


## Cast `kind` at `ground`.
func cast(kind: StringName, ground: Vector3) -> void:
	if _proof.ready_in(kind) > 0.0:
		miracle_failed.emit(&"cooling")
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
		&"money": miracle = _money(ground, power, size, length)
		&"party": miracle = _party(ground, size, length)
		&"frogs": miracle = _frogs(ground, size, length)
	_proof.used(kind, _cooldown(kind))
	if kind != &"frogs":  # the frogs decide their own proof
		_proof.leave(miracle.global_position, M.proof_radius * size, _proof_strength(kind))
	miracle_cast.emit(kind, miracle)


func _cooldown(kind: StringName) -> float:
	match kind:
		&"water": return M.water_cooldown
		&"money": return M.money_cooldown
		&"party": return M.party_cooldown
		&"frogs": return M.frog_cooldown
	return 0.0


func _proof_strength(kind: StringName) -> float:
	match kind:
		&"water": return M.water_proof
		&"money": return M.money_proof
		&"party": return M.party_proof
	return 0.0


func _water(ground: Vector3, size: float, length: float) -> Node3D:
	var rain: Node3D = RainScript.new()
	city.add_child(rain)
	rain.start(ground, size, length)
	Sfx.play(get_tree(), rain.global_position, &"chime", 0.6)
	faith.report(rain, &"see_rain", M.water_intensity, B.spectacle_situation, M.rain_time * length, true,
			M.water_deniability, rain.helped(), M.rain_seen_from)
	return rain


func _money(ground: Vector3, power: float, size: float, length: float) -> Node3D:
	var notes: Node3D = MoneyScript.new()
	city.add_child(notes)
	notes.start(ground, size, length)
	# Your believers pick the notes up and hand them in; strangers keep theirs.
	if treasury:
		var amount := M.money_amount * lerpf(M.money_weak_share, 1.0, power)
		if districts and _buildings_near(ground, M.money_radius * size).any(districts.owns):
			amount *= M.money_own_multiplier
		treasury.add_money(amount)
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
				M.party_lines[randi() % M.party_lines.size()], Color(1.0, 0.6, 0.9), true)
	faith.report(party, &"see_party", M.party_intensity, M.party_situation, M.party_time * length,
			true, M.party_deniability, dancers, M.party_seen_from)
	return party


## Chaos: a crowd gathers to gawk and some get knocked flat, a building under
## the frogs may be overrun (yours too), and the city reads it as a blessing or
## a curse, which nobody can tell beforehand.
func _frogs(ground: Vector3, size: float, length: float) -> Node3D:
	var frogs: Node3D = FrogScript.new()
	city.add_child(frogs)
	frogs.start(ground, size, length)
	var radius := M.frog_radius * size
	for c in _people_near(ground, radius):
		if randf() < M.frog_knock_chance:
			var away := Vector3(randf_range(-1.0, 1.0), 0.6, randf_range(-1.0, 1.0))
			c.knock_over(away.normalized() * M.frog_push)
	var gawkers: Array = []
	var most := roundi(M.frog_gawkers * size)
	for c in _people_near(ground, M.frog_gather_radius * size):
		if gawkers.size() < most and c.can_answer():
			gawkers.append(c)
	for c in gawkers:
		var a := randf() * TAU
		var spot := ground + Vector3(cos(a), 0.0, sin(a)) * radius * randf_range(0.6, 1.0)
		c.send_on_errand(spot, ground, M.frog_time * length,
				M.frog_lines[randi() % M.frog_lines.size()], Color(0.6, 0.95, 0.45))
	var luck := randf()
	var situation := lerpf(M.frog_situation_min, M.frog_situation_max, luck)
	_proof.leave(ground, M.proof_radius * size, lerpf(M.frog_proof_min, M.frog_proof_max, luck))
	faith.report(frogs, &"see_frogs", M.frog_intensity, situation, M.frog_time * length, true,
			M.frog_deniability, [], M.frog_seen_from)
	return frogs


func _buildings_near(p: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < radius:
			out.append(b)
	return out


func _people_near(p: Vector3, radius: float) -> Array:
	var out := []
	for c in get_tree().get_nodes_in_group("citizens"):
		if Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length() < radius:
			out.append(c)
	return out
