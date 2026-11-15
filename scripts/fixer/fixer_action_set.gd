class_name FixerActionSet
extends Resource
## The Fixer's actions at one key building, found by the name on its sign
## (DistrictSettings.key_names).

@export var key := ""
@export var actions: Array[FixerAction] = []
