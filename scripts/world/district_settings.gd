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
## With its core building, this share of a district's buildings makes it yours
## (60 or 75 is still open with Eilam).
@export_range(0.0, 1.0) var control_share := 0.6
## A district's core can only become yours once this share of the buildings within
## core_base_steps borders of it are yours.
@export_range(0.0, 1.0) var core_base_share := 0.5
@export var core_base_steps := 2

@export_group("Start district")
## Abandoned buildings stand empty: whoever moves in holds them.
@export_range(0.0, 1.0) var abandoned_start := 0.3      # share of the start district's buildings
@export_range(0.0, 1.0) var abandoned_elsewhere := 0.04  # scattered through the rest of the city

@export_group("The stage")
## The start screen: a title and the Secretary's briefing.
@export var start_title := "Stage 1: The Slums"
@export_multiline var start_briefing := "Minutes of the founding meeting. Present: the High Priest, a kettle.\n\nItem 1: we have a base at the edge of the Slums. Win the street one building at a time; we can only take a building next to one we already hold.\nItem 2: train a Vandalist at the base and have him mark the five landmarks of the status quo. Each mark makes the heart of the district easier to win.\nItem 3: take the core in the middle and most of the district.\n\nKeep it quiet: the neighbours complain, City Hall condemns, the police close streets."
@export var start_button := "Open the meeting"
## The cult loses once it has had lose_after_believers believers and then has none
## at all (the high priest aside) for lose_minutes.
@export var lose_after_believers := 8
@export var lose_minutes := 3.0
@export var lose_title := "The cult has dissolved"
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
