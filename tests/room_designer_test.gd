extends Node
## Drives the room designer headless: furniture is put in, stacks on a surface, turns,
## undoes, survives a save and a reload in format 1, snaps to the grid, offers the
## Artist's pieces, and the 3D view builds. Prints ROOM DESIGNER TEST: PASS or FAILED; with --shot=<path> it leaves the
## view up for a screenshot instead of quitting.

const SCENE := preload("res://scenes/room_designer.tscn")

var _failed := 0
var _designer: RoomDesigner


func _ready() -> void:
	_designer = SCENE.instantiate()
	add_child(_designer)
	await get_tree().process_frame
	var d := _designer
	d.settings.store_path = "user://room_designs_test.json"
	d.store = DesignStore.new(d.settings)
	d._choose_kind(_index_of(&"desks"))
	d._clear()
	var desk := _put(&"desk", 0, 0, 2.0)
	_check(desk.y == 0.0, "a desk stands on the floor")
	var screen := _put(&"computerScreen", 0, 0, 2.0)
	_check(is_equal_approx(screen.y, d.catalog.size_of(desk).y), "a screen put on the desk rests on its top")
	var lamp := _put(&"lampWall", 0, 1, 1.0)
	_check(lamp.manual and lamp.y > 1.0 and lamp.z < 0.0, "a wall lamp hangs on the back wall")
	d.selected = desk
	d._turn()
	_check(desk.rot == 1, "R turns the picked item")
	d._undo_last()
	_check(d.design.items.size() == 3 and d.design.items[0].rot == 0, "undo puts it back")
	var file := d.design.to_dict(d.kind, d.settings)
	_check(int(file["format"]) == 1 and (file["items"] as Array).size() == 3 \
			and (file["cells"] as Array).size() == d.kind.cells.size(), "the room's file is format 1")
	var item: Dictionary = (file["items"] as Array)[2]
	_check((item["cell"] as Array)[1] == 1 and is_equal_approx(float(item["x"]), 1.0),
			"an item's place is stored per cell")
	var back := RoomDesign.from_dict(JSON.parse_string(JSON.stringify(file)), d.settings)
	_check(back.items.size() == 3 and absf(back.items[1].y - screen.y) < 0.002 \
			and back.items[2].row == 1, "and reads back the same")
	var again := DesignStore.new(d.settings).design_of(d.kind, 1)
	_check(again.items.size() == 3, "the designer keeps the room between visits")
	await get_tree().process_frame
	_check(d._preview._nodes.size() == 3, "the 3D view builds the furniture")
	var drawn := d._preview._nodes[d.design.items[0]] as Node3D
	_check(is_equal_approx(drawn.scale.x, d.settings.furniture_scale),
			"furniture is drawn %.1f times its size" % d.settings.furniture_scale)
	_check(is_equal_approx(d._preview._snap(1.13), 1.25) and is_equal_approx(d._preview._snap(-0.6), -0.5),
			"places snap to a %.2f m grid" % d.settings.snap)
	d._preview._free = true
	_check(is_equal_approx(d._preview._snap(1.13), 1.13), "Shift places freely")
	d._preview._free = false
	var missing := PackedStringArray()
	for m in d.settings.artist_models:
		if d.catalog.scene(m) == null or d.catalog.icon(m) == null:
			missing.append(m)
	_check(missing.is_empty() and d.catalog.models_in("all", "counter").size() == 5,
			"the Artist's pieces are on offer beside Kenney's %s" % missing)
	_check(d.catalog.is_surface(&"counter_register") and d.catalog.is_surface(&"display_case") \
			and d.catalog.wall_height(&"picture_landscape") > 1.0 \
			and d.catalog.wall_height(&"wall_clock") > 1.0,
			"counters and display cases take things on top; pictures and the clock hang")
	d.selected = screen
	d._sync(false)
	print("ROOM DESIGNER TEST: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	DirAccess.remove_absolute(d.settings.store_path)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			return
	get_tree().quit(1 if _failed > 0 else 0)


func _index_of(id: StringName) -> int:
	for i in _designer.kinds.size():
		if _designer.kinds[i].id == id:
			return i
	return 0


func _put(model: StringName, col: int, row: int, x: float) -> RoomDesign.Item:
	var d := _designer
	d._snapshot()
	var o := d.catalog.new_item(model, row, col * d.settings.bay_width + x, 0.0, d.design.items)
	d.design.items.append(o)
	d._on_edited()
	return o


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failed += 1
