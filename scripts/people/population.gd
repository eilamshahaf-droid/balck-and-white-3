extends Node
## The city's residents. Once the city is built, gives every person a name, a
## group, a home in a real building, a workplace, family and close friends,
## then puts a body for each on the street. Other systems ask Population about
## people (who lives where, who believes) instead of scanning the scene tree.

# Loaded at run time: a parse-time preload would load social_group.gd before
# its class_name is registered and break the typed groups array.
var _people: PeopleSettings = load("res://data/people.tres")
const B: Balance = preload("res://data/balance.tres")
const CitizenScript := preload("res://scripts/citizen.gd")

var residents: Array[Resident] = []

var _homes: Array[Node3D] = []
var _offices: Array[Node3D] = []
var _by_home: Dictionary = {}   # building -> Array[Resident]
var _rng := RandomNumberGenerator.new()

@onready var city: Node3D = get_parent()


func _ready() -> void:
	_rng.seed = 7
	# The city builds its blocks in its own _ready, which runs after ours.
	city.ready.connect(_populate, CONNECT_ONE_SHOT)


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
	if r.home:
		(_by_home[r.home] as Array).erase(r)
	r.home = building
	if not _by_home.has(building):
		_by_home[building] = []
	(_by_home[building] as Array).append(r)
	if is_instance_valid(r.body):
		r.body.settle_at_home()


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
		var c: CharacterBody3D = CitizenScript.new()
		c.city = city
		c.resident = r
		c.collision_layer = city.LAYER_CITIZENS
		c.collision_mask = city.LAYER_WORLD
		r.body = c
		city.add_child(c)


func _add_family() -> void:
	var home: Node3D = _homes[_rng.randi() % _homes.size()]
	var last: String = _people.last_names[_rng.randi() % _people.last_names.size()]
	var size := mini(_rng.randi_range(_people.family_size_min, _people.family_size_max), _people.resident_count - residents.size())
	var ids: Array[int] = []
	for n in size:
		var r := Resident.new()
		r.id = residents.size()
		r.first_name = _people.first_names[_rng.randi() % _people.first_names.size()]
		r.last_name = last
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
