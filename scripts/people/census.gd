class_name Census
extends RefCounted
## Builds the city's residents once, when the city is ready: families with
## unique names in every home (at least min_residents_per_home each), jobs,
## and close friends. Population takes the result and runs the city with it.

const B: Balance = preload("res://data/balance.tres")

var residents: Array[Resident] = []
var by_home: Dictionary = {}   # building -> Array[Resident]
var homes: Array[Node3D] = []
var offices: Array[Node3D] = []

var _people: PeopleSettings
var _rng: RandomNumberGenerator
var _used_names: Dictionary = {}   # full name -> true, so nobody shares a name
var _staff: Dictionary = {}        # office -> number of people working there


func _init(people: PeopleSettings, rng: RandomNumberGenerator) -> void:
	_people = people
	_rng = rng


## Sort `buildings` into homes and office towers, then fill them with people.
func take(buildings: Array[Node]) -> void:
	for b: Node3D in buildings:
		if _height(b) > _people.office_height:
			offices.append(b)
		else:
			homes.append(b)
	for home in homes:
		while (by_home.get(home, []) as Array).size() < _people.min_residents_per_home:
			_add_family(home, _people.family_size_max)
	while residents.size() < _people.resident_count:
		_add_family(homes[_rng.randi() % homes.size()], _people.resident_count - residents.size())
	_add_friends()


func _set_home(r: Resident, building: Node3D) -> void:
	r.home = building
	if not by_home.has(building):
		by_home[building] = []
	(by_home[building] as Array).append(r)


## A family of at most `max_size` moves into `home`.
func _add_family(home: Node3D, max_size: int) -> void:
	var last: String = _people.last_names[_rng.randi() % _people.last_names.size()]
	var size := mini(_rng.randi_range(_people.family_size_min, _people.family_size_max), max_size)
	var ids: Array[int] = []
	for n in size:
		var r := Resident.new()
		r.id = residents.size()
		r.last_name = last
		r.first_name = _unused_first_name(last)
		r.group = _pick_group()
		r.work = pick_work(r.group)
		r.belief = _rng.randf_range(_people.belief_min, _people.belief_max)
		r.baseline = r.belief
		r.color = Color.from_hsv(_rng.randf(), 0.45, 0.85)
		r.skepticism = _rng.randf_range(r.group.skepticism_min, r.group.skepticism_max)
		r.has_phone = _rng.randf() < B.phone_chance
		residents.append(r)
		_set_home(r, home)
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
## Candidates come from the homes nearby and the same workplace, not from the
## whole city, so this stays fast with thousands of residents.
func _add_friends() -> void:
	var neighbours := {}   # home -> Array of residents living within neighbour_radius
	for home: Node3D in by_home:
		var around: Array[Resident] = []
		for other: Node3D in by_home:
			if home.global_position.distance_to(other.global_position) < _people.neighbour_radius:
				around.append_array(by_home[other])
		neighbours[home] = around
	var colleagues := {}   # workplace -> Array of residents working there
	for r in residents:
		if r.work:
			if not colleagues.has(r.work):
				colleagues[r.work] = []
			(colleagues[r.work] as Array).append(r)
	for r in residents:
		var wanted := _rng.randi_range(_people.friends_min, _people.friends_max)
		var nearby: Array = (neighbours[r.home] as Array).duplicate()
		if r.work:
			nearby.append_array(colleagues[r.work])
		nearby.shuffle()
		for _attempt in wanted * 4:
			if r.friends.size() >= wanted:
				break
			var f: Resident
			if nearby.is_empty() or _rng.randf() < _people.distant_friend_chance:
				f = residents[_rng.randi() % residents.size()]
			else:
				f = nearby.pop_back()
			if f == r or r.family.has(f.id) or r.friends.has(f.id):
				continue
			r.friends.append(f.id)
			f.friends.append(r.id)


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


## Where someone of group `g` works: an office tower (the least staffed one,
## so every tower gets its people), a low building on the street, or nowhere.
func pick_work(g: SocialGroup) -> Node3D:
	match g.workplace:
		SocialGroup.Workplace.OFFICE:
			if offices.is_empty():
				return homes[_rng.randi() % homes.size()]
			var best := offices[0]
			for o in offices:
				if _staff.get(o, 0) < _staff.get(best, 0):
					best = o
			_staff[best] = _staff.get(best, 0) + 1
			return best
		SocialGroup.Workplace.STREET:
			return homes[_rng.randi() % homes.size()]
	return null


func _height(building: Node3D) -> float:
	for child in building.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size.y
	return 0.0
