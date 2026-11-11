class_name ResidentArchetype
extends Resource
## One of the eight kinds of resident (GDD section 3): fixed traits and assets,
## and how much each of the four needs matters to them once they believe.
## Values are levels (low, medium, high) as in the GDD tables; ArchetypeSettings
## turns a level into a number, so one table tunes all eight.

enum Level { NONE, LOW, MEDIUM, HIGH }
enum Workplace { NONE, OFFICE, STREET }

@export var title := ""
## The district kinds (DistrictSettings.kinds) this archetype lives in, and in each
## its relative share of the residents (same order; shares need not add up to 1).
@export var lives_in: PackedStringArray = []
@export var shares: PackedFloat32Array = []
## Where they work: nowhere, a glass office tower, or a low building on the street.
@export var workplace := Workplace.STREET

@export_group("Traits")
## Lowers the influence others have on them (conversion chance).
@export var anxiety := Level.MEDIUM
## Raises their influence on others.
@export var sociability := Level.MEDIUM
## Raises the chance to convert them.
@export var curiosity := Level.MEDIUM
## Lowers the chance to convert them.
@export var skepticism := Level.MEDIUM

@export_group("Assets")
## Money they make for the cult as believers.
@export var wealth := Level.MEDIUM
## How many people they can be in touch with.
@export var connections := Level.MEDIUM
## Belief they make for the cult in a staffed sermon house.
@export var faith := Level.MEDIUM

@export_group("Needs: influence (how strongly each need affects them)")
@export var livelihood_influence := Level.MEDIUM
@export var security_influence := Level.MEDIUM
@export var pleasure_influence := Level.MEDIUM
@export var meaning_influence := Level.MEDIUM

@export_group("Needs: desire (how much of it they want)")
@export var livelihood_desire := Level.MEDIUM
@export var security_desire := Level.MEDIUM
@export var pleasure_desire := Level.MEDIUM
@export var meaning_desire := Level.MEDIUM


## This archetype's share of the residents of district kind `kind` (0 if it doesn't live there).
func share_in(kind: String) -> float:
	var i := lives_in.find(kind)
	return shares[i] if i >= 0 and i < shares.size() else 0.0
