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
## How well off a district of each kind is, same order: scales rent and shop income and
## what it costs to buy people out. The Slums are poor; the Financial district is rich.
@export var wealth := PackedFloat32Array([0.4, 0.9, 1.0, 1.2, 1.0, 2.0, 1.5])
## How free each district of the stage map starts (0 grey and ruled .. 1 free), in map order. Not
## used yet: the story's "independence" will drive grey versus colour.
@export var independence := PackedFloat32Array([0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1])

@export_group("Who holds a building")
@export var tick := 0.5                     # seconds between counts
## Share of a building's residents who must believe for it to be yours.
@export_range(0.0, 1.0) var capture_share := 0.5
## A district's core building (the one nearest its middle) is harder: this share of its
## residents must believe. Once it is yours, City Hall and the police leave the district alone.
@export_range(0.0, 1.0) var core_capture_share := 0.75
## A following that holds this share of a district's buildings fills its bar alone
## (at middling welfare, with no key place).
@export_range(0.0, 1.0) var control_share := 0.6
@export_group("Winning a district: one bar, two sources")
## The following (the share of buildings that are yours over control_share) counts this
## much when your believers live badly, and this much when they live well.
@export var welfare_low := 0.85
@export var welfare_high := 1.15
## What holding the district's core adds to the bar, and each marked landmark.
@export_range(0.0, 1.0) var core_points := 0.2
@export_range(0.0, 1.0) var landmark_points := 0.08
@export var progress_tick := 1.0   # seconds between looks at the bar
@export_group("Who holds a building: the core")
## A district's core can only become yours once this share of the buildings within
## core_base_steps borders of it are yours.
@export_range(0.0, 1.0) var core_base_share := 0.5
@export var core_base_steps := 2

@export_group("Borders and blocks")
## Buildings whose walls stand this close border each other (next door, or across a street).
@export var border_gap := 12.0
## What the believers living in a block that is all yours make, times this.
@export var block_output_bonus := 1.25
## A completed block calms its district: awareness drops by this, once.
@export var block_awareness_drop := 0.1
@export var block_note := "Block complete!"
@export_group("Start district")
## Abandoned buildings stand empty: whoever moves in holds them. None at the start
## (Eilam, 2026-11-12: a wall of empty buildings only blocks the cult's way); a building
## is still abandoned when a fire or roaches empty it.
@export_range(0.0, 1.0) var abandoned_start := 0.0      # share of the start district's buildings
@export_range(0.0, 1.0) var abandoned_elsewhere := 0.0  # scattered through the rest of the city

@export_group("The stage")
## The start screen: a title and the Secretary's briefing.
@export var start_title := "Stage 1: The Slums"
@export_multiline var start_briefing := "Minutes of the founding meeting. Present: the Secretary (taking these minutes), a kettle.\n\nItem 1: City Hall has turned down our god's application to be recognised as a god. A form was missing. The Committee will appeal, street by street.\nItem 2: our office is at the edge of the Slums. We win the street one building at a time, and only next to a building we already hold. A whole block of ours (the ring on the ground) is safe and pays better.\nItem 3: the district is ours when its bar is full. A wide membership that lives well fills it; so do the core in the middle and every landmark our Field Delegate marks. Either way alone is hard; together they leave us room.\nItem 4: the Hand places people. Where it sets a member down is what that member does. A worn-out member still goes, and lets everyone know.\n\nKeep it quiet: the neighbours complain, City Hall condemns, the police close streets."
@export var start_button := "Open the meeting"
## The cult loses once it has had lose_after_believers believers and then has none
## at all (the high priest aside) for lose_minutes.
@export var lose_after_believers := 8
@export var lose_minutes := 3.0
@export var lose_title := "The Committee has dissolved"
@export var lose_line := "Minutes, final item: attendance zero. The kettle has been repossessed. Meeting closed."
@export var retry_button := "Try again"

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
