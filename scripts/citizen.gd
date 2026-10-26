extends CharacterBody3D
## The body of a city resident: walks between intersections near home,
## falls, gets up, stares at miracles. Who the person is (name, home, family,
## belief) lives on the Resident record, so it outlasts this body.
##
## Belief is hidden from the player. A miracle can push it toward faith or
## toward skepticism, depending on what the miracle did to this person, on a
## personal coefficient (skepticism) the player never sees, and on how many
## times they have seen that kind of miracle before (see balance.gd).

enum State { WALKING, HELD, FALLING, DOWN, GETTING_UP }

const UPRIGHT := Quaternion.IDENTITY
const B = preload("res://data/balance.tres")
const P: PeopleSettings = preload("res://data/people.tres")

var city: Node3D
## Used by the god's hand: heavier things lag and swing more when held.
var mass := 1.0
var fall_gravity := P.gravity
var grid := Vector2i.ZERO
var state := State.WALKING
var speed := 3.0
var target := Vector3.ZERO
var lane_offset := Vector3.ZERO

## Population hands every resident's body its record before adding it. A body
## spawned without one (a passer-by, an inspector) keeps this anonymous record.
var resident := Resident.new()
## Hidden: -1 = total skeptic, +1 = devoted believer.
var belief: float:
	get:
		return resident.belief
	set(value):
		resident.belief = value
## Hidden personal coefficient k: 0 believes easily, 1 always finds a rational explanation.
var skepticism: float:
	get:
		return resident.skepticism
	set(value):
		resident.skepticism = value
var has_phone: bool:
	get:
		return resident.has_phone
	set(value):
		resident.has_phone = value
## The corner nearest home: people wander around it.
var home := Vector2i.ZERO
## Stand still (watching a fire, waiting on a roof) instead of walking the grid.
var idle := false
## Story moments can fix how this person explains the next miracle (&"god", &"fraud", ...).
var scripted_explanation := &""
## Answering a divine sign: walking to a building, or standing at it.
var on_errand := false
## On an errand and already standing at the spot.
var errand_arrived := false

var _body: MeshInstance3D
var _own_mat := StandardMaterial3D.new()
var _debug_mat := StandardMaterial3D.new()
var _fall_speed := 0.0
var _pause := 0.0
var _spin := Vector3.ZERO      # tumble while flying, radians per second around this axis
var _down_timer := 0.0
var _lying := Quaternion.IDENTITY
var _seen := {}             # miracle kind -> times seen
var _events_seen := {}     # ids of miracle events already reacted to
var _phone: MeshInstance3D
var _phone_timer := 0.0
var _look_at_target := Vector3.INF   # where a witness stares while stopped
var _bubble: Label3D
var _bubble_timer := 0.0
var _errand_route: Array[Vector3] = []
var _errand_time := 0.0
var _errand_line := ""
var _errand_color := Color.WHITE
var _errand_face := Vector3.ZERO
var _errand_say := 0.0


func _ready() -> void:
	add_to_group("citizens")
	add_to_group("god_grabbable")

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	_body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.8
	_body.mesh = mesh
	_body.position.y = 0.9
	_own_mat.albedo_color = Color.from_hsv(randf(), 0.45, 0.85)
	_body.material_override = _own_mat
	add_child(_body)

	_phone = MeshInstance3D.new()
	var phone_mesh := BoxMesh.new()
	phone_mesh.size = Vector3(0.12, 0.22, 0.03)
	_phone.mesh = phone_mesh
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.85, 0.95, 1.0)
	screen.emission_enabled = true
	screen.emission = Color(0.7, 0.9, 1.0)
	_phone.material_override = screen
	_phone.position = Vector3(0, 1.55, 0.35)
	_phone.visible = false
	add_child(_phone)

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position.y = 2.6
	_bubble.font_size = 40
	_bubble.fixed_size = true       # readable from a god's height
	_bubble.pixel_size = 0.0011
	_bubble.outline_size = 12
	_bubble.no_depth_test = true
	_bubble.visible = false
	add_child(_bubble)

	speed = randf_range(P.walk_speed_min, P.walk_speed_max)
	if resident.id < 0:
		skepticism = randf()
		has_phone = randf() < B.phone_chance
	if resident.home:
		grid = city.nearest_grid(resident.home.global_position)
	home = grid
	lane_offset = Vector3(randf_range(-P.lane_spread, P.lane_spread), 0, randf_range(-P.lane_spread, P.lane_spread))
	position = city.intersection(grid) + lane_offset + Vector3.UP * 0.1
	_pick_next_target()


func _physics_process(delta: float) -> void:
	match state:
		State.HELD:
			move_and_slide()  # The god's hand drives our velocity through a spring.
		State.FALLING:
			velocity.y -= fall_gravity * delta
			_fall_speed = maxf(_fall_speed, -velocity.y)
			move_and_slide()
			if _spin != Vector3.ZERO:
				_body.quaternion = (Quaternion(_spin.normalized(), _spin.length() * delta) * _body.quaternion).normalized()
			if is_on_floor():
				_land()
			elif global_position.y < -30.0:
				_respawn()
		State.DOWN:
			# Lie where we fell, sliding to a stop, then get up.
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			velocity.y -= fall_gravity * delta
			move_and_slide()
			_body.quaternion = _body.quaternion.slerp(_lying, 1.0 - exp(-12.0 * delta))
			_body.position.y = lerpf(_body.position.y, 0.35, 1.0 - exp(-12.0 * delta))
			_down_timer -= delta
			if _down_timer <= 0.0:
				state = State.GETTING_UP
				_down_timer = P.get_up_time
		State.GETTING_UP:
			var w := 1.0 - exp(-8.0 * delta)
			_body.quaternion = _body.quaternion.slerp(UPRIGHT, w)
			_body.position.y = lerpf(_body.position.y, 0.9, w)
			_down_timer -= delta
			if _down_timer <= 0.0:
				_stand_up()
		State.WALKING:
			if idle:
				velocity = Vector3(0, -1.0, 0)
				move_and_slide()
				if _look_at_target != Vector3.INF:
					_turn_to(_look_at_target)
				return
			if _pause > 0.0:
				_pause -= delta
				if _look_at_target != Vector3.INF:
					_turn_to(_look_at_target)
				return
			if on_errand:
				_walk_errand(delta)
				return
			var to_target := target - global_position
			to_target.y = 0
			if to_target.length() < 0.6:
				_pick_next_target()
			else:
				var dir := to_target.normalized()
				velocity = Vector3(dir.x * speed, -1.0, dir.z * speed)
				rotation.y = atan2(dir.x, dir.z)
				move_and_slide()


func _process(delta: float) -> void:
	_phone_timer -= delta
	_phone.visible = _phone_timer > 0.0 and state == State.WALKING
	_bubble_timer -= delta
	_bubble.visible = _bubble_timer > 0.0
	if city.show_belief:
		# Red = skeptic, white = undecided, gold = believer.
		var c := Color.WHITE
		if belief < 0:
			c = Color.WHITE.lerp(Color(0.9, 0.15, 0.1), -belief)
		else:
			c = Color.WHITE.lerp(Color(1.0, 0.8, 0.1), belief)
		_debug_mat.albedo_color = c
		_body.material_override = _debug_mat
	else:
		_body.material_override = _own_mat


## Shift belief after witnessing or experiencing a miracle, by the formula in
## balance.gd. situation: + it helped this person, - it hurt them.
func react_to_miracle(kind: StringName, intensity: float, situation: float, friends_belief := 0.0) -> void:
	var times: int = _seen.get(kind, 0)
	_seen[kind] = times + 1
	var novelty := maxf(1.0 - B.novelty_step * times, B.novelty_floor)
	var change := intensity * situation * (1.0 - skepticism) * novelty
	# A repeat that reads as a trick turns people away, believers or not.
	if novelty < 0.0:
		change = intensity * absf(situation) * novelty
	belief = clampf(belief + change + B.friends_weight * friends_belief, -1.0, 1.0)


func has_seen_event(id: int) -> bool:
	return _events_seen.has(id)


## Saw miracle event `e` (see faith.gd) happen at `at`. First picks an
## explanation (god, chance, fraud or a plot), which decides what the miracle
## does to belief, then stops to stare and maybe films it.
## Returns true if this person filmed it.
func witness(e: Dictionary, at: Vector3, friends_belief: float) -> bool:
	if _events_seen.size() > 30:
		_events_seen.clear()
	_events_seen[e.id] = true
	var helped: bool = e.helped.has(self)
	var situation: float = B.helped_situation if helped else e.situation
	var explanation := _explain(e.deniability, 1.0 if helped else B.bystander_timing, friends_belief)
	match explanation:
		&"god":
			react_to_miracle(e.kind, e.intensity, situation, friends_belief)
		&"fraud":
			belief = clampf(belief - e.intensity * B.fraud_penalty, -1.0, 1.0)
		&"plot":
			belief = clampf(belief - e.intensity * B.plot_penalty, -1.0, 1.0)
	# Big miracles hold people longer, and they keep talking about them.
	var hold: float = B.look_time * (1.0 + e.intensity * 3.0)
	_say(explanation, hold * 1.4)
	if state != State.WALKING:
		return false
	_pause = maxf(_pause, hold * randf_range(0.7, 1.3))
	_look_at_target = at
	_turn_to(at)
	if has_phone:
		_phone_timer = _pause
	return has_phone


## Weigh the four explanations of the design doc and pick one.
## deniability: how easy it is to explain without a god; timing: how exactly it
## answered this person's need right now.
func _explain(deniability: float, timing: float, friends_belief: float) -> StringName:
	if scripted_explanation != &"":
		var fixed := scripted_explanation
		scripted_explanation = &""
		return fixed
	var weights := {
		&"god": (1.0 - skepticism) * (0.3 + timing) * (1.0 - deniability * 0.5) + maxf(friends_belief, 0.0) * 0.5,
		&"chance": deniability * (0.4 + skepticism * 0.6),
		&"fraud": skepticism * (1.0 - deniability) * B.fraud_weight * (1.5 if has_phone else 1.0),
		&"plot": skepticism * B.plot_weight,
	}
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return &"chance"


## A short line over the head, so the player can read how a miracle landed.
func _say(explanation: StringName, seconds: float) -> void:
	var lines := {
		&"god": ["It's a miracle!", Color(1.0, 0.85, 0.35)],
		&"chance": ["Just luck.", Color(0.85, 0.85, 0.85)],
		&"fraud": ["It's a hoax.", Color(1.0, 0.45, 0.4)],
		&"plot": ["Someone's behind this...", Color(0.7, 0.6, 1.0)],
	}
	_say_line(lines[explanation][0], lines[explanation][1], seconds)


func _turn_to(p: Vector3) -> void:
	var d := p - global_position
	rotation.y = atan2(d.x, d.z)


## Answer a divine sign: walk to `spot` (along the streets), then stand
## there facing `face` for `stay` seconds, now and then saying `line`.
func send_on_errand(spot: Vector3, face: Vector3, stay: float, line: String, color: Color) -> void:
	on_errand = true
	errand_arrived = false
	var corner: Vector3 = city.intersection(city.nearest_grid(spot))
	_errand_route = [corner + lane_offset * 0.3, Vector3(spot.x, corner.y, spot.z)]
	_errand_time = stay
	_errand_line = line
	_errand_color = color
	_errand_face = face
	_errand_say = 0.0


## Free to answer a sign: walking the streets, not busy with anything else.
func can_answer() -> bool:
	return state == State.WALKING and not on_errand and not idle


func end_errand() -> void:
	if not on_errand:
		return
	on_errand = false
	errand_arrived = false
	resume_walking()


func _walk_errand(delta: float) -> void:
	if not _errand_route.is_empty():
		var to_point := _errand_route[0] - global_position
		to_point.y = 0
		if to_point.length() < 0.8:
			_errand_route.pop_front()
			return
		var dir := to_point.normalized()
		velocity = Vector3(dir.x * speed, -1.0, dir.z * speed)
		rotation.y = atan2(dir.x, dir.z)
		move_and_slide()
		return
	errand_arrived = true
	_turn_to(_errand_face)
	_errand_say -= delta
	if _errand_say <= 0.0:
		_errand_say = randf_range(P.errand_line_min, P.errand_line_max)
		_say_line(_errand_line, _errand_color, 2.5)
	_errand_time -= delta
	if _errand_time <= 0.0:
		end_errand()


func _say_line(text: String, color: Color, seconds: float) -> void:
	_bubble.text = text
	_bubble.modulate = color
	_bubble_timer = seconds


func on_grabbed() -> void:
	on_errand = false
	errand_arrived = false
	state = State.HELD
	velocity = Vector3.ZERO
	_spin = Vector3.ZERO
	_body.quaternion = UPRIGHT
	_body.position.y = 0.9
	_phone_timer = 0.0


## Tapped by the hand.
func on_tapped(from: Vector3) -> void:
	notice(from)


## Something happened at `from` (a tap, a knock, a car alarm): stop and look.
func notice(from: Vector3) -> void:
	if state != State.WALKING:
		return
	_pause = randf_range(P.notice_pause_min, P.notice_pause_max)
	_look_at_target = Vector3.INF
	_turn_to(from)


## Where the hand should aim to pick this person.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.9


func on_released(throw_velocity: Vector3) -> void:
	state = State.FALLING
	velocity = throw_velocity
	_fall_speed = 0.0
	var speed := throw_velocity.length()
	if speed > P.tumble_min_speed:
		var axis := throw_velocity.cross(Vector3.UP)
		if axis.length() < 0.01:
			axis = Vector3.RIGHT
		_spin = axis.normalized() * clampf(speed * 0.5, 2.0, 14.0)
	else:
		_spin = Vector3.ZERO


## Blown off our feet (by lightning). Returns false if the hand is holding us.
func knock_over(push: Vector3) -> bool:
	if state == State.HELD:
		return false
	on_released(push)
	return true


## A healing miracle: whoever is lying down gets straight back up.
## Returns true if this person needed it.
func heal() -> bool:
	if state != State.DOWN and state != State.GETTING_UP:
		return false
	_stand_up()
	return true


func _land() -> void:
	var impact := _fall_speed + Vector2(velocity.x, velocity.z).length() * 0.5
	if _spin == Vector3.ZERO and impact < P.hard_landing_speed * 0.6:
		_body.quaternion = UPRIGHT
		_stand_up()
		return
	# Knocked down: lie flat, facing the way we were flying, for longer the harder the fall.
	_spin = Vector3.ZERO
	state = State.DOWN
	_down_timer = clampf(1.0 + impact * 0.1, 1.0, 4.0)
	var heading := atan2(velocity.x, velocity.z) - rotation.y
	_lying = Quaternion(Vector3.UP, heading) * Quaternion(Vector3.RIGHT, PI / 2.0)


func _stand_up() -> void:
	_body.quaternion = UPRIGHT
	_body.position.y = 0.9
	state = State.WALKING
	velocity = Vector3.ZERO
	grid = city.nearest_grid(global_position)
	target = city.intersection(grid) + lane_offset


## Fell off the world: back home.
func _respawn() -> void:
	state = State.WALKING
	grid = home
	global_position = city.intersection(grid) + lane_offset + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	_spin = Vector3.ZERO
	_body.quaternion = UPRIGHT
	_body.position.y = 0.9
	_pick_next_target()


## Back to walking the streets from wherever this person is now.
func resume_walking() -> void:
	idle = false
	_look_at_target = Vector3.INF
	grid = city.nearest_grid(global_position)
	target = city.intersection(grid) + lane_offset


## Moved house: start again from the corner nearest the new home.
func settle_at_home() -> void:
	home = city.nearest_grid(resident.home.global_position)
	grid = home
	global_position = city.intersection(grid) + lane_offset + Vector3.UP * 0.1
	resume_walking()


func _pick_next_target() -> void:
	# Everyone has a neighbourhood: believers gather where they live.
	var next: Vector2i = city.random_neighbor(grid)
	for attempt in 4:
		if city.intersection(next).distance_to(city.intersection(home)) <= P.home_range:
			break
		next = city.random_neighbor(grid)
	grid = next
	target = city.intersection(grid) + lane_offset
