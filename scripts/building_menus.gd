class_name BuildingMenus
extends Node
## The second wheels of a building of yours: the upgrades for its kind (home,
## prayer house or workplace) and posts for free believers in prayer houses and
## shops. Prices and effects live in Population and
## Treasury; this only builds the slices and carries out the choice.

const S: HandSettings = preload("res://data/hand_settings.tres")

## What each upgrade is called on the wheel, and what it does.
const UPGRADE_INFO := {
	Population.Upgrade.ELEVATOR: ["Elevator", "comfort up", Color(0.6, 0.85, 1.0)],
	Population.Upgrade.ROOF_GARDEN: ["Roof Garden", "comfort up", Color(0.55, 0.9, 0.5)],
	Population.Upgrade.CAMERAS: ["Cameras", "fear up", Color(0.9, 0.5, 0.45)],
	Population.Upgrade.GATE: ["Gate", "fear up", Color(0.75, 0.45, 0.7)],
	Population.Upgrade.LOUDSPEAKER: ["Loudspeaker", "priests reach further", Color(1.0, 0.85, 0.4)],
	Population.Upgrade.BANNERS: ["Banners", "preaching stronger", Color(0.85, 0.5, 0.9)],
	Population.Upgrade.LECTURE_HALL: ["Lecture Hall", "stronger preaching", Color(0.6, 0.75, 1.0)],
	Population.Upgrade.STOREFRONT: ["Storefront", "shop income", Color(0.95, 0.7, 0.35)],
	Population.Upgrade.GYM: ["Training Hall", "trains fighters", Color(0.9, 0.45, 0.4)],
	Population.Upgrade.REAL_ESTATE: ["Real Estate", "cheaper buying nearby", Color(0.5, 0.8, 0.6)],
	Population.Upgrade.SEMINARY: ["Seminary", "trains priests", Color(0.95, 0.95, 1.0)],
	Population.Upgrade.RESTAURANT: ["Restaurant", "comfort up", Color(1.0, 0.75, 0.5)],
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


## The upgrades this kind of building can buy (a home, a prayer house, a workplace).
func upgrade_items(building: Node3D) -> Array[Dictionary]:
	var cost := population.upgrade_cost(building)
	var items: Array[Dictionary] = []
	for kind in population.upgrades_for(building):
		var info: Array = UPGRADE_INFO[kind]
		var bought := population.count_of(building, kind)
		items.append({"id": StringName(str(kind)), "label": info[0], "effect": info[1],
				"color": info[2], "enabled": treasury.can_afford(cost),
				"note": "$%d%s" % [roundi(cost), " (x%d)" % bought if bought > 0 else ""]})
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


## Buy the upgrade `id` (an `Upgrade` value as text) for `building` if there is money for it.
func buy_upgrade(id: StringName, building: Node3D) -> bool:
	var kind := int(String(id)) as Population.Upgrade
	var cost := population.upgrade_cost(building)
	if not population.upgrades_for(building).has(kind) or not treasury.can_afford(cost):
		return false
	treasury.spend_money(cost)
	population.upgrade(building, kind)
	return true


## Send a free believer from the street nearby to the post `id` in `building`.
func send_to_post(id: StringName, building: Node3D) -> bool:
	if not POSTS.has(id):
		return false
	for r in population.free_believers_near(building.global_position, S.staff_reach):
		if population.assign(r, POSTS[id], building):
			return true
	return false
