class_name PoliceArrests
extends Node3D
## The police try to arrest the preaching priest. A squad surrounds him and he
## stands still; the player frees him by getting the officers away (pick them
## up and throw them, or a miracle scatters them). If the squad is still around
## him when the time runs out, he is taken. Whoever decides that an arrest
## happens (the priest's sermon, via Sermons.police_moved_in) calls `arrest`.

## A squad surrounds `priest`; `where` is on the street, for the alert.
signal arrest_started(priest: Resident, where: Vector3)
## The squad is gone from `priest`: he got away (`freed`), or time ran out and he is taken.
## Sermons releases him on this too (end_sermon).
signal arrest_ended(priest: Resident, freed: bool)

const S: PoliceSettings = preload("res://data/police.tres")

var _squads: Array[Squad] = []
var _timer := 0.0
var _uniform := _mat(S.uniform_color)
var _skin := _mat(S.skin_color)


class Squad:
	var priest: Resident
	var officers: Array[PoliceOfficer] = []
	var left := 0.0
	var marker: Label3D


## Is an arrest going on for `priest`?
func is_arresting(priest: Resident) -> bool:
	for squad in _squads:
		if squad.priest == priest:
			return true
	return false


## Seconds left before the priest is taken, for the HUD alert (0 with none going on).
func seconds_left() -> float:
	return _squads[0].left if not _squads.is_empty() else 0.0


## Where the arrest is, or Vector3.INF with none going on.
func where() -> Vector3:
	if _squads.is_empty() or _squads[0].priest.body == null:
		return Vector3.INF
	return _squads[0].priest.body.global_position


## Send a squad after `priest`. False when he has no body on the street or is already held.
func arrest(priest: Resident) -> bool:
	if priest.body == null or is_arresting(priest):
		return false
	var squad := Squad.new()
	squad.priest = priest
	squad.left = S.arrest_time
	var centre := priest.body.global_position
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
	priest.body.add_child(squad.marker)
	_squads.append(squad)
	arrest_started.emit(priest, centre)
	return true


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


func _tend(squad: Squad, step: float) -> void:
	var body := squad.priest.body
	if body == null or not is_instance_valid(body):
		_finish(squad, true)
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


func _finish(squad: Squad, freed: bool) -> void:
	_squads.erase(squad)
	var body := squad.priest.body
	if is_instance_valid(body):
		body.idle = false
		if is_instance_valid(squad.marker):
			squad.marker.queue_free()
	for officer in squad.officers:
		if is_instance_valid(officer):
			officer.queue_free()
	arrest_ended.emit(squad.priest, freed)


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
