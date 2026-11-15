class_name DesignStore
extends RefCounted
## Keeps every room design between visits (user://, which the browser keeps too), starts
## from the room files that ship with the game, and hands files out: a download in the
## browser, a file in the user folder on a PC. Reads a file back the same two ways.

## A file the player picked was read: `designs` are the rooms in it.
signal file_loaded(designs: Array[RoomDesign])

var settings: RoomDesignerSettings
var _all := {}   # key -> format-1 dictionary
var _picker_callback: JavaScriptObject


func _init(s: RoomDesignerSettings) -> void:
	settings = s
	var parsed: Variant = _read_json(s.store_path)
	if parsed is Dictionary:
		_all = parsed


## The design of `kind` at `level`: as last kept, else as shipped, else empty.
func design_of(kind: RoomKind, level: int) -> RoomDesign:
	var key := RoomDesign.key_of(kind.id, level)
	var d: Variant = _all.get(key)
	if d == null:
		d = _read_json(settings.shipped_folder + file_name(kind.id, level))
	var design: RoomDesign = RoomDesign.from_dict(d, settings) if d is Dictionary else null
	return design if design else RoomDesign.new(kind.id, level)


func keep(design: RoomDesign, kind: RoomKind) -> void:
	_all[design.key()] = design.to_dict(kind, settings)
	var f := FileAccess.open(settings.store_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_all))


## Every kept design, as one file's rooms.
func all_rooms() -> Array:
	return _all.values()


static func file_name(id: StringName, level: int) -> String:
	return "room_%s_L%d.json" % [id, level]


## Give the player `data` as a file called `name`: a download in the browser; on a PC a
## file in the user folder, whose path comes back ("" in the browser).
func hand_out(name: String, data: Dictionary) -> String:
	var text := JSON.stringify(data, " ")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), name, "application/json")
		return ""
	var folder := "user://room_files"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	return ProjectSettings.globalize_path(path)


## In the browser: open the page's file picker; file_loaded follows.
func pick_in_browser() -> void:
	if not OS.has_feature("web"):
		return
	_picker_callback = JavaScriptBridge.create_callback(_on_browser_file)
	var window := JavaScriptBridge.get_interface("window")
	window.godotRoomFile = _picker_callback
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json';
			input.onchange = function () {
				var f = input.files[0];
				if (!f) return;
				f.text().then(function (t) { window.godotRoomFile(t); });
			};
			input.click();
		})();
	""", true)


## Read a room file (one room, or {rooms: [...]}) at `path` on this machine.
func read_file(path: String) -> void:
	_take(FileAccess.get_file_as_string(path))


func _on_browser_file(args: Array) -> void:
	_take(str(args[0]) if not args.is_empty() else "")


func _take(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	var list: Array = []
	if parsed is Dictionary:
		var d: Dictionary = parsed
		list = d["rooms"] if d.get("rooms") is Array else [d]
	var designs: Array[RoomDesign] = []
	for raw: Variant in list:
		var design: RoomDesign = RoomDesign.from_dict(raw, settings) if raw is Dictionary else null
		if design:
			_all[design.key()] = raw
			designs.append(design)
	if not designs.is_empty():
		var f := FileAccess.open(settings.store_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(_all))
	file_loaded.emit(designs)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
