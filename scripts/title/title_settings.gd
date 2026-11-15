class_name TitleSettings
extends Resource
## The title screen's words and look (scenes/title.tscn), and the credits it shows.

@export var subtitle := "A god against the bureaucracy"
@export var background_color := Color(0.09, 0.1, 0.13)
@export var title_color := Color(1.0, 0.85, 0.35)
@export var title_size := 72
@export var button_width := 320.0
## Where the player's settings are kept between visits (the browser keeps user:// too).
@export var settings_path := "user://settings.cfg"
## One line each; a model under CC-BY must be credited here once it ships in the game
## (the Artist keeps the list in art/kits/CREDITS.md).
@export var credits := PackedStringArray([
	"Made by Eilam, with Claude",
	"Furniture and city modules: Kenney (kenney.nl), CC0",
	"The god's glove: from the WebXR hand model, Copyright (c) 2019 Amazon, MIT licence",
	"Props: made with Meshy",
	"Engine: Godot (godotengine.org), MIT licence",
])
