class_name TreasurySettings
extends Resource
## Tunables for the money (treasury.gd). Open data/treasury.tres in Godot and change
## values in the Inspector. What sellers bring in and the loan are in data/followers.tres.

@export var start_money := 250.0
@export var tick := 1.0   # seconds between payments
