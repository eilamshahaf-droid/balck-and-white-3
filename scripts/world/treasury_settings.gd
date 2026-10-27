class_name TreasurySettings
extends Resource
## Tunables for the cult's money (treasury.gd). Open data/treasury.tres in
## Godot and change values in the Inspector.

@export var start_money := 250.0
@export var tick := 1.0                     # seconds between incomes
## Every believer drops something in the collection box.
@export var tithe_per_believer := 0.05      # money per second per believer
## A building of yours with the Facade decree opens shops run by believers.
@export var shop_income := 1.5              # money per second per shop building
@export var shop_income_per_believer := 0.3 # and per believer who lives there
