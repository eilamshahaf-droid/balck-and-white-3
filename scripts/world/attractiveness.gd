class_name Attractiveness
extends Node
## The attractiveness gate (Eilam's numbers of 2026-11-15, GDD "Two ways to resist"). A
## district's attractiveness is one number: the Office, every building you hold (its
## homes) and the rooms that draw people (the utilities: in the Slums the Laundry Room,
## RoomKind.attraction). An ordinary building can only be taken while it is at least that
## building's threshold, which rises with every ordinary building you hold; the first few
## are free. Key buildings skip it (the Fixer opens them). A building lost lowers the
## threshold again.

const S: DistrictSettings = preload("res://data/districts.tres")

@export var districts: Districts
@export var rooms: Rooms


## District `d`'s attractiveness now.
func value(d: int) -> float:
	var out := 0.0
	for i in districts.buildings.size():
		if districts.buildings[i] == null or not districts.is_yours(i) \
				or districts.district_of(i) != d:
			continue
		out += S.office_attraction if districts.is_base(districts.buildings[i]) \
				else S.building_attraction
		out += rooms.totals_of(i).attraction
	return out


## Ordinary buildings of district `d` you hold: not the Office, not a key building.
func ordinary_held(d: int) -> int:
	var n := 0
	for i in districts.buildings.size():
		if districts.buildings[i] != null and districts.is_yours(i) and _ordinary(i) \
				and districts.district_of(i) == d:
			n += 1
	return n


## The attractiveness district `d` needs for its next ordinary building.
func next_threshold(d: int) -> float:
	return S.attraction_step * maxi(ordinary_held(d) + 1 - S.free_buildings, 0)


## The meter shows once the gate matters: from the first building that is not free.
func shown(d: int) -> bool:
	return ordinary_held(d) + 1 > S.free_buildings


## Why building `index` can't be taken for want of attractiveness; "" when it can.
func why_not(index: int) -> String:
	if not _ordinary(index):
		return ""
	var d := districts.district_of(index)
	var have := value(d)
	var need := next_threshold(d)
	return "" if have >= need else "attractiveness %d of %d" % [floori(have), ceili(need)]


func _ordinary(index: int) -> bool:
	return not districts.is_key(index) and not districts.is_base(districts.buildings[index])
