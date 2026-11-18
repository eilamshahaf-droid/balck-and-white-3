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

@export_group("Action tags")
@export var tag_texture: Texture2D
@export var tag_size := Vector2(170, 60)
## The arc the column of tags follows, round the fingertip (pixels).
@export var tag_arc_radius := 190.0
## Pixels between one place in the column and the next.
@export var tag_spacing := 64.0
@export var tag_tilt_degrees := 8.0
## The tag pointed at grows this much.
@export var tag_grow := 1.12
## Long notes shrink down to this font size to fit the tag.
@export var tag_min_font := 9
## Each action's place in the column (0 at the top), the same on every building, so the
## hand learns where it is. Actions not listed take the first free places.
@export var tag_slots := {
	&"rooms": 0, &"floors": 1, &"shop": 2, &"train_rep": 3, &"train_fixer": 4,
	&"loan": 5, &"bury": 6,
	&"send": 0, &"fixer": 1, &"fixer_act_0": 2, &"fixer_act_1": 3, &"fixer_act_2": 4,
	&"fixer_act_3": 5,
	&"seller_more": 0, &"seller_less": 1,
	&"water": 0, &"money": 1, &"party": 2, &"frogs": 3,
}

@export_group("Cuff tag")
## Metres above the hand's origin where its cuff is.
@export var cuff_lift := 1.6
## Where the tag hangs from the cuff (pixels across and down).
@export var cuff_string := Vector2(46, 10)
## Pixels from the tag's end to its punched hole.
@export var cuff_hole_inset := 22.0

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
