class_name TreasurySettings
extends Resource
## Tunables for the cult's money (treasury.gd). Open data/treasury.tres in
## Godot and change values in the Inspector. Every building of yours earns or
## costs money each second: rent while it has no use, upkeep once it has one
## (except a shop, which earns), more upkeep for luxury and every floor level.
## District wealth (data/districts.tres) scales what a building earns.

@export var start_money := 250.0
@export var tick := 1.0                     # seconds between payments

@export_group("Collection box")
@export var tithe_per_believer := 0.05      # money per second per believer

@export_group("Rent: a building of yours with no use")
@export var rent_per_resident := 0.1        # money per second per resident

@export_group("Uses: a Change Use decree")
## Every use but the shop costs upkeep instead of bringing rent in.
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
