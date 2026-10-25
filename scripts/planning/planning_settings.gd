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
	"station": {"commerce": [6.0, 110.0], "quality": [3.0, 80.0], "influence": [2.0, 110.0]},
	"square": {"quality": [6.0, 45.0], "influence": [4.0, 60.0], "belief": [2.0, 45.0]},
	"tower": {"influence": [6.0, 90.0], "commerce": [3.0, 60.0]},
	"factory": {"commerce": [8.0, 70.0], "quality": [-6.0, 70.0], "fear": [3.0, 60.0]},
}
## Seen from far away, a tall landmark reaches further (Lynch's landmark; BW2's hill bonus).
@export var tower_height := 90.0
@export var height_reach_per_metre := 0.8    # extra radius for each metre of height above 30 m

@export_group("Street details (street level)")
@export var details := {
	"tree": {"quality": [1.5, 22.0]},
	"bench": {"quality": [1.0, 18.0], "influence": [1.0, 18.0]},
	"camera": {"fear": [2.5, 30.0], "quality": [-0.6, 30.0]},
	"shrine": {"belief": [2.5, 25.0]},
}

@export_group("Zoning (neighbourhood level)")
## What each built lot of a zone gives the area around it.
@export var zone_effects := {
	"residential": {},
	"commercial": {"commerce": [1.2, 50.0], "quality": [0.4, 30.0]},
	"industrial": {"commerce": [1.5, 60.0], "quality": [-1.5, 50.0], "fear": [0.3, 40.0]},
}
@export var floors_per_density := [2, 6, 18]  # floors for density 1, 2, 3
@export var residents_per_floor := 8
@export var build_interval := 0.25          # seconds between new buildings rising
## Mixed use (Jane Jacobs): a block next to a different zone gets this bonus.
@export var mixed_use_quality := 1.5
@export var mixed_use_commerce := 1.0
## Homes won't go up where life is worse than this.
@export var min_quality_to_build_homes := -3.0
## Shops need customers: residents within this distance.
@export var shop_customer_radius := 120.0
@export var residents_per_shop := 40

@export_group("Belief")
## Prayer made by each resident, scaled by the belief field where they live (0..1 at this value).
@export var belief_field_full := 10.0
@export var prayer_per_resident := 0.02     # belief per minute at a full belief field
