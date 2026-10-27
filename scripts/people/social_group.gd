class_name SocialGroup
extends Resource
## One of the city's groups (students, bankers, police...). Every resident
## belongs to one, and gets its hidden traits from the group's ranges, so we
## tune a handful of groups instead of thousands of people.

enum Workplace { NONE, OFFICE, STREET }
## The ways the cult wins people over. Each group answers them differently:
## retirees a friendly visit, bankers money, police force.
enum Route { PREACH, MONEY, FORCE }

@export var title := ""
## Relative share of the city's residents; the shares need not add up to 1.
@export var share := 1.0
## Hidden skepticism k is rolled in this range: 0 believes easily, 1 always finds a rational explanation.
@export_range(0.0, 1.0) var skepticism_min := 0.2
@export_range(0.0, 1.0) var skepticism_max := 0.8
## Where they work: nowhere, a glass office tower, or a low building on the street.
@export var workplace := Workplace.STREET
## Hidden wealth (0 poor .. 1 rich) is rolled in this range.
@export_range(0.0, 1.0) var wealth_min := 0.2
@export_range(0.0, 1.0) var wealth_max := 0.6

@export_group("Response to each route")
## Multiplies every push toward belief that comes by that route; 1 = average.
@export var preach_response := 1.0
@export var money_response := 1.0
@export var force_response := 1.0


func response(route: Route) -> float:
	match route:
		Route.MONEY:
			return money_response
		Route.FORCE:
			return force_response
	return preach_response
