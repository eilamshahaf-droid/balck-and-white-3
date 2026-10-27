extends Node
## Believers answer the divine signs on buildings (design doc: "signs").
##
## A sign is not an order: each believer walks over and acts on it.
##   Blessed: everyone gathers to pray, and their prayers fill the pool faster.
##   Cursed: a rally in front of the entrance.
##   Protected: a human chain in robes, which also fights any fire there.
## Unsure believers now and then misread the sky and do something else.
## These are the readings of the power route; money and influence readings
## come once districts know how they were taken over (design doc: signs).

const M = preload("res://data/miracles.tres")
const B = preload("res://data/balance.tres")
const DivineSign = preload("res://scripts/divine_sign.gd")

const KINDS: Array[StringName] = [&"blessed", &"cursed", &"protected"]
const SIDEWALK := 2.5         # the block's raised sidewalk: people walk the street, so they stand just off the kerb
const KERB_GAP := 1.0
const ROLES := {&"blessed": &"pray", &"cursed": &"rally", &"protected": &"guard"}
## What each role says, and its colour.
const LINES := {
	&"pray": [["Bless this place!", "Hallelujah!", "I felt a warm glow."], Color(1.0, 0.85, 0.35)],
	&"rally": [["Repent, building!", "We have pamphlets!", "Honk if He answered you!"], Color(0.75, 0.65, 1.0)],
	&"guard": [["Human chain! Robes on!", "Nobody touches this building!", "Protected by a higher power."], Color(0.5, 0.95, 1.0)],
}
const MISREAD_LINE := "Wait... was that a cloud or a halo?"

@onready var faith: Node = get_node("../Faith")
@onready var miracles: Node = get_node("../Miracles")

var _followers := {}   # divine sign -> Array of [citizen, role]
var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = M.recruit_interval
	_forget_gone()
	for divine in get_tree().get_nodes_in_group("divine_signs"):
		var team: Array = _followers.get(divine, [])
		_followers[divine] = team
		_recruit(divine, team)
		_act(divine.get_parent(), team, M.recruit_interval)


## Drop followers who left (grabbed, thrown, done) and signs that were cleared.
func _forget_gone() -> void:
	for divine in _followers.keys():
		var team: Array = _followers[divine]
		if not is_instance_valid(divine) or divine.is_queued_for_deletion():
			for f in team:
				if is_instance_valid(f[0]):
					f[0].end_errand()
			_followers.erase(divine)
			continue
		_followers[divine] = team.filter(func(f): return is_instance_valid(f[0]) and f[0].on_errand)


func _recruit(divine: Node3D, team: Array) -> void:
	var building: Node3D = divine.get_parent()
	var needed: int = M.followers_per_sign - team.size()
	if needed <= 0:
		return
	var size := DivineSign.building_size(building)
	for c in _free_believers_near(building.global_position):
		if needed == 0:
			break
		var kind: StringName = divine.kind
		var misread: bool = c.belief < M.unsure_belief and randf() < M.misread_chance
		if misread:
			kind = KINDS[(KINDS.find(kind) + randi_range(1, 2)) % KINDS.size()]
		var role: StringName = ROLES[kind]
		var spot := _spot(building, size, c.global_position)
		var line: Array = LINES[role]
		var text: String = MISREAD_LINE if misread else line[0][randi() % line[0].size()]
		c.send_on_errand(spot, building.global_position, M.errand_time, text, line[1])
		team.append([c, role])
		needed -= 1


## Where a follower stands: in the street just off the kerb, on the
## building's side nearer to them, spread along the front.
func _spot(building: Node3D, size: Vector3, from: Vector3) -> Vector3:
	var side := 1.0 if from.z > building.global_position.z else -1.0
	var out: float = size.z / 2.0 + SIDEWALK + KERB_GAP
	var along := randf_range(-0.4, 0.4) * size.x
	return building.global_position + Vector3(along, -building.global_position.y, side * out)


func _free_believers_near(p: Vector3) -> Array:
	var out := []
	for c in get_tree().get_nodes_in_group("citizens"):
		if c.belief > B.believer_threshold and c.can_answer() and c.global_position.distance_to(p) < M.sign_reach:
			out.append(c)
	out.sort_custom(func(a, b): return a.global_position.distance_to(p) < b.global_position.distance_to(p))
	return out


## What the followers standing at `building` do this step.
func _act(building: Node3D, team: Array, dt: float) -> void:
	var counts := {}
	for f in team:
		if f[0].errand_arrived:
			counts[f[1]] = counts.get(f[1], 0) + 1
	faith.belief_pool += M.worship_belief * counts.get(&"pray", 0) * dt
	if counts.get(&"guard", 0) > 0:
		var fire: Node3D = miracles.fire_on(building)
		if fire and fire.is_burning():
			fire.douse(M.guard_douse * counts[&"guard"] * dt)
