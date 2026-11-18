class_name UiSettings
extends Resource
## The interface's numbers and colours (the UI brief "the god's desk"); its looks
## (paper, tape, fonts) are in data/ui_theme.tres.

@export_group("Colours")
@export var ink := Color("2b2620")
@export var muted := Color("6f665a")
@export var red := Color("b3261e")

@export_group("Desk")
## Seconds between updates of the numbers on screen.
@export var refresh := 0.25
## How much the paper dims while the game is paused (1 = not at all).
@export var pause_dim := 0.8
@export var version_alpha := 0.5
## The district card, bottom right, wraps its lines at this width.
@export var district_width := 380.0

@export_group("Tape strip")
@export var strip_position := Vector2(14, 8)
## How far under the strip's top the line about the miracle in the hand sits.
@export var held_below := 70.0
@export var icon_size := 22.0
@export var coin_texture: Texture2D
@export var pin_texture: Texture2D
@export var buildings_bar_width := 90.0

@export_group("Exposure dial")
@export var dial_size := 132.0
@export var dial_margin := 14.0
@export var dial_rim := 5.0
@export var dial_paper: Texture2D
## A wedge this see-through over the paper shows the exposure.
@export var dial_wedge_alpha := 0.8

@export_group("Minutes slip")
@export var peg_texture: Texture2D
@export var peg_size := Vector2(88, 30)
## Seconds the red pen takes to strike a done step through.
@export var strike_seconds := 0.5
## Seconds after a new step before the slip folds back to one line.
@export var collapse_seconds := 6.0
