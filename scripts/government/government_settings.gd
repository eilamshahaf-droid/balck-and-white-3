class_name GovernmentSettings
extends Resource
## Every tunable number for City Hall (design doc: "הממשלה כאויב"). Open
## data/government.tres in Godot and change values in the Inspector.

@export_group("When City Hall comes")
@export var visit_cooldown := 60.0          # seconds of quiet after a visit
@export var retry_cooldown := 30.0          # seconds of quiet after a visit you stopped
@export var check_interval := 0.5           # seconds between looks for a target or a blocker
@export var news_time := 8.0                # seconds the latest news stays on screen

@export_group("Building code (hidden from the player)")
## City Hall comes when you squeeze too much out of your buildings: every floor
## level past the code, luxury on top of extra floors, and a Combat Training
## use are violations. Suspicion grows with them and fades without them; at
## suspicion_visit an inspector goes to the worst offender.
@export var code_floor_levels := 2          # floor decrees the code allows
@export var level_violation := 1.0          # per floor decree past the code
@export var luxury_violation := 0.5         # luxury on a building with floors past the code
@export var training_violation := 0.5       # an unlicensed fight club
@export var suspicion_rate := 0.4           # suspicion per second per violation
@export var suspicion_decay := 0.5          # suspicion lost per second
@export var suspicion_visit := 40.0

@export_group("Inspector")
@export var inspector_walk_blocks := 1      # corners up the avenue he starts walking from
@export var inspection_time := 5.0          # seconds he stands at the door

@export_group("Demolition")
@export var notice_time := 45.0             # seconds on the notice before the bulldozer comes
@export var bulldozer_start_blocks := 4     # corners up the avenue it starts driving from
@export var bulldozer_speed := 7.0
@export var bulldozer_mass := 12.0
@export var demolish_time := 8.0            # seconds to bring a building down
@export var give_up_time := 15.0            # blocked this long, the crew goes home
@export var guards_to_block := 3            # believers standing at the building that stop the bulldozer
@export var guard_radius := 25.0
