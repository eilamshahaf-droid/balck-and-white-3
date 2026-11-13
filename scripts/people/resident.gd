class_name Resident
extends RefCounted
## Who a resident is, apart from the body walking the street: name, archetype,
## home, work, family, friends, rank and the hidden values. The body (citizen.gd)
## reads and writes these, so the person survives when the body changes, and
## most residents are indoors with no body at all.
##
## A resident is won over in one step (Population.attempt): they become a
## believer, who can then be trained into a missionary and a priest.

## Ordered: everything from BELIEVER up counts as a believer.
enum Rank { RESIDENT, BELIEVER, MISSIONARY, PRIEST, AGENT, HIGH_PRIEST }
## What a believer does for the cult: FREE believers have no post. PRAY and
## PRIEST staff a sermon house, SHOP staffs a shop, TRAIN is training in a sermon house.
## MANAGER: a rep who took a building over stays there and runs it; the building is yours
## while it has one.
enum Job { FREE, PRAY, SHOP, PRIEST, TRAIN, MANAGER }

## Index in Population.residents; -1 for a passer-by the city doesn't count.
var id := -1
var first_name := ""
var last_name := ""
var archetype: ResidentArchetype
var rank := Rank.RESIDENT
## Buildings from the city's "buildings" group. work is null for those who don't work.
var home: Node3D
var work: Node3D
## The building this person is sitting in on to claim it, or null.
var occupying: Node3D
## Ids (indexes into Population.residents) rather than references, so the
## ties don't form reference cycles that would never be freed.
var family: Array[int] = []
var friends: Array[int] = []
var has_phone := false

## Traits and assets, 0..1, from the archetype's levels.
var anxiety := 0.5
var sociability := 0.5
var curiosity := 0.5
var skepticism := 0.5
var wealth := 0.5
var connections := 0.5
var faith := 0.5
## Scales converting; set by rank.
var charisma := 0.0

## What a miracle that hurts leaves behind, 0..1.
var fear := 0.0
var color := Color.WHITE
var job := Job.FREE
## While training: the rank they will have, and the seconds left.
var training_for := Rank.RESIDENT
var training_left := 0.0
## False once the person died (a building burned down around them).
var alive := true
## Seconds left in jail (an arrested special agent); off the street meanwhile.
var jailed_left := 0.0
## The building this person works in (null while FREE); their body stays around it.
var post: Node3D
## Null while indoors.
var body: Citizen


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func is_believer() -> bool:
	return rank >= Rank.BELIEVER


## Missionaries and the high priest win people over.
func preaches() -> bool:
	return rank == Rank.MISSIONARY or rank == Rank.HIGH_PRIEST


## Priests and the high priest serve in a sermon house, drawn larger.
func is_priest() -> bool:
	return rank == Rank.PRIEST or rank == Rank.HIGH_PRIEST
