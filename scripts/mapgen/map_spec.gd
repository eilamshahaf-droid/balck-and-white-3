class_name MapSpec
extends Resource
## What kind of map to make. A level is a MapSpec saved in data/maps/ with fixed
## numbers; the sandbox makes one with a fresh `seed` each time.

@export var map_seed := 1
@export_group("Streets")
@export var avenues := 7                         # north-south roads
@export var streets := 14                        # east-west roads
@export var avenue_gaps := Vector2(64.0, 96.0)   # min, max distance between avenues
@export var street_gaps := Vector2(22.0, 36.0)
@export_group("Blocks")
@export var plazas := 4                          # blocks left half open as squares
@export var park_length := 4                     # blocks of park along the north end, 0 for none
@export_group("Districts")
@export var columns := 3
@export var rows := 3
## An archetype id per district, west to east then south to north. Leave a
## slot empty (or the array short) and the generator picks for it.
@export var archetypes: PackedStringArray = []
## Where the cult starts, a district index; -1 picks a corner.
@export var start_district := -1
@export_group("Organic streets")
## A StreetStyle id; the style's numbers replace the ones below. Empty keeps them.
@export var street_style := &""
## Real metres to game metres, so a real block fits the toy-town city.
@export var metres_scale := 0.3
## Size of the area the organic street generator fills, centred on the origin.
@export var field_size := Vector2(480.0, 400.0)
@export var grid_fields := 3          # straight-street patches, each at its own angle
@export var radial_fields := 2        # streets that fan out from a centre
@export var field_reach := 160.0      # how far a patch dominates before the next takes over
@export var field_wobble := 0.35      # radians of noise on the street direction
@export var major_spacing := 46.0     # distance between main streets
@export var minor_spacing := 22.0     # distance between side streets
@export var trace_step := 3.0
@export var max_line_length := 700.0
@export_range(0.0, 1.0) var dead_end_share := 0.1   # side streets cut short


## A copy of this spec with a street style's numbers applied.
func styled(style: StreetStyle) -> MapSpec:
	var out := duplicate() as MapSpec
	out.grid_fields = style.grid_fields
	out.radial_fields = style.radial_fields
	out.field_reach = style.field_reach * metres_scale
	out.field_wobble = style.field_wobble
	out.minor_spacing = style.minor_spacing * metres_scale
	out.major_spacing = style.major_spacing * metres_scale
	out.dead_end_share = style.dead_end_share
	return out
