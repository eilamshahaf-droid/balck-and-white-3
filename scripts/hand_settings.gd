class_name HandSettings
extends Resource
## Every tunable number for the god's hand and camera.
## Open data/hand_settings.tres in Godot and change values in the Inspector.

@export_group("Camera")
@export var pan_key_speed := 60.0           # WASD, metres per second per 100 m of zoom
@export var rotate_key_speed := 1.5         # Q/E, radians per second
@export var tilt_key_speed := 1.0           # R/F, radians per second
@export var orbit_sensitivity := 0.005      # middle-drag, radians per pixel
@export var zoom_step := 1.15               # per wheel notch
@export var zoom_drag_sensitivity := 0.01   # both buttons + mouse, per pixel
@export var distance_min := 8.0
@export var distance_max := 450.0
@export_range(5, 89) var pitch_min_deg := 15.0   # degrees below the horizon
@export_range(5, 89) var pitch_max_deg := 80.0
@export var min_clearance := 3.0            # metres above whatever is below the camera
@export var smoothing := 10.0               # how fast the camera catches up with its target
@export var fly_duration := 1.5
@export var fly_distance_ground := 70.0
@export var fly_distance_object := 20.0
@export var bounds_margin := 60.0           # how far past the city edge the camera may go

@export_group("Hand")
@export var hover_height := 1.5
@export var hold_height := 5.0
@export var follow_rate := 25.0
@export var hand_scale := 1.6
@export var tap_max_time := 0.2             # a press shorter than this, without moving, is a tap
@export var drag_threshold_px := 6.0
@export var tap_impulse := 3.0

@export_group("Holding and throwing")
@export var spring_stiffness := 120.0
@export_range(0.0, 2.0) var spring_damping := 0.6   # 1 = no wobble, lower = more wobble
@export var throw_window := 0.1             # seconds of hand motion averaged for a throw
@export var throw_multiplier := 1.0
@export var throw_max_speed := 60.0
@export var place_max_speed := 2.0          # slower than this on release = put down, not throw
@export var show_arc := true
@export var arc_min_speed := 8.0
