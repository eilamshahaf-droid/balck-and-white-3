extends Label
## The numbers the player is allowed to see: the belief pool, believers and
## exposure. Belief itself stays hidden (B shows it, for debugging).

@onready var faith: Node = get_node("../../Faith")


func _process(_delta: float) -> void:
	text = "Belief: %d    Believers: %d    Exposure: %d%%" % [
		floori(faith.belief_pool), faith.believers, roundi(faith.exposure * 100.0)]
