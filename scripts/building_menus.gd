class_name BuildingMenus
extends Node
## The second wheels of a building of yours: housing upgrades (elevator, roof
## garden for comfort; cameras, gate for fear) and posts for free believers in
## prayer houses and shops. Prices and effects live in Population and
## Treasury; this only builds the slices and carries out the choice.

const S: HandSettings = preload("res://data/hand_settings.tres")

const UPGRADES := {
	&"elevator": Population.Upgrade.ELEVATOR,
	&"garden": Population.Upgrade.ROOF_GARDEN,
	&"cameras": Population.Upgrade.CAMERAS,
	&"gate": Population.Upgrade.GATE,
}
const POSTS := {
	&"pray": Resident.Job.PRAY,
	&"priest": Resident.Job.PRIEST,
	&"shop": Resident.Job.SHOP,
}

@export var population: Population
@export var treasury: Treasury


## Does `building` take free believers as staff?
func has_posts(building: Node3D) -> bool:
	return building.is_in_group(Population.PRAYER_HOUSES) or building.is_in_group(Population.SHOPS)


func upgrade_items(building: Node3D) -> Array[Dictionary]:
	var cost := population.upgrade_cost(building)
	var price := "$%d" % roundi(cost)
	var items: Array[Dictionary] = [
		{"id": &"elevator", "label": "Elevator", "effect": "comfort up", "color": Color(0.6, 0.85, 1.0)},
		{"id": &"garden", "label": "Roof Garden", "effect": "comfort up", "color": Color(0.55, 0.9, 0.5)},
		{"id": &"cameras", "label": "Cameras", "effect": "fear up", "color": Color(0.9, 0.5, 0.45)},
		{"id": &"gate", "label": "Gate", "effect": "fear up", "color": Color(0.75, 0.45, 0.7)},
	]
	for item in items:
		item.note = price
		item.enabled = treasury.can_afford(cost)
	return items


func post_items(building: Node3D) -> Array[Dictionary]:
	var free := population.free_believers_near(building.global_position, S.staff_reach).size()
	var items: Array[Dictionary] = []
	if building.is_in_group(Population.PRAYER_HOUSES):
		items.append({"id": &"pray", "label": "Send to Pray", "color": Color(1.0, 0.88, 0.5)})
		items.append({"id": &"priest", "label": "Train Priest", "color": Color(0.95, 0.95, 1.0)})
	if building.is_in_group(Population.SHOPS):
		items.append({"id": &"shop", "label": "Work Here", "color": Color(0.5, 0.9, 0.55)})
	for item in items:
		item.note = "%d free nearby" % free
		item.enabled = free > 0
	return items


## Buy the upgrade `id` for `building` if there is money for it.
func buy_upgrade(id: StringName, building: Node3D) -> bool:
	var cost := population.upgrade_cost(building)
	if not UPGRADES.has(id) or not treasury.can_afford(cost):
		return false
	treasury.spend_money(cost)
	population.upgrade(building, UPGRADES[id])
	return true


## Send a free believer from the street nearby to the post `id` in `building`.
func send_to_post(id: StringName, building: Node3D) -> bool:
	if not POSTS.has(id):
		return false
	for r in population.free_believers_near(building.global_position, S.staff_reach):
		if population.assign(r, POSTS[id], building):
			return true
	return false
