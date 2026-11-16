class_name SoundSettings
extends Resource
## Which recorded sound each event plays, and how loud. An event with no files here is
## made in code by Sfx (the old placeholders), so a missing sound is never silence.

## The folder the file names below are in.
@export var folder := "res://assets/audio/kenney/"
## Event -> file names; one is picked at random each time.
@export var files := {}
## Event -> volume in dB (0 when missing).
@export var volumes := {}
## How far the pitch of a sound may wander each time, both ways (0.08: 8%).
@export var pitch_spread := 0.08
## Sounds in the world: how far they carry.
@export var unit_size := 25.0
@export var max_distance := 400.0

@export_group("The city in the background")
@export var ambience_db := -24.0
## The street swells and falls back over this many seconds, by this many dB.
@export var swell_seconds := 9.0
@export var swell_db := 5.0
## How deep the rumble is: 0 hiss, near 1 a low roar.
@export_range(0.0, 0.999) var ambience_smoothing := 0.985

@export_group("When money and paperwork make a sound")
## Money that goes or comes at once by at least this much clinks (a purchase, a gift),
## so the takings and the upkeep, a little each tick, stay quiet.
@export var coins_min := 5.0
