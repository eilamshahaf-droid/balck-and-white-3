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
@export var fade_radius := 1.4              # how wide a tube between camera and hand clears buildings
@export_range(0.0, 1.0) var fade_amount := 0.85   # how see-through a faded building gets
@export var fade_speed := 8.0
@export var fade_near_camera := 6.0         # buildings this close to the camera fade too
@export var fade_keep_radius := 6.0         # buildings this close to the centre of the view never fade

@export_group("Building menus")
@export var staff_reach := 60.0              # free believers this close can be sent to a building

@export_group("Hand")
@export var hover_height := 1.5
@export var hold_height := 5.0
@export var follow_rate := 40.0
@export var hand_scale := 1.6
@export var tap_max_time := 0.2             # a press shorter than this, without moving, is a tap
@export var drag_threshold_px := 6.0
@export var tap_impulse := 3.0
@export var pick_assist_px := 30.0          # least grab reach on screen; the whole drawn hand counts when it is bigger
@export var grab_reach := 1.0                # one dial for how forgiving grabbing is, for everything
@export_range(0.0, 1.0) var magnet_strength := 0.3   # how far the hand leans toward an assisted target
@export var knock_radius := 5.0              # a tap on a wall opens a door this close
@export var notice_radius := 15.0            # people this close turn toward a knock

@export_group("Tool wheels")
@export var wheel_hold_time := 0.5           # left button held still this long opens a wheel (signs on a building, miracles elsewhere)
@export var wheel_radius_px := 150.0
@export var wheel_dead_zone_px := 50.0       # the hand sits in this hole; releasing inside it chooses nothing

@export_group("Wind")
@export var wind_full_radius := 5.0          # full effect inside this distance, sharper when closer
@export var wind_fade_radius := 10.0         # fades out smoothly up to this distance
@export_range(0.0, 1.0) var wind_idle := 0.3 # strength of a still hand compared to a moving one
@export var wind_speed_full := 15.0          # hand speed (m/s) that gives full wind
@export var wind_force := 30.0               # push on light things such as newspapers

@export_group("Holding and throwing")
@export var spring_stiffness := 120.0
@export_range(0.0, 2.0) var spring_damping := 0.6   # 1 = no wobble, lower = more wobble
@export var throw_window := 0.1             # seconds of hand motion averaged for a throw
@export var throw_multiplier := 1.0
@export var throw_max_speed := 60.0
@export var place_max_speed := 2.0          # slower than this on release = put down, not throw
@export var place_max_mouse_speed := 150.0  # mouse slower than this (pixels/s) on release = put down
@export var show_arc := true
@export var arc_min_speed := 8.0
