class_name PoliceArrests
extends Node3D
## The police arrest the Vandalist (Murals calls arrest after the neighbourhood
## answers a mural). A squad surrounds him and he stands still, and from then on he
## is a martyr: people near the spot side with him for a while (Awareness). Three ways
## out: throw the officers off him with the hand or scatter them with a miracle (costs
## belief), pay bail once he is taken, or wait until jail lets him go.

## A squad surrounds `agent`; `where` is on the street, for the alert.
signal arrest_started(agent: Resident, where: Vector3)
## The squad is gone from `agent`: he got away (`freed`), or time ran out and he is taken.
signal arrest_ended(agent: Resident, freed: bool)
## `agent` is out of jail (bail or time served).
signal released(agent: Resident)

const S: PoliceSettings = preload("res://data/police.tres")
const A: AwarenessSettings = preload("res://data/awareness.tres")

@export var population: Population
@export var districts: Districts
@export var awareness: Awareness
@export var faith: Faith
@export var treasury: Treasury

## The agents in jail, soonest out first.
var jailed: Array[Resident] = []

var _squads: Array[Squad] = []
var _timer := 0.0
var _uniform := _mat(S.uniform_color)
var _skin := _mat(S.skin_color)


class Squad:
	var agent: Resident
	var officers: Array[PoliceOfficer] = []
	var left := 0.0
	var marker: Label3D


## Is an arrest going on for `agent`?
func is_arresting(agent: Resident) -> bool:
	for squad in _squads:
		if squad.agent == agent:
			return true
	return false


## Seconds left before the agent is taken, for the HUD alert (0 with none going on).
func seconds_left() -> float:
	return _squads[0].left if not _squads.is_empty() else 0.0


## Where the arrest is, or Vector3.INF with none going on.
func where() -> Vector3:
	if _squads.is_empty() or _squads[0].agent.body == null:
		return Vector3.INF
	return _squads[0].agent.body.global_position


## Send a squad after `agent`. False when he has no body on the street or is already held.
func arrest(agent: Resident) -> bool:
	if agent.body == null or is_arresting(agent):
		return false
	var squad := Squad.new()
	squad.agent = agent
	squad.left = S.arrest_time
	var centre := agent.body.global_position
	for i in S.officers:
		var officer := PoliceOfficer.new()
		add_child(officer)
		officer.build(_uniform, _skin, S.officer_mass)
		var angle := TAU * i / S.officers
		officer.global_position = centre + Vector3(cos(angle), 0.0, sin(angle)) * S.ring_radius
		officer.rotation.y = -angle - PI / 2.0
		squad.officers.append(officer)
	squad.marker = Label3D.new()
	squad.marker.text = "ARREST!"
	squad.marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	squad.marker.no_depth_test = true
	squad.marker.font_size = 64
	squad.marker.outline_size = 16
	squad.marker.pixel_size = S.label_size * 2.0
	squad.marker.modulate = S.stripe_color.lightened(0.3)
	squad.marker.position = Vector3(0.0, 4.0, 0.0)
	agent.body.add_child(squad.marker)
	_squads.append(squad)
	var near := districts.building_near(centre)
	if near >= 0:
		awareness.add_martyr(districts.buildings[near])
	arrest_started.emit(agent, centre)
	return true


## Pay bail for the agent who has been in jail longest. False without one or the money.
func bail() -> bool:
	if jailed.is_empty() or not treasury.spend_money(A.bail_money):
		return false
	_release(jailed[0])
	return true


## Seconds before the next jailed agent is let go (0 with nobody in jail).
func jail_left() -> float:
	return jailed[0].jailed_left if not jailed.is_empty() else 0.0


## A miracle goes off at `point`: officers within `radius` are thrown clear.
func scatter_near(point: Vector3, radius: float) -> void:
	for squad in _squads:
		for officer in squad.officers:
			if is_instance_valid(officer) and officer.global_position.distance_to(point) <= radius:
				officer.sleeping = false
				var away := officer.global_position - point
				away.y = 0.0
				officer.apply_central_impulse((away.normalized() + Vector3.UP) * S.scatter_impulse)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var step := maxf(S.arrest_tick, delta)
	_timer = S.arrest_tick
	for squad in _squads.duplicate():
		_tend(squad, step)
	for agent in jailed.duplicate():
		agent.jailed_left -= step
		if agent.jailed_left <= 0.0:
			_release(agent)


func _release(agent: Resident) -> void:
	jailed.erase(agent)
	agent.jailed_left = 0.0
	if agent.alive:
		population.bring_out(agent)
	released.emit(agent)


func _tend(squad: Squad, step: float) -> void:
	var body := squad.agent.body
	if body == null or not is_instance_valid(body):
		_finish(squad, true, false)
		return
	if body.state == Citizen.State.WALKING:
		body.idle = true
	var near := 0
	for officer in squad.officers:
		if is_instance_valid(officer) and officer.global_position.distance_to(body.global_position) <= S.free_distance:
			near += 1
	if near == 0:
		_finish(squad, true)
		return
	squad.left -= step
	if squad.left <= 0.0:
		_finish(squad, false)


## `rescued`: the hand or a miracle got the officers off him, which costs belief.
func _finish(squad: Squad, freed: bool, rescued := true) -> void:
	_squads.erase(squad)
	var body := squad.agent.body
	if is_instance_valid(body):
		body.idle = false
		if is_instance_valid(squad.marker):
			squad.marker.queue_free()
	for officer in squad.officers:
		if is_instance_valid(officer):
			officer.queue_free()
	if freed and rescued:
		faith.spend(minf(A.rescue_belief, faith.belief_pool))
	else:
		_jail(squad.agent)
	arrest_ended.emit(squad.agent, freed)


func _jail(agent: Resident) -> void:
	agent.jailed_left = A.jail_seconds
	jailed.append(agent)
	population.put_away(agent)


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
