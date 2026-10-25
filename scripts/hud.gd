extends Label
## The numbers the player is allowed to see: the belief pool, believers,
## exposure, and how strong the hand is where it is. Belief itself stays hidden (B shows it, for debugging).

@onready var faith: Node = get_node("../../Faith")
@onready var hand: Node3D = get_node("../../GodHand")


func _process(_delta: float) -> void:
	text = "Belief: %d    Believers: %d    Exposure: %d%%    Hand strength here: %.1f (person 1, tree 3, taxi 4)" % [
		floori(faith.belief_pool), faith.believers, roundi(faith.exposure * 100.0), hand.strength_here]
	if hand.held and hand.grip < 1.0:
		text += "    Too heavy here: costs belief"
