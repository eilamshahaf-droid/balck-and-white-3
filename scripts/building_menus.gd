class_name BuildingMenus
extends Node
## What the wheel of a building of yours offers (HandTools draws it and reports the
## choice). The first wheel: upgrades, more floors, the shop, and at the main Office
## training and a loan. "Upgrades" and "Shop" open a second wheel. Every slice says
## what it costs, or why it can't be had.

const F: FollowersSettings = preload("res://data/followers.tres")
const U: UnitSettings = preload("res://data/units.tres")
const D: DecreeSettings = preload("res://data/decrees.tres")
const Kind := BuildingUpgrades.Kind
## Name, what it does, and colour of each upgrade.
const LOOKS := {
	Kind.ATTRACTION: ["Attraction", "followers come faster", Color(0.55, 0.9, 0.5)],
	Kind.SECURITY: ["Security", "harder to turn back", Color(0.9, 0.5, 0.45)],
	Kind.SHOP: ["Bigger Shop", "room for more sellers", Color(0.95, 0.7, 0.35)],
	Kind.DESKS: ["More Desks", "room for more clerks", Color(0.95, 0.95, 1.0)],
	Kind.TRAINING: ["Training Room", "one more Rep at a time", Color(0.6, 0.75, 1.0)],
}

@export var districts: Districts
@export var followers: Followers
@export var treasury: Treasury
@export var faith: Faith
@export var population: Population
@export var decrees: Decrees


## The slices for `building`: the first wheel, or the second one for `group`
## (&"upgrades" or &"shop").
func items(building: Node3D, group := &"") -> Array[Dictionary]:
	var i := districts.index_of(building)
	match group:
		&"upgrades": return _upgrade_items(building, i)
		&"shop": return _shop_items(i)
	var out: Array[Dictionary] = []
	if districts.is_base(building):
		out.append(_slice(&"train_rep", "Train " + U.title(Resident.Rank.MISSIONARY),
				U.color(Resident.Rank.MISSIONARY), why_not_train(Resident.Rank.MISSIONARY),
				"%d paperwork" % roundi(F.rep_paperwork)))
		out.append(_slice(&"train_fixer", "Train " + U.title(Resident.Rank.AGENT),
				U.color(Resident.Rank.AGENT), why_not_train(Resident.Rank.AGENT),
				"%d paperwork" % roundi(F.fixer_paperwork)))
	out.append({"id": &"upgrades", "label": "Upgrades", "color": Color(0.6, 0.85, 1.0),
			"note": "$%d each" % roundi(followers.upgrades.cost(building))})
	out.append(_slice(&"floors", "+%d Floors" % D.floors_per_decree, Color(0.95, 0.7, 0.35),
			_why_not_decree(&"floors", building), decrees.price(&"floors", building)))
	if followers.has_shop(i):
		out.append({"id": &"shop", "label": "Shop", "color": Color(0.5, 0.9, 0.55),
				"note": "%d of %d sellers" % [followers.sellers_in(i), followers.shop_slots(i)]})
	else:
		out.append(_slice(&"open_shop", "Open a Shop", Color(0.5, 0.9, 0.55),
				_why_not_decree(&"use", building), decrees.price(&"use", building)))
	if districts.is_base(building):
		out.append(_slice(&"loan", "Loan $%d" % roundi(F.loan_money), Color(0.8, 0.62, 0.45),
				_why_not_loan(), "%d paperwork, pay back $%d" % [roundi(F.loan_paperwork), roundi(F.loan_owed)]))
	return out


## Carry out slice `id` on `building`. True when something was done.
func choose(id: StringName, building: Node3D) -> bool:
	var i := districts.index_of(building)
	match id:
		&"train_rep": return _train(Resident.Rank.MISSIONARY, building)
		&"train_fixer": return _train(Resident.Rank.AGENT, building)
		&"floors": return decrees.issue(&"floors", building)
		&"open_shop": return decrees.issue(&"use", building)
		&"loan": return treasury.borrow()
		&"seller_more", &"seller_less":
			followers.change_sellers(i, 1 if id == &"seller_more" else -1)
			return true
	for kind: Kind in followers.kinds_for(i):
		if id == _upgrade_id(kind) and treasury.spend_money(followers.upgrades.cost(building)):
			followers.upgrades.add(building, kind)
			return true
	return false


## Why nobody can start training for `rank` now; "" when one can.
func why_not_train(rank: Resident.Rank) -> String:
	var rep := rank == Resident.Rank.MISSIONARY
	if rep and population.reps_out >= followers.rep_cap():
		return "%d of %d Reps out: one must take a building first" \
				% [population.reps_out, followers.rep_cap()]
	if not rep and population.agent_count + population.staffing.training_for(rank) >= F.fixer_cap:
		return "%d at most" % F.fixer_cap
	if followers.idle() <= 0:
		return "no follower to spare"
	var cost := F.rep_paperwork if rep else F.fixer_paperwork
	if faith.belief_pool < cost:
		return "needs %d paperwork" % roundi(cost)
	return ""


## One follower leaves the pool and starts training at `building`.
func _train(rank: Resident.Rank, building: Node3D) -> bool:
	if why_not_train(rank) != "":
		return false
	var cost := F.rep_paperwork if rank == Resident.Rank.MISSIONARY else F.fixer_paperwork
	if not faith.spend(cost) or not followers.take_one():
		return false
	population.start_training(rank, building)
	return true


func _upgrade_items(building: Node3D, i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cost := followers.upgrades.cost(building)
	for kind: Kind in followers.kinds_for(i):
		var look: Array = LOOKS[kind]
		out.append({"id": _upgrade_id(kind), "label": look[0], "color": look[2],
				"note": "$%d  (level %d)" % [roundi(cost), followers.upgrades.level(building, kind)],
				"effect": look[1], "enabled": treasury.can_afford(cost)})
	return out


func _shop_items(i: int) -> Array[Dictionary]:
	var working := followers.sellers_in(i)
	var slots := followers.shop_slots(i)
	var more := "shop is full" if working >= slots \
			else ("no follower to spare" if followers.idle() <= 0 else "")
	return [
		_slice(&"seller_more", "One More Seller", Color(0.5, 0.9, 0.55), more,
				"next brings $%+.2f/s" % followers.next_seller_net(i)),
		_slice(&"seller_less", "One Seller Fewer", Color(0.9, 0.55, 0.45),
				"nobody works here" if working <= 0 else "", "%d of %d at work" % [working, slots]),
	]


func _why_not_decree(kind: StringName, building: Node3D) -> String:
	if decrees.is_done(kind, building):
		return "done"
	return "" if decrees.can_afford(kind, building) else "needs " + decrees.price(kind, building)


func _why_not_loan() -> String:
	if treasury.owed > 0.0:
		return "$%d still owed" % ceili(treasury.owed)
	return "" if treasury.can_borrow() else "needs %d paperwork" % roundi(F.loan_paperwork)


## A slice that is greyed out with `why` when it can't be chosen, and shows `price`
## when it can.
func _slice(id: StringName, label: String, color: Color, why: String, price: String) -> Dictionary:
	return {"id": id, "label": label, "color": color, "note": why if why != "" else price,
			"enabled": why == ""}


func _upgrade_id(kind: Kind) -> StringName:
	return StringName("upgrade_%d" % kind)
