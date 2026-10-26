class_name Resident
extends RefCounted
## Who a resident is, apart from the body walking the street: name, group,
## home, work, family, friends and the hidden values. The body (citizen.gd)
## reads and writes these, so the person survives when the body changes.

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
## Hidden personal coefficient k: 0 believes easily, 1 always finds a rational explanation.
var skepticism := 0.5
var has_phone := false
var body: Citizen


func full_name() -> String:
	return "%s %s" % [first_name, last_name]
