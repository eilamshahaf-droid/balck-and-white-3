extends Node
## Drives the room designer headless: furniture is put in, stacks on a surface, turns,
## undoes, survives a save and a reload in format 1, takes grid squares without overlap, offers the
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
	_check(is_equal_approx(drawn.scale.x, d.catalog.scale_of(&"desk")),
			"furniture is drawn %.1f times its size" % d.catalog.scale_of(&"desk"))
	_check(is_equal_approx(d._preview._snap(1.13), 1.25) and is_equal_approx(d._preview._snap(-0.6), -0.5),
			"small things snap to a %.2f m grid" % d.settings.snap)
	_check_placement()
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
	if FurnitureSpots.type_of(o, d.catalog) == FurnitureCatalog.Place.Type.FLOOR:
		FurnitureSpots.settle(o, d.catalog, d.kind, d.design.items)
	d.design.items.append(o)
	d._on_edited()
	return o


## Floor pieces take whole squares and never overlap; pictures stay on the wall; a
## sidecar file wins over the lists.
func _check_placement() -> void:
	var d := _designer
	var step := d.settings.grid_step
	d._choose_kind(_index_of(&"family"))
	d._clear()
	var bed := _put(&"bedDouble", 0, 0, 1.13)
	var r := FurnitureSpots.area(bed, d.catalog)
	var on_grid := func(v: float) -> bool: return is_equal_approx(fposmod(v, step), 0.0) \
			or is_equal_approx(fposmod(v, step), step)
	_check(bed.y == 0.0 and on_grid.call(r.position.x) and on_grid.call(r.position.y + d.settings.depth / 2.0) \
			and on_grid.call(r.end.x), "a bed takes whole %.1f m squares (%s)" % [step, FurnitureSpots.squares(bed, d.catalog)])
	var side := _put(&"bedDouble", 0, 0, 1.13)
	_check(not FurnitureSpots.area(side, d.catalog).grow(-0.01).intersects(r), "a second bed put on it moves to free squares")
	_check(not FurnitureSpots.move_to(side, bed.x, bed.z, d.catalog, d.kind, d.design.items),
			"and cannot be dragged onto the first")
	var full := 0
	for i in 60:
		var o := d.catalog.new_item(&"bedDouble", 0, 2.0, 0.0, d.design.items)
		if not FurnitureSpots.settle(o, d.catalog, d.kind, d.design.items):
			break
		d.design.items.append(o)
		full += 1
	var overlaps := 0
	for a in d.design.items:
		for b in d.design.items:
			if a != b and a.row == b.row and FurnitureSpots.area(a, d.catalog).grow(-0.01).intersects(FurnitureSpots.area(b, d.catalog)):
				overlaps += 1
	_check(full < 60 and overlaps == 0, "a full floor takes no more beds (%d more fit), none overlap" % full)
	d._clear()
	var pic := d.catalog.new_item(&"picture_landscape", 0, 2.0, 0.0, d.design.items)
	FurnitureSpots.hang(pic, 1.9, d.catalog, d.kind)
	var z := pic.z
	FurnitureSpots.hang(pic, 300.0, d.catalog, d.kind)
	_check(pic.z == z and z < 0.0 and pic.x < d._preview._width(), "a picture slides along the back wall only")
	var model := &"bedDouble"
	var path := d.catalog._folder_of(model) + String(model) + ".place.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(true, "(sidecar check skipped: the model folder is read-only)")
		return
	file.store_string(JSON.stringify({"type": "wall", "scale": 1.5, "footprint": [1.0, 0.5]}))
	file.close()
	var fresh := FurnitureCatalog.new(d.settings)
	var place := fresh.place_of(model)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(place.type == FurnitureCatalog.Place.Type.WALL and is_equal_approx(place.scale, 1.5) \
			and place.footprint == Vector2(1.0, 0.5) and place.wall_height == d.settings.default_wall_height,
			"a model's .place.json wins over the lists")


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failed += 1
