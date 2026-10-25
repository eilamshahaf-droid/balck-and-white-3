class_name PlanningSettings
extends Resource
## Every number of the city-planning model, in one place (like BW2's
## PlacementData). Open data/planning.tres in Godot and change values in the
## Inspector. Each structure gives each metric a value at its centre that fades
## to zero at its radius.
##
## Metrics: belief (prayer made here), commerce, quality (quality of life),
## fear, influence.

@export_group("Landmarks (plot level)")
## name -> { metric: [value at centre, radius in metres] }
@export var landmarks := {
	"temple": {"belief": [10.0, 70.0], "influence": [3.0, 70.0], "quality": [1.0, 40.0]},
	"square": {"quality": [6.0, 45.0], "influence": [4.0, 60.0], "belief": [2.0, 45.0]},
	"park": {"quality": [8.0, 65.0], "belief": [1.0, 40.0], "fear": [-1.5, 50.0]},
	"station": {"commerce": [6.0, 110.0], "quality": [3.0, 80.0], "influence": [2.0, 110.0]},
	"tower": {"influence": [6.0, 90.0], "commerce": [3.0, 60.0]},
	"factory": {"commerce": [8.0, 70.0], "quality": [-6.0, 70.0], "fear": [3.0, 60.0]},
	"monument": {"fear": [6.0, 100.0], "influence": [3.0, 100.0], "belief": [2.0, 60.0], "quality": [-2.0, 50.0]},
}
## How much of the block each landmark takes, in metres along the block.
@export var landmark_width := {
	"temple": 20.0, "square": 24.0, "park": 44.0, "station": 18.0, "tower": 14.0,
	"factory": 30.0, "monument": 16.0,
}
## Seen from far away, a tall landmark reaches further (Lynch's landmark; BW2's hill bonus).
@export var tower_height := 90.0
@export var height_reach_per_metre := 0.8    # extra radius for each metre of height above 30 m

@export_group("Street details (street level)")
@export var details := {
	"tree": {"quality": [1.5, 22.0]},
	"bench": {"quality": [1.0, 18.0], "influence": [1.0, 18.0]},
	"shrine": {"belief": [2.5, 25.0]},
	"camera": {"fear": [2.5, 30.0], "quality": [-0.6, 30.0]},
	"billboard": {"influence": [1.8, 35.0], "commerce": [1.5, 30.0], "quality": [-0.5, 20.0]},
}
## Closing a street segment to cars and turning it into a plaza (Jacobs' short blocks).
@export var plaza := {"quality": [4.0, 40.0], "influence": [2.5, 45.0], "commerce": [1.0, 40.0]}

@export_group("Zoning (neighbourhood level)")
## What each built lot of a zone gives the area around it.
@export var zone_effects := {
	"residential": {},
	"commercial": {"commerce": [1.2, 50.0], "quality": [0.4, 30.0]},
	"industrial": {"commerce": [1.5, 60.0], "quality": [-1.5, 50.0], "fear": [0.3, 40.0]},
}
@export var floors_per_density := [3, 7, 18]  # floors for density 1, 2, 3
## Lots in a block are this wide, at random (NYC lots are 25 ft and merge into bigger buildings).
@export var lot_width_min := 6.0
@export var lot_width_max := 14.0
@export var residents_per_floor := 8
@export var build_interval := 0.15          # seconds between buildings rising or being converted
## Better places get taller buildings: land value = commerce + quality + influence, full at this.
@export var land_value_full := 14.0
## Mixed use (Jane Jacobs): a block next to a different zone gets this bonus.
@export var mixed_use_quality := 1.5
@export var mixed_use_commerce := 1.0
## Homes won't go up where life is worse than this.
@export var min_quality_to_build_homes := -3.0
## Shops need customers: residents within this distance.
@export var shop_customer_radius := 120.0
@export var residents_per_shop := 120

@export_group("Character (which god the street looks like)")
## A building is rebuilt in the look of a path once that path's score around it
## passes this: good = quality + belief/2 - 2, evil = 2 x fear - 1, grey = influence - 1.
@export var character_threshold := 1.5
## Good streets stay human-scale (Gehl); evil housing blocks grow into slabs.
@export var good_height_factor := 0.75
@export var evil_height_factor := 1.35
@export var grey_height_factor := 1.2

@export_group("What the city makes")
## Prayer by each resident, scaled by the belief field where they live (0..1 at this value).
@export var belief_field_full := 10.0
@export var prayer_per_resident := 0.02     # belief per minute at a full belief field
@export var fear_prayer := 0.5              # frightened people pray too, at this share of fear/belief_field_full
@export var migrants_per_quality := 0.002   # people per minute who move in, per resident per point of quality
@export var power_per_fear := 0.01          # compliance and recruits per minute, per resident per point of fear
@export var money_per_job := 0.05           # money per minute per job, more where commerce is high
