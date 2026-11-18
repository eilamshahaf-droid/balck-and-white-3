class_name LightingSettings
extends Resource
## The city's light: tone mapping, the sky's fill light and the sun, by day and by night.
## The toon shader's bands, shadow levels and tints are in data/art_style.tres.
## Open data/lighting.tres in Godot and change values in the Inspector.

@export_group("Tone")
## ACES: the depth of field's Compatibility curve (depth_of_field.gdshader) is measured for it,
## so changing the tone mapper means measuring that curve again.
@export var tonemap: Environment.ToneMapper = Environment.TONE_MAPPER_ACES
@export_range(0.3, 2.0) var exposure := 1.0

@export_group("Day")
## Sun to sky fill about 3:1 on a lit wall, so shaded sides keep their colour.
@export_range(0.0, 2.0) var sun_energy := 0.85
@export var sun_color := Color(1.0, 0.95, 0.86)
@export_range(0.0, 2.0) var ambient_energy := 0.75
@export var sky_top := Color(0.22, 0.5, 0.92)
@export var sky_horizon := Color(0.74, 0.86, 0.97)

@export_group("Night")
@export_range(0.0, 2.0) var night_sun_energy := 0.3
@export var night_sun_color := Color(0.6, 0.7, 1.0)
@export_range(0.0, 2.0) var night_ambient_energy := 0.4
@export var night_sky_top := Color(0.03, 0.04, 0.1)
@export var night_sky_horizon := Color(0.1, 0.1, 0.18)
