class_name PlayerSettings
extends RefCounted
## The player's own settings, kept in a small file between visits: sound volume, full
## screen and the art style. Applied at start by the title screen.

const SECTION := "player"

var volume := 0.8
var fullscreen := false
var art_style := true

var _path: String


func _init(path: String) -> void:
	_path = path
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	volume = float(file.get_value(SECTION, "volume", volume))
	fullscreen = bool(file.get_value(SECTION, "fullscreen", fullscreen))
	art_style = bool(file.get_value(SECTION, "art_style", art_style))


func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "volume", volume)
	file.set_value(SECTION, "fullscreen", fullscreen)
	file.set_value(SECTION, "art_style", art_style)
	file.save(_path)


## Put the settings into effect: the master bus, the window and the art style.
func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)
	ArtStyle.set_enabled(art_style)
