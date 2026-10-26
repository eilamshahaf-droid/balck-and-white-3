extends Label
## The numbers the player is allowed to see: the belief pool, believers,
## exposure and the miracle power under the hand. Belief itself stays hidden
## (B shows it, for debugging).

@onready var faith: Node = get_node("../../Faith")
@onready var tools: Node = get_node("../../HandTools")
@onready var miracles: Node = get_node("../../Miracles")


func _process(_delta: float) -> void:
	text = "Belief: %d    Believers: %d    Exposure: %d%%    Miracle power here: %d%%" % [
		floori(faith.belief_pool), faith.believers, roundi(faith.exposure * 100.0),
		roundi(miracles.power_here * 100.0)]
	if tools.charged != &"":
		text += "    In the hand: %s (click to cast, right-click to drop)" % String(tools.charged).capitalize()
