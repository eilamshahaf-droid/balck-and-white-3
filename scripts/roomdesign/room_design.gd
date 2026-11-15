class_name RoomDesign
extends RefCounted
## The furniture of one room kind at one level, as the room designer edits it, and its
## file (format 1, shared with the Artist's browser editor): {room, level, bay_width,
## floor_height, depth, cells, items: [{model, cell: [col, row], x (metres from the
## cell's left to the item's middle), y (metres above that floor), z (metres from the
## room's middle, back negative), depth (0 back, 1 middle, 2 front), rot (quarter
## turns), scale}]}. Rooms are designed unturned; the game may turn them.


## One piece of furniture. `x` is metres from the room's left edge (so it can move
## across cells); the file stores it per cell.
class Item:
	var model: StringName
	var row := 0
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var rot := 0
	var scale := 1.0
	## Its height was set by hand (or it hangs on a wall): don't settle it on what is below.
	var manual := false

	func copy() -> Item:
		var o := Item.new()
		o.model = model
		o.row = row
		o.x = x
		o.y = y
		o.z = z
		o.rot = rot
		o.scale = scale
		o.manual = manual
		return o


var room: StringName
var level := 1
var items: Array[Item] = []


func _init(room_id: StringName = &"", room_level := 1) -> void:
	room = room_id
	level = room_level


## The store's key for this room and level.
static func key_of(room_id: StringName, room_level: int) -> String:
	return "%s_%d" % [room_id, room_level]


func key() -> String:
	return key_of(room, level)


## 0 at the back, 1 in the middle, 2 at the front.
static func depth_slot(z: float, band: float) -> int:
	return 0 if z < -band else (2 if z > band else 1)


func to_dict(kind: RoomKind, s: RoomDesignerSettings) -> Dictionary:
	var cells := []
	for c in kind.cells:
		cells.append([c.x, c.y])
	var out := []
	for o in items:
		var col := floori(o.x / s.bay_width)
		out.append({
			"model": String(o.model),
			"cell": [col, o.row],
			"x": snappedf(o.x - col * s.bay_width, 0.001),
			"y": snappedf(o.y, 0.001),
			"z": snappedf(o.z, 0.01),
			"depth": depth_slot(o.z, s.depth_band),
			"rot": o.rot,
			"scale": snappedf(o.scale, 0.01),
		})
	return {
		"format": s.format, "room": String(room), "title": kind.title,
		"category": s.category_of(room), "level": level, "bay_width": s.bay_width,
		"floor_height": s.floor_height, "depth": s.depth, "cells": cells, "items": out,
	}


## A design from a format-1 dictionary; null when it isn't one.
static func from_dict(d: Dictionary, s: RoomDesignerSettings) -> RoomDesign:
	if not d.has("room") or not d.has("items"):
		return null
	var design := RoomDesign.new(StringName(str(d["room"])), int(d.get("level", 1)))
	var bay := float(d.get("bay_width", s.bay_width))
	for raw: Variant in d["items"]:
		if not raw is Dictionary:
			continue
		var i: Dictionary = raw
		var cell: Array = i.get("cell", [0, 0])
		var o := Item.new()
		o.model = StringName(str(i.get("model", "")))
		o.row = int(cell[1])
		o.x = int(cell[0]) * bay + float(i.get("x", bay / 2.0))
		o.y = float(i.get("y", 0.0))
		# Older files only have the depth slot.
		o.z = float(i["z"]) if i.has("z") else (int(i.get("depth", 1)) - 1) * 1.7
		o.rot = int(i.get("rot", 0)) % 4
		o.scale = float(i.get("scale", 1.0))
		o.manual = o.y > 0.0
		design.items.append(o)
	return design


## Every item, as plain data, for undo.
func snapshot() -> Array[Item]:
	var out: Array[Item] = []
	for o in items:
		out.append(o.copy())
	return out
