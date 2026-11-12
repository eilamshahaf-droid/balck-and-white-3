class_name TreasurySettings
extends Resource
## Tunables for the cult's money (treasury.gd). Open data/treasury.tres in
## Godot and change values in the Inspector. Every building of yours earns or
## costs money each second: the Committee's dues (never "rent": the god is against
## landlords) while it has no use, upkeep once it has one
## (except a shop, which earns), more upkeep for luxury and every floor level.
## District wealth (data/districts.tres) scales what a building earns.

@export var start_money := 250.0
@export var tick := 1.0                     # seconds between payments

## Every seated believer (Population.seats) costs this much money per minute.
@export var believer_upkeep := 1.5
## Upkeep can overdraw the treasury, but never below debt_floor: past it, costs stop
## being charged so the game never spirals. While overdrawn nothing that costs money can
## be bought or trained (can_afford), and the Secretary minutes it once.
@export var debt_floor := -1000.0
@export var overdrawn_line := "Minutes: the treasury is overdrawn; no further expenditure is minuted."
@export var overdrawn_color := Color(1.0, 0.45, 0.35)
## Free spaces, bought in tiers (built when the feature freeze lifts): the price of each
## tier, and how much more the believers within free_space_reach blocks of it make.
@export var free_space_costs := PackedFloat32Array([400.0, 1200.0])
@export var free_space_output := PackedFloat32Array([0.15, 0.25])
@export var free_space_reach := 2

@export_group("Collection box")

@export_group("Dues: a building of yours with no use")
@export var dues_per_resident := 0.03       # money per second per resident

@export_group("Uses: a Change Use decree")
## Every use but the shop costs upkeep instead of bringing dues in.
@export var use_upkeep := 1.2               # money per second
@export var shop_use := "Shop"
@export var shop_income := 2.0              # money per second
@export var shop_income_per_believer := 0.25

@export_group("Luxury: faster, and dearer to run")
@export var luxury_speed := 1.6             # what the building does, this much faster
@export var luxury_upkeep := 1.5            # money per second on top

@export_group("Floors: more room, less and less worth it")
## Efficiency = 1 + floor_gain * (1 - floor_falloff ^ levels): the first floors
## help most, later ones barely. Upkeep = floor_upkeep * levels², small for the
## first levels and soon more than they bring in.
@export var floor_gain := 0.8
@export_range(0.0, 1.0) var floor_falloff := 0.55
@export var floor_upkeep := 0.05            # money per second, times the levels squared
