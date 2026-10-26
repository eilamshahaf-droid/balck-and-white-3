class_name GovernmentSettings
extends Resource
## Every tunable number for City Hall (design doc: "הממשלה כאויב"). Open
## data/government.tres in Godot and change values in the Inspector.

@export_group("When City Hall comes")
@export_range(0.0, 1.0) var inspector_exposure := 0.1   # exposure that brings an inspector
@export var visit_cooldown := 60.0          # seconds of quiet after a visit
@export var retry_cooldown := 30.0          # seconds of quiet after a visit you stopped
@export var check_interval := 0.5           # seconds between looks for a target or a blocker
@export var news_time := 8.0                # seconds the latest news stays on screen

@export_group("Inspector")
@export var inspector_walk_blocks := 1      # corners up the avenue he starts walking from
@export var inspection_time := 5.0          # seconds he stands at the door
@export var inspection_claim_cut := 35.0    # claim points a completed inspection takes away

@export_group("Demolition")
@export var notice_time := 45.0             # seconds on the notice before the bulldozer comes
@export var bulldozer_start_blocks := 4     # corners up the avenue it starts driving from
@export var bulldozer_speed := 7.0
@export var bulldozer_mass := 12.0
@export var demolish_time := 8.0            # seconds to bring a building down
@export var give_up_time := 15.0            # blocked this long, the crew goes home
@export var guards_to_block := 3            # believers standing at the building that stop the bulldozer
@export var guard_radius := 25.0
@export var lightning_scare_radius := 18.0  # lightning this close sends the crew running
@export var scare_hop := 4.0                # upward kick from that lightning, per unit of mass
