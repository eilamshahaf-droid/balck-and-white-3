class_name BuildingMenus
extends Node
## The second wheels of a building of yours: the upgrades for its kind (home,
## sermon house or workplace), posts for free believers in sermon houses and
## shops, and training missionaries and priests in sermon houses. Prices and effects live in Population and
## Treasury; this only builds the slices and carries out the choice.

const S: HandSettings = preload("res://data/hand_settings.tres")
const U: UnitSettings = preload("res://data/units.tres")

## What each upgrade is called on the wheel, and what it does.
const UPGRADE_INFO := {
	BuildingUpgrades.Kind.ELEVATOR: ["Elevator", "comfort up", Color(0.6, 0.85, 1.0)],
	BuildingUpgrades.Kind.ROOF_GARDEN: ["Roof Garden", "comfort up", Color(0.55, 0.9, 0.5)],
	BuildingUpgrades.Kind.CAMERAS: ["Cameras", "fear up", Color(0.9, 0.5, 0.45)],
	BuildingUpgrades.Kind.GATE: ["Gate", "fear up", Color(0.75, 0.45, 0.7)],
	BuildingUpgrades.Kind.LOUDSPEAKER: ["Loudspeaker", "priests reach further", Color(1.0, 0.85, 0.4)],
	BuildingUpgrades.Kind.BANNERS: ["Banners", "preaching stronger", Color(0.85, 0.5, 0.9)],
	BuildingUpgrades.Kind.LECTURE_HALL: ["Lecture Hall", "stronger preaching", Color(0.6, 0.75, 1.0)],
	BuildingUpgrades.Kind.STOREFRONT: ["Storefront", "shop income", Color(0.95, 0.7, 0.35)],
	BuildingUpgrades.Kind.GYM: ["Training Hall", "trains fighters", Color(0.9, 0.45, 0.4)],
	BuildingUpgrades.Kind.REAL_ESTATE: ["Real Estate", "cheaper buying nearby", Color(0.5, 0.8, 0.6)],
	BuildingUpgrades.Kind.SEMINARY: ["Seminary", "trains priests", Color(0.95, 0.95, 1.0)],
	BuildingUpgrades.Kind.RESTAURANT: ["Restaurant", "comfort up", Color(1.0, 0.75, 0.5)],
}
## Post slices: the job, and the rank of who takes it.
const POSTS := {
	&"pray": [Resident.Job.PRAY, Resident.Rank.BELIEVER],
	&"serve": [Resident.Job.PRIEST, Resident.Rank.PRIEST],
	&"shop": [Resident.Job.SHOP, Resident.Rank.BELIEVER],
}
## Training slices: what each turns someone into.
const TRAINING := {
	&"missionary": Resident.Rank.MISSIONARY,
	&"priest": Resident.Rank.PRIEST,
}

@export var population: Population
@export var treasury: Treasury


## Does `building` take free believers as staff?
func has_posts(building: Node3D) -> bool:
	return building.is_in_group(Population.PRAYER_HOUSES) or building.is_in_group(Population.SHOPS)


## The upgrades this kind of building can buy (a home, a sermon house, a workplace).
func upgrade_items(building: Node3D) -> Array[Dictionary]:
	var cost := population.upgrades.cost(building)
	var items: Array[Dictionary] = []
	for kind in population.upgrades.kinds_for(building):
		var info: Array = UPGRADE_INFO[kind]
		var bought := population.upgrades.count_of(building, kind)
		items.append({"id": StringName(str(kind)), "label": info[0], "effect": info[1],
				"color": info[2], "enabled": treasury.can_afford(cost),
				"note": "$%d%s" % [roundi(cost), " (x%d)" % bought if bought > 0 else ""]})
	return items


func post_items(building: Node3D) -> Array[Dictionary]:
	var p := building.global_position
	var believers := population.free_believers_near(p, S.staff_reach).size()
	var items: Array[Dictionary] = []
	if building.is_in_group(Population.PRAYER_HOUSES):
		items.append(_post_item(&"pray", "Send to Pray", Color(1.0, 0.88, 0.5), believers))
		var priests := population.free_believers_near(p, S.staff_reach, Resident.Rank.PRIEST).size()
		items.append(_post_item(&"serve", "Serve as " + U.title(Resident.Rank.PRIEST),
				U.color(Resident.Rank.PRIEST), priests))
		for id: StringName in TRAINING:
			var rank: Resident.Rank = TRAINING[id]
			var free := population.staffing.trainees_for(rank, building, S.staff_reach).size()
			var item := _post_item(id, "Train " + U.title(rank), U.color(rank), free)
			if not population.staffing.can_train(rank, building):
				item.enabled = false
				item.note = "not here" if rank == Resident.Rank.PRIEST else "house full"
			elif not treasury.can_afford(_training_cost(rank)):
				item.enabled = false
				item.note = "needs $%d" % roundi(_training_cost(rank))
			items.append(item)
	if building.is_in_group(Population.SHOPS):
		items.append(_post_item(&"shop", "Work Here", Color(0.5, 0.9, 0.55), believers))
	return items


## Buy the upgrade `id` (an `Upgrade` value as text) for `building` if there is money for it.
func buy_upgrade(id: StringName, building: Node3D) -> bool:
	var kind := int(String(id)) as BuildingUpgrades.Kind
	var cost := population.upgrades.cost(building)
	if not population.upgrades.kinds_for(building).has(kind) or not treasury.can_afford(cost):
		return false
	treasury.spend_money(cost)
	population.upgrade(building, kind)
	return true


## Send a free believer from the street nearby to the post or training `id` in `building`.
func send_to_post(id: StringName, building: Node3D) -> bool:
	var p := building.global_position
	if TRAINING.has(id):
		var rank: Resident.Rank = TRAINING[id]
		if not treasury.can_afford(_training_cost(rank)):
			return false
		for r in population.staffing.trainees_for(rank, building, S.staff_reach):
			if population.staffing.train(r, rank, building):
				treasury.spend_money(_training_cost(rank))
				return true
		return false
	if not POSTS.has(id):
		return false
	var job: Resident.Job = POSTS[id][0]
	for r in population.free_believers_near(p, S.staff_reach, POSTS[id][1]):
		if population.staffing.assign(r, job, building):
			return true
	return false


func _training_cost(rank: Resident.Rank) -> float:
	return U.priest_cost if rank == Resident.Rank.PRIEST else 0.0


func _post_item(id: StringName, label: String, color: Color, free: int) -> Dictionary:
	var title: String = U.title(Resident.Rank.BELIEVER).to_lower()
	if TRAINING.has(id):
		title = U.title(TRAINING[id] - 1).to_lower()
	elif POSTS.has(id):
		title = U.title(POSTS[id][1]).to_lower()
	return {"id": id, "label": label, "color": color, "enabled": free > 0,
			"note": "%d %s%s ready" % [free, title, "" if free == 1 else "s"]}
