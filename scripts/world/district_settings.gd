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
## The share of a district's people that must follow you for the freedom way to win
## (with key_part_share of its key buildings).
@export_range(0.0, 1.0) var control_share := 0.6
@export_group("Winning a district: two ways")
## Control: this share of the district's key buildings wins it alone.
@export_range(0.0, 1.0) var key_win_share := 0.8
## Freedom: this share of the key buildings, together with control_share of the people.
@export_range(0.0, 1.0) var key_part_share := 0.3
@export var progress_tick := 1.0   # seconds between looks at the bar
@export_group("Who holds a building: the core")
## A district's core can only become yours once this share of the buildings within
## core_base_steps borders of it are yours.
@export_range(0.0, 1.0) var core_base_share := 0.5
@export var core_base_steps := 2

## A building you lose keeps this much of its meter, so there is a window to send
## another rep before it has to be won from the start.
@export_range(0.0, 1.0) var lost_meter := 0.6
@export_group("Impression: the gate on ordinary buildings")
## A building is impressed by every building of yours within the influence radius: this
## much each, plus the RoomKind.impression of its open rooms (homes, shops, the Laundry
## Room).
@export var impression_per_building := 1.0
## The next ordinary building needs impression_start, and impression_step more for every
## ordinary building you hold past impression_free.
@export var impression_start := 3.0
@export var impression_step := 0.3
@export var impression_free := 2
## What to do when it is short.
@export var impression_remedy := "fit homes (+1), shops (+2) or a Laundry Room (+5) in your buildings near it"

@export_group("Key buildings")
## One block in this many has a key building (1: every block but the Office's own).
@export var blocks_per_key := 1.0
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
## The opening scene on the first run: one panel per line, each with who speaks and
## what is seen (an empty direction shows nothing). Read through the accessors below.
@export var opening_speakers := PackedStringArray([
	"Narrator",
	"The Secretary, shouting from inside City Hall",
	"The Secretary, at home",
	"The Secretary, reading",
	"Narrator",
])
@export var opening_directions := PackedStringArray([
	"The camera drops through the clouds onto City Hall.",
	"",
	"He opens the closet. Inside is an altar in the shape of a hand.",
	"Light streams from the altar. There is a letter in the statue's hand.",
	"",
])
@export_multiline var opening_lines := PackedStringArray([
	"In the whole universe there is one thing that even God has no answer to...",
	"I asked for holiday days half a year ago! I won't work like this. I quit!",
	"God, I need a holiday. Destroy City Hall so I can finally go on mine.",
	"After considering your request, the necessary forms are missing. To produce them you will have to do as I say before we can approve the request.",
	"Bureaucracy. Even God cannot defeat it.",
])
@export var opening_next := "Next"
@export var opening_skip := "Skip"
@export var opening_done := "Take the first building"
## The world behind the opening is dimmed to this.
@export var opening_dim := Color(0.02, 0.03, 0.06, 0.88)
@export var opening_panel_color := Color(0.09, 0.1, 0.15, 0.97)
@export var opening_direction_color := Color(0.7, 0.72, 0.8)
@export_group("Missions: the card that says what to do next")
@export var mission_width := 380.0
@export var mission_train := "Train a Rep"
@export var mission_train_hint := "Hold the button on the Office (gold roof) and choose Train Rep. It costs paperwork, which the clerks at the Office make. A Rep takes a building over and stays to manage it."
@export var mission_send := "Send your Rep to a building"
@export var mission_send_hint := "Hold the button on a building near yours and choose Send a Rep (the card under the hand says if it is impressed enough). (Faster: lift the Rep and set them down at its door.) Two Reps at one door work twice as fast."
@export var mission_take := "Take the building"
@export var mission_take_hint := "The bar over the building fills while a Rep is at its door, faster while your hand is over it. When it is full the building is yours and the Rep stays as its Manager."
@export var mission_first := "Send your Rep"
@export var mission_first_hint := "Your first Rep waits by the Office. Hold the button on a building next to the Office and choose Send a Rep. (Faster: lift the Rep and set them down at its door.)"
@export var mission_first_take := "Take the first building"
@export var mission_first_take_hint := "The bar over the building fills while your Rep is at its door, twice as fast with your hand over it. When it is full the building is yours and the Rep stays as its Manager."
@export var mission_shop := "Plan the Office: a Shop"
@export var mission_shop_hint := "The Office (gold roof) is empty. Double click it and fit a Shop on the ground floor: its sellers bring in money. Esc closes the plan."
@export var mission_desks := "Plan the Office: a Desk Room"
@export var mission_desks_hint := "Fit a Desk Room in the Office: its clerks make paperwork. Every Rep costs a little paperwork each second, so desks are what keep your Reps at work."
## Homes the Office needs before the card moves on.
@export var mission_homes_count := 2
@export var mission_homes := "Plan the Office: %d homes"
@export var mission_homes_hint := "People work where they live: fit two Family Flats in the Office so there is someone to sit at the desks and serve in the Shop. Homes also impress the buildings nearby."
@export var mission_training := "Save up for a Training Room"
@export var mission_training_hint := "Fit a Training Room in the Office: one more Rep at a time. The bar shows your money against its price."
@export var mission_inspector := "An inspector!"
@export var mission_inspector_hint := "A clerk from City Hall walks from a key building (red sign) to one of yours and takes the paperwork he asks for; short of it, he takes what there is and comes back. Lift him and throw him far away: it buys time."
## Reps first: the Fixer's missions start once this many buildings are yours.
@export var mission_fixer_from := 3
@export var mission_fixer := "Train the Fixer"
@export var mission_fixer_hint := "Key buildings (red signs) send the inspectors and are locked to Reps. Only the Fixer opens them: hold the button on the Office and choose Train Fixer."
@export var mission_open := "Open a key building"
@export var mission_open_hint := "Set the Fixer down at a red-signed building, then hold the button on it for his actions. Quiet ones are cheap; a loud one fills more and sends an inspector. From 70% exposure he lies low."
## %d of %d: the key buildings of the district that are yours, and all of them.
@export var mission_keys := "Key buildings: %d of %d"
@export var mission_district_hint := "Two ways to win, shown bottom left: most of the key buildings, or a few of them and most of the people. Open key buildings with the Fixer, then take them with a Rep."
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


func opening_count() -> int:
	return opening_lines.size()


func opening_speaker(i: int) -> String:
	return opening_speakers[i] if i < opening_speakers.size() else ""


func opening_direction(i: int) -> String:
	return opening_directions[i] if i < opening_directions.size() else ""


func opening_line(i: int) -> String:
	return opening_lines[i]
