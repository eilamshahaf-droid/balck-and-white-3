class_name DistrictSettings
extends Resource
## Every tunable number for districts and for buildings changing sides
## (design doc: "השתלטות על רובע"). Open data/districts.tres in Godot and
## change values in the Inspector.

@export_group("Kinds")
## The GDD's seven stages: which archetypes live in each (ResidentArchetype.lives_in).
## A stage map names a kind per district (data/maps/<stage>/stage.json).
@export var kinds: PackedStringArray = [
	"Slums", "Workers", "Students", "Gentrification", "Nightlife", "Financial", "Old civic",
]
## How well off a district of each kind is, same order: scales dues and shop income and
## what it costs to buy people out. The Slums are poor; the Financial district is rich.
@export var wealth := PackedFloat32Array([0.4, 0.9, 1.0, 1.2, 1.0, 2.0, 1.5])
## How free each district of the stage map starts (0 grey and ruled .. 1 free), in map order. Not
## used yet: the story's "independence" will drive grey versus colour.
@export var independence := PackedFloat32Array([0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1])

@export_group("Who holds a building")
@export var tick := 0.5                     # seconds between counts
## A following that holds this share of a district's buildings fills its bar alone
## (at middling welfare, with no key place).
@export_range(0.0, 1.0) var control_share := 0.6
@export_group("Winning a district: one bar, two sources")
## What holding the district's core adds to the bar, and each marked landmark.
@export_range(0.0, 1.0) var core_points := 0.25
@export var progress_tick := 1.0   # seconds between looks at the bar
@export_group("Who holds a building: the core")
## A district's core can only become yours once this share of the buildings within
## core_base_steps borders of it are yours.
@export_range(0.0, 1.0) var core_base_share := 0.5
@export var core_base_steps := 2

## A building you lose keeps this much of its meter, so there is a window to send
## another rep before it has to be won from the start.
@export_range(0.0, 1.0) var lost_meter := 0.6
@export_group("Key buildings")
## One block in this many has a key building.
@export var blocks_per_key := 4.5
## The names on their signs, in the order they are chosen (the core first).
@export var key_names := PackedStringArray(["Bureau of Forms", "Permit Office",
		"Licence Desk", "Zoning Board", "Records Annex", "Noise Bureau", "Stamp Office",
		"Queue Management", "Parking Authority", "Department of Departments"])
@export var key_board_color := Color(0.45, 0.12, 0.12)
@export var key_board_width := 14.0
@export var key_board_height := 2.6
@export var key_label_font_size := 64
@export var key_label_color := Color(1.0, 0.95, 0.85)

@export_group("Borders and blocks")
## Buildings whose walls stand this close border each other (next door, or across a street).
@export var border_gap := 12.0
@export var block_note := "Block complete!"
@export_group("The stage")
## The start screen: a title and the Secretary's briefing.
@export var start_title := "Stage 1: The Slums"
@export_multiline var start_briefing := "Minutes of the founding meeting. Present: the Secretary (taking these minutes), a kettle.\n\nItem 1: City Hall has turned down our god's application to be recognised as a god. A form was missing. The Committee will appeal, street by street.\nItem 2: our office is at the edge of the Slums. A Rep at a building's door fills the bar over it; when it is full the building is ours and the Rep stays to manage it, so every building needs a Rep of its own. Buildings next to ours in the same block come round by themselves, slowly, and then only need a Rep. Only next to a building we already hold. A whole block of ours (the ring on the ground) is safe and pays better.\nItem 3: the district is ours when its bar is full. A wide membership that lives well fills it; so do the core in the middle and every landmark our Fixer marks. Either way alone is hard; together they leave us room.\nItem 4: the Hand places people. Where it sets a member down is what that member does. A worn-out member still goes, and lets everyone know.\n\nKeep it quiet: the neighbours complain, City Hall condemns, the police close streets."
@export var start_button := "Open the meeting"
@export_group("Missions: the card that says what to do next")
@export var mission_width := 380.0
@export var mission_train := "Train a Rep"
@export var mission_train_hint := "Hold the button on the Office (gold roof) and choose Train Rep. It costs paperwork, which the clerks at the Office make. A Rep takes a building over and stays to manage it."
@export var mission_send := "Send your Rep to a building"
@export var mission_send_hint := "Hold the button on a building next to one of yours and choose Send a Rep, or lift the Rep and set them down at its door. Two Reps at one door work twice as fast."
@export var mission_take := "Take the building"
@export var mission_take_hint := "The bar over the building fills while a Rep is at its door, faster while your hand is over it. When it is full the building is yours and the Rep stays as its Manager."
## The block mission starts once this many buildings are yours.
@export var mission_block_from := 2
@export var mission_block := "Complete the Office's block: %d of %d"
@export var mission_block_hint := "Take every building in the ring round the Office. A complete block draws followers faster; green bars are buildings that already want you and only need a Rep."
@export var mission_district := "Fill the district's bar"
@export var mission_district_hint := "Every building of yours fills it. Hold the button on a building of yours and choose Rooms: fit in shops for money, and in the Office desk rooms, archives and training rooms."
@export var mission_won := "The district is yours"

@export_group("District captured")
## The screen when a district is yours; %s is the district's name.
@export var captured_title := "%s is yours!"
## One line from the Secretary's meeting minutes, by district (wraps around).
@export var captured_minutes: PackedStringArray = [
	"Minutes, item 1: the district is ours. Item 2: someone keeps eating the biscuits. Motion carried.",
]
@export var next_stage_note := "The next district opens in a later version."
@export var keep_playing_label := "Keep playing"
@export var captured_color := Color(1.0, 0.8, 0.25)

@export_group("Look")
@export var core_color := Color(0.62, 0.3, 0.85)           # beacon on each district's core building
@export var core_beacon := Vector3(1.2, 7.0, 1.2)          # its size, above the roof
@export var tooltip_interval := 0.1                        # seconds between looks under the cursor
@export var tooltip_offset := Vector2(18.0, 18.0)          # pixels from the cursor
@export var roof_color := Color(1.0, 0.7, 0.0)              # the plate on a building of yours
@export var border_color := Color(1.0, 1.0, 1.0, 0.85)
@export var controlled_border_color := Color(1.0, 0.7, 0.0, 1.0)
@export var border_width := 0.6
## The takeover bar over a building: least width, thickness and depth (metres), the
## widest it gets, how far above the roof, and its colours (filling, and full: it wants you).
@export var meter_bar := Vector3(6.0, 1.0, 2.4)
@export var meter_bar_max := 12.0
@export var meter_bar_lift := 3.0
@export var meter_back_color := Color(0.1, 0.1, 0.14)
@export var meter_fill_color := Color(1.0, 0.75, 0.15)
@export var meter_ready_color := Color(0.35, 0.9, 0.4)
@export var unit_ring_margin := 1.5             # how far a unit's ring stands out from its walls


# Accessors rather than indexing the arrays from a const preload: in the editor the
# parser folds a const resource's unsaved arrays to null and rejects the index.
## How well off a district of `kind` is.
func wealth_of_kind(kind: String) -> float:
	var d := kinds.find(kind)
	return wealth[d] if d >= 0 and d < wealth.size() else 1.0


func start_independence(count: int) -> PackedFloat32Array:
	var out := independence.duplicate()
	out.resize(count)
	return out


func minute_for(d: int) -> String:
	return captured_minutes[d % captured_minutes.size()] if not captured_minutes.is_empty() else ""


func key_name(k: int) -> String:
	return key_names[k % key_names.size()] if k >= 0 else ""
