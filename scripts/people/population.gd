extends Node
## The city's residents. Once the city is built, gives every person a name, a
## group, a home in a real building, a workplace, family and close friends,
## then puts a body for each on the street. Other systems ask Population about
## people (who lives where, who believes) instead of scanning the scene tree.
##
## It also tracks believers the hand sets down on or at a building, who sit in
## there to claim it (the power route of the claim meter, design doc: "how a
## place is taken"), and keeps each building's believing presence cached.

## A believer started sitting in on `building`.
signal occupant_added(building: Node3D, resident: Resident)
## An occupant left `building` (picked up, or went home).
signal occupant_left(building: Node3D, resident: Resident)

# Loaded at run time: a parse-time preload would load social_group.gd before
# its class_name is registered and break the typed groups array.
var _people: PeopleSettings = load("res://data/people.tres")
const B: Balance = preload("res://data/balance.tres")

var residents: Array[Resident] = []

var _homes: Array[Node3D] = []
var _offices: Array[Node3D] = []
var _by_home: Dictionary = {}   # building -> Array[Resident]
var _occupants: Dictionary = {}   # building -> Array[Resident]
var _presence: Dictionary = {}    # building -> summed belief of its believers, refreshed on a timer
var _footprints: Dictionary = {}  # building -> Rect2 on the ground (x, z)
var _presence_timer := 0.0
var _used_names: Dictionary = {}   # full name -> true, so nobody shares a name
var _rng := RandomNumberGenerator.new()

@onready var city: Node3D = get_parent()


func _ready() -> void:
	_rng.seed = 7
	# The city builds its blocks in its own _ready, which runs after ours.
	city.ready.connect(_populate, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_presence_timer -= delta
	if _presence_timer > 0.0:
		return
	_presence_timer = _people.presence_refresh
	_refresh_presence()


## How strongly believers hold `building`: the summed belief of the believers
## who live there or sit in on it. Cached, so it is cheap to ask every tick.
func power_presence(building: Node3D) -> float:
	return _presence.get(building, 0.0)


func occupants(building: Node3D) -> Array:
	return _occupants.get(building, [])


## Share of the people living in `building` who believe (0 if nobody lives there).
func believer_share(building: Node3D) -> float:
	var people: Array = _by_home.get(building, [])
	if people.is_empty():
		return 0.0
	var n := 0
	for r: Resident in people:
		if r.belief > B.believer_threshold:
			n += 1
	return float(n) / people.size()


## The resident whose body stands nearest `p` on the ground, within `radius`; null if none.
func resident_near(p: Vector3, radius: float) -> Resident:
	var best: Resident = null
	var best_d := radius
	for r in residents:
		if not is_instance_valid(r.body):
			continue
		var d := Vector2(r.body.global_position.x - p.x, r.body.global_position.z - p.z).length()
		if d < best_d:
			best_d = d
			best = r
	return best


## The building people can live in nearest to `p`.
func home_near(p: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for b in _homes:
		var d := b.global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = b
	return best


func move_home(r: Resident, building: Node3D) -> void:
	_set_home(r, building)
	if is_instance_valid(r.body):
		r.body.settle_at_home()


## `r` moves out of their home to the nearest other one (bought out, scared off).
func evict(r: Resident) -> void:
	var old := r.home
	_homes.erase(old)
	var new_home := home_near(old.global_position)
	_homes.append(old)
	if new_home == null:
		return
	_set_home(r, new_home)
	if is_instance_valid(r.body):
		r.body.move_out()


## Someone preaches to `r` (missionaries at the door): belief rises by
## `strength`, less the more skeptical the person is.
func preach_to(r: Resident, strength: float) -> void:
	r.belief = minf(1.0, r.belief + strength * (1.0 - r.skepticism))


## Everyone leaves `building` for good (roaches, fire): the people who live
## there move to the nearest other homes and those close by run out into the
## street. Nobody moves in again, so it stays empty.
func evacuate(building: Node3D) -> void:
	_homes.erase(building)
	_release_occupants(building)
	var new_home := home_near(building.global_position)
	if new_home == null:
		return  # the whole city is going away (quitting the game)
	var leaving: Array = _by_home.get(building, []).duplicate()
	for r: Resident in leaving:
		_set_home(r, new_home)
		if not is_instance_valid(r.body):
			continue
		r.body.move_out()
		if r.body.global_position.distance_to(building.global_position) < _people.flee_reach:
			r.body.flee(building.global_position)
	_by_home.erase(building)


## Skip the story: whole families move into the homes nearest one corner and
## become a small congregation of believers.
func found_congregation() -> void:
	var corner: Vector3 = city.intersection(_people.congregation_corner)
	var near := _homes.duplicate()
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(corner) < b.global_position.distance_squared_to(corner))
	var moved := 0
	var family_home := 0
	for r in residents:
		if moved >= _people.congregation_size:
			break
		# Families are created together, so their ids sit side by side; a new
		# surname means a new family and the next building.
		if moved > 0 and r.last_name != residents[r.id - 1].last_name:
			family_home += 1
		move_home(r, near[family_home % near.size()])
		r.belief = _rng.randf_range(_people.congregation_belief_min, _people.congregation_belief_max)
		r.skepticism = _rng.randf_range(0.0, _people.congregation_skepticism_max)
		moved += 1


func _populate() -> void:
	for b: Node3D in get_tree().get_nodes_in_group("buildings"):
		if _height(b) > _people.office_height:
			_offices.append(b)
		else:
			_homes.append(b)
	while residents.size() < _people.resident_count:
		_add_family()
	_add_friends()
	for r in residents:
		var c := Citizen.new()
		c.city = city
		c.resident = r
		c.collision_layer = city.LAYER_CITIZENS
		c.collision_mask = city.LAYER_WORLD
		r.body = c
		city.add_child(c)
		c.set_down.connect(_on_set_down.bind(r))
		c.stopped_occupying.connect(_on_stopped_occupying.bind(r))
	for b in _homes + _offices:
		_footprints[b] = _footprint(b)
		_presence[b] = 0.0
		b.tree_exiting.connect(_forget_building.bind(b), CONNECT_ONE_SHOT)
	_refresh_presence()


## A believer set down on a building, or right at its walls, sits in there.
func _on_set_down(r: Resident) -> void:
	if r.belief <= B.believer_threshold or r.occupying:
		return
	var p := r.body.global_position
	var building := _place_at(p)
	if building == null:
		return
	r.occupying = building
	if not _occupants.has(building):
		_occupants[building] = []
	(_occupants[building] as Array).append(r)
	r.body.occupy(building.global_position)
	occupant_added.emit(building, r)


func _on_stopped_occupying(r: Resident) -> void:
	var building := r.occupying
	if building == null:
		return
	r.occupying = null
	(_occupants[building] as Array).erase(r)
	occupant_left.emit(building, r)


## A building left the city (City Hall's bulldozer): everyone who lived,
## worked or sat in there carries on without it.
func _forget_building(building: Node3D) -> void:
	evacuate(building)
	_offices.erase(building)
	_footprints.erase(building)
	_presence.erase(building)
	_occupants.erase(building)
	if _homes.is_empty():
		return
	for r in residents:
		if r.work == building:
			r.work = _pick_work(r.group)


func _release_occupants(building: Node3D) -> void:
	for r: Resident in occupants(building).duplicate():
		if is_instance_valid(r.body):
			r.body.leave_occupied()
		else:
			_on_stopped_occupying(r)


func _set_home(r: Resident, building: Node3D) -> void:
	if r.home:
		(_by_home[r.home] as Array).erase(r)
	r.home = building
	if not _by_home.has(building):
		_by_home[building] = []
	(_by_home[building] as Array).append(r)


## The building `p` stands on, or the nearest one within occupy_reach of its walls (null if none).
func _place_at(p: Vector3) -> Node3D:
	var at := Vector2(p.x, p.z)
	var best: Node3D = null
	var best_d := _people.occupy_reach
	for b: Node3D in _footprints:
		var rect: Rect2 = _footprints[b]
		var d := at.distance_to(at.clamp(rect.position, rect.end))
		if d <= best_d:
			best_d = d
			best = b
	return best


func _footprint(building: Node3D) -> Rect2:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size := (child.shape as BoxShape3D).size
			var c := building.global_position
			return Rect2(c.x - size.x / 2.0, c.z - size.z / 2.0, size.x, size.z)
	return Rect2()


func _refresh_presence() -> void:
	for b: Node3D in _presence:
		_presence[b] = 0.0
	for r in residents:
		if r.belief <= B.believer_threshold:
			continue
		_presence[r.home] += r.belief
		if r.occupying and r.occupying != r.home:
			_presence[r.occupying] += r.belief


func _add_family() -> void:
	var home: Node3D = _homes[_rng.randi() % _homes.size()]
	var last: String = _people.last_names[_rng.randi() % _people.last_names.size()]
	var size := mini(_rng.randi_range(_people.family_size_min, _people.family_size_max), _people.resident_count - residents.size())
	var ids: Array[int] = []
	for n in size:
		var r := Resident.new()
		r.id = residents.size()
		r.last_name = last
		r.first_name = _unused_first_name(last)
		r.group = _pick_group()
		r.work = _pick_work(r.group)
		r.belief = _rng.randf_range(_people.belief_min, _people.belief_max)
		r.skepticism = _rng.randf_range(r.group.skepticism_min, r.group.skepticism_max)
		r.has_phone = _rng.randf() < B.phone_chance
		residents.append(r)
		move_home(r, home)
		ids.append(r.id)
	for id in ids:
		var others := ids.duplicate()
		others.erase(id)
		residents[id].family = others


func _unused_first_name(last: String) -> String:
	var first := ""
	for _attempt in 20:
		first = _people.first_names[_rng.randi() % _people.first_names.size()]
		if not _used_names.has(first + " " + last):
			break
	_used_names[first + " " + last] = true
	return first


## Close friends, mostly neighbours and colleagues. A friendship goes both ways.
func _add_friends() -> void:
	for r in residents:
		var wanted := _rng.randi_range(_people.friends_min, _people.friends_max)
		var nearby: Array[Resident] = []
		var distant: Array[Resident] = []
		for o in residents:
			if o == r or r.family.has(o.id) or r.friends.has(o.id):
				continue
			if _close(r, o):
				nearby.append(o)
			else:
				distant.append(o)
		nearby.shuffle()
		distant.shuffle()
		while r.friends.size() < wanted and not (nearby.is_empty() and distant.is_empty()):
			var far := nearby.is_empty() or (not distant.is_empty() and _rng.randf() < _people.distant_friend_chance)
			var f: Resident = distant.pop_back() if far else nearby.pop_back()
			r.friends.append(f.id)
			f.friends.append(r.id)


func _close(a: Resident, b: Resident) -> bool:
	if a.work != null and a.work == b.work:
		return true
	return a.home.global_position.distance_to(b.home.global_position) < _people.neighbour_radius


func _pick_group() -> SocialGroup:
	var total := 0.0
	for g in _people.groups:
		total += g.share
	var roll := _rng.randf() * total
	for g in _people.groups:
		roll -= g.share
		if roll <= 0.0:
			return g
	return _people.groups[-1]


func _pick_work(g: SocialGroup) -> Node3D:
	match g.workplace:
		SocialGroup.Workplace.OFFICE:
			if not _offices.is_empty():
				return _offices[_rng.randi() % _offices.size()]
			return _homes[_rng.randi() % _homes.size()]
		SocialGroup.Workplace.STREET:
			return _homes[_rng.randi() % _homes.size()]
	return null


func _height(building: Node3D) -> float:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size.y
	return 0.0
