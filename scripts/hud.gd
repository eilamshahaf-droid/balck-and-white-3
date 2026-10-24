extends Label
## The numbers the player is allowed to see: believers, exposure, and how
## strong the hand is where it is. Belief itself stays hidden (B shows it, for debugging).

@onready var faith: Node = get_node("../../Faith")
@onready var hand: Node3D = get_node("../../GodHand")


func _process(_delta: float) -> void:
	text = "Believers: %d    Exposure: %d%%    Hand strength here: %.1f (person 1, tree 3, taxi 4)" % [
		faith.believers, roundi(faith.exposure * 100.0), hand.strength_here]
