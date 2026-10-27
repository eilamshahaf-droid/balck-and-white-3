class_name Citizen
extends CharacterBody3D
## The body of a city resident: walks between intersections near home,
## falls, gets up, stares at miracles. Who the person is (name, home, family,
## belief) lives on the Resident record, so it outlasts this body.
##
## Belief is hidden from the player. A miracle can push it toward faith or
## toward skepticism, depending on what the miracle did to this person, on a
## personal coefficient (skepticism) the player never sees, and on how many
## times they have seen that kind of miracle before (see balance.gd).

## Back on our feet after the hand dropped or threw us.
signal set_down
## Picked up or done sitting in: no longer holds the place we were occupying.
signal stopped_occupying

enum State { WALKING, HELD, FALLING, DOWN, GETTING_UP }

const UPRIGHT := Quaternion.IDENTITY
const OCCUPY_LINES: Array[String] = [
	"We're not leaving.", "This floor is holy now.", "Form 7-C, signed.", "Sit-in for the Hand!",
]
const OCCUPY_COLOR := Color(1.0, 0.85, 0.35)
const FLEE_LINES: Array[String] = ["ROACHES!", "Not my kitchen!", "I'm never going back in there!", "It touched me!"]
const FLEE_COLOR := Color(1.0, 0.55, 0.45)
const B = preload("res://data/balance.tres")
# Loaded at run time: a parse-time preload would load social_group.gd before
# its class_name is registered and break the typed groups array.
var _people: PeopleSettings = load("res://data/people.tres")

var city: Node3D
var police: Police
## Used by the god's hand: heavier things lag and swing more when held.
var mass := 1.0
var fall_gravity := _people.gravity
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
## Sitting in on a building (a roof, a lobby) to claim it for the cult.
var occupying := false

## The body's pose (tumbling, lying down). The crowd (crowd.gd) draws every
## body; this mesh stays hidden and gives the hand its size, and shows only
## while the hand outlines this person, since the outline is drawn on it.
var _body: MeshInstance3D
static var _phone_screen: StandardMaterial3D

var _own_mat: StandardMaterial3D
var _fall_speed := 0.0
var _pause := 0.0
var _spin := Vector3.ZERO      # tumble while flying, radians per second around this axis
var _down_timer := 0.0
var _lying := Quaternion.IDENTITY
var _events_seen := {}     # ids of miracle events already reacted to
var _phone: MeshInstance3D
var _phone_timer := 0.0
var _look_at_target := Vector3.INF   # where a witness stares while stopped
static var _explaining := 0   # explanation bubbles showing now, over everyone
var _bubble: Label3D
var _bubble_timer := 0.0
var _bubble_counted := false   # this bubble is one of the `_explaining` ones
var _errand_route: Array[Vector3] = []
var _errand_time := 0.0
var _errand_line := ""
var _errand_color := Color.WHITE
var _errand_face := Vector3.ZERO
var _errand_say := 0.0
var _occupy_time := 0.0
var _flee_time := 0.0
var _dancing := false
var _dance_time := 0.0
var _from_hand := false       # the fall in progress started in the hand


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
	_body.mesh = SharedMeshes.capsule(0.35, 1.8)
	_body.position.y = 0.9
	_body.visible = false
	add_child(_body)
	Crowd.join(self)
	# The phone and the speech bubble are made the first time they are needed:
	# most of the crowd never films or speaks.
	set_process(false)

	speed = randf_range(_people.walk_speed_min, _people.walk_speed_max)
	if resident.id < 0:
		skepticism = randf()
		has_phone = randf() < B.phone_chance
		resident.color = Color.from_hsv(randf(), 0.45, 0.85)
	if resident.home:
		grid = city.nearest_grid(resident.home.global_position)
	home = grid
	lane_offset = Vector3(randf_range(-_people.lane_spread, _people.lane_spread), 0, randf_range(-_people.lane_spread, _people.lane_spread))
	position = city.intersection(grid) + lane_offset + Vector3.UP * 0.1
	_pick_next_target()


func _physics_process(delta: float) -> void:
	if (_body.material_overlay != null) != _body.visible:
		_show_own_body(not _body.visible)
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
				_down_timer = _people.get_up_time
		State.GETTING_UP:
			var w := 1.0 - exp(-8.0 * delta)
			_body.quaternion = _body.quaternion.slerp(UPRIGHT, w)
			_body.position.y = lerpf(_body.position.y, 0.9, w)
			_down_timer -= delta
			if _down_timer <= 0.0:
				_stand_up()
		State.WALKING:
			if idle:
				if _look_at_target != Vector3.INF:
					_turn_to(_look_at_target)
				if occupying:
					_sit_in(delta)
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
			var pace := speed
			if _flee_time > 0.0:
				_flee_time -= delta
				pace *= _people.flee_speed_factor
			if to_target.length() < 0.6:
				_pick_next_target()
			else:
				_step_toward(target, pace, delta)


## Runs only while this person is filming or talking.
func _process(delta: float) -> void:
	_phone_timer -= delta
	_bubble_timer -= delta
	if _phone:
		_phone.visible = _phone_timer > 0.0 and state == State.WALKING
	if _bubble:
		_bubble.visible = _bubble_timer > 0.0
	if _bubble_counted and _bubble_timer <= 0.0:
		_uncount_bubble()
	if _phone_timer <= 0.0 and _bubble_timer <= 0.0:
		set_process(false)


func _exit_tree() -> void:
	_uncount_bubble()
	Crowd.leave(self)


## Where the crowd draws this body (nowhere while it shows its own mesh).
func body_transform() -> Transform3D:
	if _body.visible:
		return Transform3D(Basis.from_scale(Vector3.ZERO), global_position)
	var t := global_transform * _body.transform
	if resident.job != Resident.Job.PRIEST:
		return t
	# Grow about the feet, so a priest doesn't sink into the street.
	var s := _people.priest_scale
	return Transform3D(t.basis.scaled(Vector3.ONE * s), global_position + (t.origin - global_position) * s)


## The body's colour: priests white, believers gold, zealots orange. With the
## belief view on (B): red = skeptic, white = undecided, gold = believer.
func body_color() -> Color:
	if not city.show_belief:
		if resident.job == Resident.Job.PRIEST:
			return _people.priest_color
		match resident.stage():
			Resident.Stage.ZEALOT:
				return _people.zealot_color
			Resident.Stage.BELIEVER:
				return _people.believer_color
		return resident.color
	if belief < 0:
		return Color.WHITE.lerp(Color(0.9, 0.15, 0.1), -belief)
	return Color.WHITE.lerp(Color(1.0, 0.8, 0.1), belief)


func has_seen_event(id: int) -> bool:
	return _events_seen.has(id)


## Saw miracle event `e` (see faith.gd) happen at `at`. Picks an explanation
## (god, chance, fraud or a plot) and says it, stops to stare and maybe films
## it. A miracle doesn't change belief by itself (it gives a priest proof to
## preach with), but one that hurt this person scares them.
## Returns true if this person filmed it.
func witness(e: Dictionary, at: Vector3, friends_belief: float) -> bool:
	if _events_seen.size() > 30:
		_events_seen.clear()
	_events_seen[e.id] = true
	var helped: bool = e.helped.has(self)
	var situation: float = B.helped_situation if helped else e.situation
	var explanation := _explain(e.deniability, 1.0 if helped else B.bystander_timing, friends_belief)
	if situation < 0.0:
		resident.fear = minf(resident.fear - situation * e.intensity * _people.fear_per_harm, 1.0)
	# Big miracles hold people longer, and they keep talking about them.
	var hold: float = B.look_time * (1.0 + e.intensity * 3.0)
	_say(explanation, hold * 1.4)
	if state != State.WALKING:
		return false
	_pause = maxf(_pause, hold * randf_range(0.7, 1.3))
	_look_at_target = at
	_turn_to(at)
	if has_phone:
		_film(_pause)
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
## Only so many show at once; a crowd of identical lines is just clutter.
func _say(explanation: StringName, seconds: float) -> void:
	if _explaining >= B.max_explanations_shown:
		return
	var lines := {
		&"god": ["It's a miracle!", Color(1.0, 0.85, 0.35)],
		&"chance": ["Just luck.", Color(0.85, 0.85, 0.85)],
		&"fraud": ["It's a hoax.", Color(1.0, 0.45, 0.4)],
		&"plot": ["Someone's behind this...", Color(0.7, 0.6, 1.0)],
	}
	_say_line(lines[explanation][0], lines[explanation][1], seconds)
	if not _bubble_counted:
		_bubble_counted = true
		_explaining += 1


func _uncount_bubble() -> void:
	if _bubble_counted:
		_bubble_counted = false
		_explaining -= 1


func _turn_to(p: Vector3) -> void:
	var d := p - global_position
	rotation.y = atan2(d.x, d.z)


## Answer a divine sign: walk to `spot` (along the streets), then stand
## there facing `face` for `stay` seconds, now and then saying `line`.
func send_on_errand(spot: Vector3, face: Vector3, stay: float, line: String, color: Color,
		dance := false) -> void:
	_dancing = dance
	on_errand = true
	errand_arrived = false
	var corner: Vector3 = city.intersection(city.nearest_grid(spot))
	_errand_route = [corner + lane_offset * 0.3, Vector3(spot.x, corner.y, spot.z)]
	_errand_time = stay
	_errand_line = line
	_errand_color = color
	_errand_face = face
	# Start at different moments, so a group doesn't chant in unison.
	_errand_say = randf_range(0.0, _people.errand_line_max)


## Free to answer a sign: walking the streets, not busy with anything else.
func can_answer() -> bool:
	return state == State.WALKING and not on_errand and not idle


func end_errand() -> void:
	if not on_errand:
		return
	if _dancing:
		_dancing = false
		_body.position.y = 0.9
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
		_step_toward(_errand_route[0], speed, delta)
		return
	errand_arrived = true
	if _dancing:
		_dance(delta)
	else:
		_turn_to(_errand_face)
	_errand_say -= delta
	if _errand_say <= 0.0:
		_errand_say = randf_range(_people.errand_line_min, _people.errand_line_max)
		# Only some speak each time, so a crowd's lines stay readable.
		if randf() < _people.errand_line_chance:
			_say_line(_errand_line, _errand_color, _people.errand_line_time)
	_errand_time -= delta
	if _errand_time <= 0.0:
		end_errand()


## Bob up and down and turn on the spot (a block party).
func _dance(delta: float) -> void:
	_dance_time += delta
	_body.position.y = 0.9 + absf(sin(_dance_time * _people.dance_bob_rate)) * _people.dance_bob_height
	rotation.y += _people.dance_spin * delta


## Stay at this spot, facing `face`, claiming the place for the cult. Stays
## until picked up, or for the people settings' occupy_time when that is set.
func occupy(face: Vector3) -> void:
	occupying = true
	idle = true
	_look_at_target = face
	_occupy_time = _people.occupy_time
	_errand_say = randf_range(0.0, _people.errand_line_max)


func _sit_in(delta: float) -> void:
	_errand_say -= delta
	if _errand_say <= 0.0:
		_errand_say = randf_range(_people.errand_line_min, _people.errand_line_max)
		if randf() < _people.errand_line_chance:
			_say_line(OCCUPY_LINES[randi() % OCCUPY_LINES.size()], OCCUPY_COLOR, _people.errand_line_time)
	if _people.occupy_time <= 0.0:
		return
	_occupy_time -= delta
	if _occupy_time <= 0.0:
		leave_occupied()


## Stop sitting in and go back to walking the streets.
func leave_occupied() -> void:
	_stop_occupying()
	# Down the stairs from a roof, back to the street.
	if global_position.y > 1.0:
		global_position = city.intersection(city.nearest_grid(global_position)) + lane_offset + Vector3.UP * 0.1
	resume_walking()


func _stop_occupying() -> void:
	if not occupying:
		return
	occupying = false
	idle = false
	stopped_occupying.emit()


func _say_line(text: String, color: Color, seconds: float) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.position.y = 2.6
		_bubble.font_size = 40
		_bubble.fixed_size = true       # readable from a god's height
		_bubble.pixel_size = 0.0011
		_bubble.outline_size = 12
		_bubble.no_depth_test = true
		add_child(_bubble)
	_bubble.text = text
	_bubble.modulate = color
	_bubble_timer = seconds
	set_process(true)


func _film(seconds: float) -> void:
	if _phone == null:
		_phone = MeshInstance3D.new()
		_phone.mesh = SharedMeshes.box(Vector3(0.12, 0.22, 0.03))
		if _phone_screen == null:
			_phone_screen = StandardMaterial3D.new()
			_phone_screen.albedo_color = Color(0.85, 0.95, 1.0)
			_phone_screen.emission_enabled = true
			_phone_screen.emission = Color(0.7, 0.9, 1.0)
		_phone.material_override = _phone_screen
		_phone.position = Vector3(0, 1.55, 0.35)
		add_child(_phone)
	_phone_timer = seconds
	set_process(true)


## The hand outlines what it hovers by drawing over its meshes, so a hovered
## person leaves the crowd and shows a mesh of their own until it lets go.
func _show_own_body(on: bool) -> void:
	_body.visible = on
	if not on:
		return
	if _own_mat == null:
		_own_mat = StandardMaterial3D.new()
		_body.material_override = _own_mat
		ArtStyle.restyle(_body)
	_own_mat.albedo_color = body_color()


## Walk toward `point` without the physics engine: the streets are flat, so a
## walker only needs a position. Up on a roof or a kerb, physics keeps them
## from walking through walls and lets them step down.
func _step_toward(point: Vector3, pace: float, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0.0
	dir = dir.normalized()
	rotation.y = atan2(dir.x, dir.z)
	if global_position.y > point.y + 0.5:
		velocity = Vector3(dir.x * pace, -1.0, dir.z * pace)
		move_and_slide()
		return
	global_position = Vector3(global_position.x + dir.x * pace * delta, point.y,
			global_position.z + dir.z * pace * delta)


func on_grabbed() -> void:
	_stop_occupying()
	_from_hand = true
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
	_pause = randf_range(_people.notice_pause_min, _people.notice_pause_max)
	_look_at_target = Vector3.INF
	_turn_to(from)


## Where the hand should aim to pick this person.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.9


func on_released(throw_velocity: Vector3) -> void:
	state = State.FALLING
	velocity = throw_velocity
	_fall_speed = 0.0
	var throw_speed := throw_velocity.length()
	if throw_speed > _people.tumble_min_speed:
		var axis := throw_velocity.cross(Vector3.UP)
		if axis.length() < 0.01:
			axis = Vector3.RIGHT
		_spin = axis.normalized() * clampf(throw_speed * 0.5, 2.0, 14.0)
	else:
		_spin = Vector3.ZERO


## Blown off our feet (by lightning). Returns false if the hand is holding us.
func knock_over(push: Vector3) -> bool:
	if state == State.HELD:
		return false
	_from_hand = false
	on_released(push)
	return true


func _land() -> void:
	var impact := _fall_speed + Vector2(velocity.x, velocity.z).length() * 0.5
	# A gentle drop from the hand lands on its feet, even from the height the hand carries people at.
	var soft_limit := _people.set_down_max_impact if _from_hand else _people.hard_landing_speed * 0.6
	if _spin == Vector3.ZERO and impact < soft_limit:
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
	if _from_hand:
		_from_hand = false
		set_down.emit()


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
	move_out()
	grid = home
	global_position = city.intersection(grid) + lane_offset + Vector3.UP * 0.1
	resume_walking()


## Become `r`, who just stepped out of their home: the body is reused for
## someone else instead of making a new one (Population keeps a fixed number
## of people on the street).
func become(r: Resident) -> void:
	resident = r
	speed = randf_range(_people.walk_speed_min, _people.walk_speed_max)
	end_errand()
	idle = false
	_pause = 0.0
	_flee_time = 0.0
	_look_at_target = Vector3.INF
	scripted_explanation = &""
	_events_seen.clear()
	settle_at_home()


## Run from `danger` (a roach attack) to a corner down the street, shouting.
func flee(danger: Vector3) -> void:
	if state != State.WALKING:
		return
	_stop_occupying()
	end_errand()
	idle = false
	_pause = 0.0
	var away := global_position - danger
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3.RIGHT
	grid = city.nearest_grid(global_position + away.normalized() * _people.flee_distance)
	target = city.intersection(grid) + lane_offset
	_flee_time = _people.flee_time
	_say_line(FLEE_LINES[randi() % FLEE_LINES.size()], FLEE_COLOR, _people.errand_line_time)


## The home (or post) changed while this person is out: from now on they wander
## around the new one, walking there instead of appearing at it.
func move_out() -> void:
	var base: Node3D = resident.post if resident.post else resident.home
	home = city.nearest_grid(base.global_position)


func _pick_next_target() -> void:
	# Everyone has a neighbourhood: believers gather where they live.
	var next: Vector2i = city.random_neighbor(grid)
	for attempt in 4:
		if city.intersection(next).distance_to(city.intersection(home)) <= _people.home_range \
				and not _street_closed(grid, next):
			break
		next = city.random_neighbor(grid)
	if _street_closed(grid, next):
		# Every way out is shut for now: wait a beat at this corner.
		_pause = randf_range(_people.notice_pause_min, _people.notice_pause_max)
		return
	grid = next
	target = city.intersection(grid) + lane_offset


## Is the street between two corners shut by a roadblock?
func _street_closed(from: Vector2i, to: Vector2i) -> bool:
	if police == null:
		return false
	var mid: Vector3 = (city.intersection(from) + city.intersection(to)) / 2.0
	return police.is_closed_at(mid)
