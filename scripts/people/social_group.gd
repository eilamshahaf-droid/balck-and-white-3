class_name SocialGroup
extends Resource
## One of the city's groups (students, bankers, police...). Every resident
## belongs to one, and gets its hidden traits from the group's ranges, so we
## tune a handful of groups instead of thousands of people.

enum Workplace { NONE, OFFICE, STREET }

@export var title := ""
## Relative share of the city's residents; the shares need not add up to 1.
@export var share := 1.0
## Hidden skepticism k is rolled in this range: 0 believes easily, 1 always finds a rational explanation.
@export_range(0.0, 1.0) var skepticism_min := 0.2
@export_range(0.0, 1.0) var skepticism_max := 0.8
## Where they work: nowhere, a glass office tower, or a low building on the street.
@export var workplace := Workplace.STREET
