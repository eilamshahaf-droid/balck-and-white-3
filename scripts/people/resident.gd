class_name Resident
extends RefCounted
## Who a resident is, apart from the body walking the street: name, group,
## home, work, family, friends and the hidden values. The body (citizen.gd)
## reads and writes these, so the person survives when the body changes, and
## most residents are indoors with no body at all.
##
## Belief moves in stages (skeptic, curious, sympathizer, believer, zealot).
## One push can move a person at most one stage, so winning someone over takes
## several visits or offers.

enum Stage { SKEPTIC, CURIOUS, SYMPATHIZER, BELIEVER, ZEALOT }
## What a believer does for the cult: FREE believers have no post. PRAY and
## PRIEST staff a prayer house, SHOP staffs a shop.
enum Job { FREE, PRAY, SHOP, PRIEST }

const B: Balance = preload("res://data/balance.tres")

## Index in Population.residents; -1 for a passer-by the city doesn't count.
var id := -1
var first_name := ""
var last_name := ""
var group: SocialGroup
## Buildings from the city's "buildings" group. work is null for those who don't work.
var home: Node3D
var work: Node3D
## The building this person is sitting in on to claim it, or null.
var occupying: Node3D
## Ids (indexes into Population.residents) rather than references, so the
## ties don't form reference cycles that would never be freed.
var family: Array[int] = []
var friends: Array[int] = []
## Hidden: -1 = total skeptic, +1 = devoted believer.
var belief := 0.0
## What this person believed before the cult reached them; belief drifts back to it.
var baseline := 0.0
## Hidden personal coefficient k: 0 believes easily, 1 always finds a rational explanation.
var skepticism := 0.5
var has_phone := false
## Hidden meters, 0..1. Comfort and fear are the two ways to play: a priest
## only reaches people who are comfortable and not afraid, force works on the
## frightened, and too much fear makes people move away.
var wealth := 0.5
var comfort := 0.5
var fear := 0.0
var color := Color.WHITE
var job := Job.FREE
## False once the person died (a building burned down around them).
var alive := true
## The building this person works in (null while FREE); their body stays around it.
var post: Node3D
## Null while indoors.
var body: Citizen


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func stage() -> Stage:
	return stage_of(belief)


static func stage_of(value: float) -> Stage:
	if value >= B.zealot_from:
		return Stage.ZEALOT
	if value >= B.believer_threshold:
		return Stage.BELIEVER
	if value >= B.sympathizer_from:
		return Stage.SYMPATHIZER
	if value >= B.curious_from:
		return Stage.CURIOUS
	return Stage.SKEPTIC


## A push toward belief by `route`, weighted by how this person's group
## answers that route. Pushes away from belief are not weighted.
func persuade(route: SocialGroup.Route, amount: float) -> void:
	if amount > 0.0:
		amount *= B.persuasion_scale * (group.response(route) if group else 1.0)
	shift(amount)


## Move belief by `amount`, but at most into the next stage up or down.
func shift(amount: float) -> void:
	var s := stage()
	var limit := 1.0
	if amount > 0.0:
		if s + 2 <= Stage.ZEALOT:
			limit = _stage_start(s + 2) - 0.001
		belief = minf(belief + amount, limit)
	else:
		limit = _stage_start(maxi(s - 1, 0))
		belief = maxf(belief + amount, limit)


static func _stage_start(s: int) -> float:
	match s:
		Stage.CURIOUS:
			return B.curious_from
		Stage.SYMPATHIZER:
			return B.sympathizer_from
		Stage.BELIEVER:
			return B.believer_threshold
		Stage.ZEALOT:
			return B.zealot_from
	return -1.0
