class_name ArtStyleSettings
extends Resource
## Every tunable number of the art style: soft cel shading + watercolour paper.
## Open data/art_style.tres in Godot and change values in the Inspector.
## Press V in the game to compare with the plain look.

@export var enabled := true

@export_group("Light bands")
@export_range(0.0, 1.0) var band_low := 0.36     # how much colour the dark side keeps
@export_range(0.0, 1.0) var band_mid := 0.56
@export_range(0.0, 1.5) var band_high := 0.68
@export_range(0.0, 1.0) var step1 := 0.45       # where dark turns to mid (0 = facing away, 1 = facing the sun)
@export_range(0.0, 1.0) var step2 := 0.65       # where mid turns to light
@export_range(0.0, 0.3) var softness := 0.06    # how blurred the band edges are
@export var shadow_tint := Color(0.66, 0.6, 0.82)   # darker bands lean this way (lavender)
@export_range(0.0, 1.0) var ambient_amount := 0.45  # how much sky light fills the shadows

@export_group("Pigment")
@export var paper_color := Color(0.957, 0.933, 0.886)
@export_range(0.5, 2.0) var saturation := 1.15                 # watercolour pigments are vivid
@export_range(0.0, 0.5) var pigment_lift := 0.05    # mixes every colour a little toward the paper
@export var wash_scale := 0.08                      # size of the uneven wash blotches (smaller = bigger blotches)
@export_range(0.0, 1.0) var wash_strength := 0.18

@export_group("Paper pass")
@export_range(0.0, 1.0) var bleed := 0.15            # colours soften into each other
@export_range(0.0, 1.0) var edge_strength := 0.3   # pigment pooling where colours meet
@export_range(0.01, 0.5) var edge_threshold := 0.12
@export_range(0.0, 0.5) var grain := 0.025
@export_range(0.0, 0.3) var paper_strength := 0.025
@export_range(0.0, 0.01) var wobble := 0.0012       # hand-painted wobble of every line
@export_range(0.0, 0.2) var vignette := 0.03        # screen borders melting into paper

@export_group("Tilt-shift")
@export_range(0.0, 12.0) var tilt_blur := 4.0        # blur in pixels at the top and bottom edges (0 = off)
@export_range(0.0, 1.0) var tilt_center := 0.55      # where the sharp band sits (0 = top, 1 = bottom)
@export_range(0.0, 1.0) var tilt_width := 0.3        # height of the sharp band
@export var tilt_height_min := 15.0                  # camera height (m) where the effect starts
@export var tilt_height_max := 100.0                 # camera height (m) where it is full

@export_group("Tone")
@export var tonemap_filmic := false        # leave off to keep the city's own tone mapping
@export var exposure := 1.0
