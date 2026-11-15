class_name Impression
extends Node
## The gate on ordinary buildings (the Designer's plan for 0.26.0, from Eilam's playtest).
## A building is impressed by the buildings of yours within the influence radius
## (Districts.reach): each counts for a little, and more for the open rooms in it
## (RoomKind.impression: a home, a shop, the Laundry Room). A Rep can only start on an
## ordinary building once its impression reaches what the next one needs, which rises
## with every ordinary building you hold. Key buildings (the Fixer opens them) and the
## Office skip it. The player sees it only on the card under the hand.

const S: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts
@export var rooms: Rooms


## The impression your buildings make on building `index`.
func of(index: int) -> float:
	var out := 0.0
	for j in districts.yours_within(index, districts.reach):
		out += S.impression_per_building + rooms.totals_of(j).impression
	return out


## Ordinary buildings of district `d` you hold: not the Office, not a key building.
func ordinary_held(d: int) -> int:
	var n := 0
	for i in districts.buildings.size():
		if districts.buildings[i] != null and districts.is_yours(i) and applies(i) \
				and districts.district_of(i) == d:
			n += 1
	return n


## The impression the next ordinary building of district `d` needs.
func required(d: int) -> float:
	return S.impression_start + S.impression_step * maxi(ordinary_held(d) - S.impression_free, 0)


## Building `index` is an ordinary one, so the gate applies to it.
func applies(index: int) -> bool:
	return not districts.is_key(index) and not districts.is_base(districts.buildings[index])


## Why building `index` can't be worked on for want of impression; "" when it can.
func why_not(index: int) -> String:
	if not applies(index):
		return ""
	var have := of(index)
	var need := required(districts.district_of(index))
	return "" if have >= need else "impression %d of %s: %s" % [floori(have), _num(need),
			S.impression_remedy]


## One decimal when it has one: 3, 3.3.
static func _num(x: float) -> String:
	return str(roundi(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
