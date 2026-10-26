class_name ArtStyleSettings
extends Resource
## Every tunable number of the art style: soft cel shading, sun, tilt-shift and depth of field.
## Open data/art_style.tres in Godot and change values in the Inspector.
## Press V in the game to compare with the plain look.

@export var enabled := true

@export_group("Light bands")
@export_range(0.0, 1.0) var band_low := 0.46     # how much colour the dark side keeps
@export_range(0.0, 1.0) var band_mid := 0.56
@export_range(0.0, 1.5) var band_high := 0.64
@export_range(0.0, 1.0) var step1 := 0.45       # where dark turns to mid (0 = facing away, 1 = facing the sun)
@export_range(0.0, 1.0) var step2 := 0.65       # where mid turns to light
@export_range(0.0, 0.3) var softness := 0.06    # how blurred the band edges are
@export var shadow_tint := Color(0.84, 0.8, 0.94)   # darker bands lean this way (cool sky blue)
@export_range(0.0, 1.0) var ambient_amount := 0.3  # how much sky light fills the shadows

@export_group("Sun and shadows")
@export var sun_override := true              # the art style sets the sun's angle and shadow quality
@export_range(-89.0, -10.0) var sun_pitch := -42.0   # degrees; lower sun = longer shadows
@export_range(-180.0, 180.0) var sun_yaw := 35.0
@export_range(0.0, 1.0) var shadow_level := 0.3     # how much colour stays in a cast shadow
@export_range(0.0, 0.5) var shadow_softness := 0.06 # 0 = razor-sharp shadow edges
@export var shadow_distance := 260.0                # metres from the camera that get shadows
@export var key_tint := Color(1.0, 0.93, 0.8)      # lit faces lean this way (warm sun)
@export_range(0.0, 1.0) var rim_strength := 0.22    # toy-like bright edge on sunlit sides

@export_group("Tilt-shift")
@export_range(0.0, 16.0) var tilt_blur := 10.0       # blur in pixels at the top and bottom edges (0 = off)
@export_range(0.0, 1.0) var tilt_center := 0.55      # where the sharp band sits (0 = top, 1 = bottom)
@export_range(0.0, 1.0) var tilt_width := 0.22       # height of the sharp band
@export var tilt_height_min := 8.0                   # camera height (m) where the effect starts
@export var tilt_height_max := 60.0                  # camera height (m) where it is full

@export_group("Depth of field")
@export_range(0.0, 16.0) var dof_blur := 8.0         # blur in pixels far behind the focus (0 = off)
@export_range(1.0, 3.0) var dof_start := 1.15        # blur starts at this many times the focus distance
@export_range(1.0, 6.0) var dof_end := 2.2           # and is full at this many times
## The focus is whatever stands under the tilt-shift's sharp band (tilt_center).

@export_group("Colour grade")
@export_range(0.5, 2.0) var saturation := 1.15        # toy colours, a little brighter than life
@export_range(0.0, 1.0) var vibrance := 0.1           # boosts dull colours more than vivid ones
@export_range(0.5, 1.5) var contrast := 1.04
@export var wash_color := Color(1.0, 0.93, 0.82)     # a soft wash over the whole picture, like The Sims
@export_range(0.0, 0.5) var wash := 0.1

@export_group("Tone")
@export var tonemap_filmic := false        # leave off to keep the city's own tone mapping
@export var exposure := 1.0
