# Art bible

The one living document for the look of the game. Owner: the Artist thread. Art Director: Eilam.
Older research (dollhouse-style, visual-style, hand-moodboard) is folded in here; the originals
stay in the project's shared folder under `research/` and `style-refs/`.

## Decisions by Eilam, 2026-11-12 (read first)

- **The story is a god against the bureaucracy** (GDD section 0). "Grey to colour: freedom" below is therefore the main visual idea, not a side proposal: the status quo is grey, what the god frees gets colour. Whether gold stays the god's colour is open again.
- **Buildings are taken one at a time; a whole block pays a bonus.** The game shows it with a gold plate on each roof of yours and a ring on the ground round each block that warms toward gold. Both are placeholders that break the rule below ("props, not tints"); the Artist owes the real look of "this building is with us" and "this block is complete".
- **Not a street-artist god** (Eilam, later the same day). The god stands for resistance to bureaucracy in two ways, control and freedom (GDD section 0). What "grey to colour" and the murals become is open until the Designer folds this in; do not build on street art as the god's identity.
- **Feature freeze**: only the Slums, until its base is good.

### What the Programmer's screenshots of 0.10.0 show (for the Artist)

1. **The Slums do not look like the Slums.** The table below asks for faded browns, mustard, peeling teal and dim warm light; the game shows clean lilac-blue and peach boxes. This is the biggest gap.
2. **The blur is too strong** at ordinary zoom: only a narrow band in the middle is sharp (`data/art_style.tres`: `dof_blur`, `tilt_blur`, `tilt_width`).
3. **Scale.** The houses outside the map are about three times the size of the city's buildings, so the city reads as a small model in a field of giants. The map's edge is a hard dark square.
4. **Text.** White help text over a bright sky is unreadable; landmark signs are huge from above.
5. **Missing from this document:** any direction for the UI (HUD, wheels, icons, font), for the miracles' effects, for sound, and for people beyond coloured capsules (a comedy needs people you can read).
6. **Where the effort goes.** Most of this document is facade realism (cornices, window pairs, the Cratial kit) that the god camera with its blur will not show. The problems above are all at the coarse level: palette, silhouette, scale, who holds what. The Cratial licence for shipping is still unchecked.

## The look

Realistic objects, stylized like a toy or dollhouse miniature, seen from above like a diorama.

- Saturated, warm colours; **no outlines**. Cel shading in 3 soft bands, cool shadow tint, warm sun,
  a toy-like rim light on sunlit edges (`data/art_style.tres`).
- Tilt-shift and depth of field when the camera is high; a soft warm wash over the picture.
- Materials are matte. No glossy realism, no PBR shine.
- Proportions are slightly chunky and exaggerated (big doors, fat roofs), details are readable
  from the god camera, not from a street-level eye.
- Humour lives in the props: laundry, boarded windows, flags, signs, tiny absurd details.
- The god's hand is a **white cloth glove** (`assets/models/god_hand`).
- Tone: a comedy. The story is being reshaped (cult versus a god against bureaucracy); until it
  settles, cult branding such as gold rings and robes is provisional.

## Palette

| Role | Colour | Notes |
| --- | --- | --- |
| Cult / believers | gold `#FFC726` | belief, owned buildings, plates |
| Priests | white | drawn larger |
| Core building beacon | violet `#9E4DD9` | |
| Sky / shadows | cool blue-lilac | shadow tint `#D6CCF0` |
| Sun | warm cream `#FFEDCC` | |

Keep gold reserved for the cult. Rivals and the state use their own hues (police: blue,
City Hall: stone grey and civic green; the rival cult: a colour not used by a district).

## Camera and readability

- High three-quarter view, buildings fade when they block the view.
- A building must read at 3 distances: silhouette (roof shape and colour), mid (facade and use
  prop), close (windows, doors, people).
- Who holds a building is shown by props on it, not tints: banner and roof flag (yours),
  boards and rubble (abandoned), flower boxes (luxury), laundry (poor).
- People are small coloured capsules in the crowd MultiMesh. Group colour is the
  readable layer; clothing detail is never needed.

## The 7 districts (one per stage, in order)

Each district gets one dominant colour, one building type and one signature prop family, so a
screenshot tells you where you are.

| # | District | Feels like | Colour / light | Buildings | Signature props |
| --- | --- | --- | --- | --- | --- |
| 1 | Slums | crowded, patched, warm and shabby | faded browns, mustard, peeling teal; dim warm light | low brick walk-ups, many abandoned | laundry lines, boarded windows, dumpsters, fire escapes, trash bags, water tanks |
| 2 | Workers | honest, grey, loud | steel blue, rust orange, smoke grey | factories, tenements, loading docks | loading docks, cooling units, hot dog carts, security gates |
| 3 | Students (university) | young, messy, bright | primary pastels, banners | dorms, a lecture hall, cheap cafes | easels, bike racks, cafe tables, posters, podium |
| 4 | Gentrification | half old, half new, smug | clean white and sage against old brick | converted lofts, glass condos | flower boxes, topiary planters, real estate signs, scaffolding |
| 5 | Tourism and nightlife | loud, lit, shiny | neon pink, cyan, gold; night-leaning light | hotels, bars, theatres | awnings, neon signs, taxis, revolving doors |
| 6 | Financial | cold, tall, tidy | glass blue, steel, one gold accent | towers, banks | bank entrances, security cameras, plazas |
| 7 | Old civic quarter | proud, stone, pompous | warm limestone, green copper roofs | City Hall, courts, monuments | bell tower, statues, flags, portico |

The game has only the Slums for now (a Map Lab map, `data/maps/slums/`); the other six wait
for the freeze to end.

## Residents (8 archetypes)

Markers first, models later. One colour per archetype, readable in the crowd, plus a small
head/hat or prop shape when close.

| Archetype | Colour | Close-up cue |
| --- | --- | --- |
| Homeless | muted brown | shopping cart / blanket |
| Blue collar | denim blue | hard hat |
| Student | bright teal | backpack |
| Pensioner | lilac grey | cane |
| Clubber | hot pink | party hat |
| Pink collar | coral | name badge / apron |
| White collar | pale grey-white | tie, briefcase |
| Bohemian | olive green | beret / scarf |

Believers get a gold ring or tint over the archetype colour. Exact values
go in `data/people.tres` once the designer confirms the table.

## Grey to colour: freedom (proposed, not built)

Direction from Eilam: colour follows independence. A district has a freedom value 0..1; at 0
everything is grey and uniform, at 1 it is full street-art colour. Concept picture:
`art/concept-sheet-2-grey-to-colour.png` in the project's shared folder.

Shader plan, so no gameplay code needs to know about colour:

- One global shader uniform: a small `freedom_map` texture (for example 64 x 64, one channel,
  blurred so district edges fade over a few metres) plus the city bounds. The game rewrites it
  when a district's value changes (rarely).
- `toon_common.gdshaderinc` samples it by world x/z and scales the existing `saturation`
  towards grey by the value. Ground, buildings, props and people all follow with no
  per-object parameters, so MultiMesh and merged building meshes stay as they are.
- Grey is not flat: keep a slight warm-cool tint so a grey district still looks like a toy.
- Needs a quick check that a global sampler uniform works on the Compatibility renderer.
- The colour grade in `screen_pass` is left alone, so camera effects stay the same everywhere.

Walls: a mural is a decal quad on a wall (white ground, bold bright shapes) that ignores the
grey-out so it always pops; a covered wall is a flat beige slab in the same place; a camera and
a fine notice are small props. The district systems place them.

## Facade styles (catalog, first four: New York)

Source: Eilam's reference photos (Wikimedia Commons, CC BY-SA: reference only, never in the game),
cards drafted by the researcher thread and checked here against the Cratial kit. The Designer turns
this into procedural rules. Later styles: federal, cast-iron, beaux-arts, art-deco, taxpayer,
modern-glass, plus Chicago, Philadelphia and Los Angeles.

**What they share (the main finding):** a building does not read as a "cube with windows" because of
three things. (1) Base, middle and top are different: a ground floor that is not the same as the
floors above, and a top that ends with a cornice or a crown. (2) A strict window rhythm that is
broken on purpose in one place (a bay window, a stoop, a shopfront, an entrance). (3) One main
material with edge details (lintels, cornice, corner) in a second colour. Rows repeat one silhouette
and vary the details (colour, hoods, bays). Street furniture on the facade (fire escapes, awnings,
air conditioners, signs) does as much for the look as the wall itself.

| | Brownstone | Tenement | Prewar apartment | Projects |
| --- | --- | --- | --- | --- |
| Floors | 3-4 + raised basement | 5-6 | 9-16 | 6-8 slabs, 13-25 towers |
| Width | 2 bays (about 8 m), in rows | 2-3 bays per lot, corners wider | 4-5 bays, corner buildings | free slab, cross or Y plan |
| Base / middle / top | stoop to parlor floor / identical floors / heavy bracketed cornice | shopfront / identical floors / sheet-metal cornice | rusticated stone base with canopy / brick middle / decorated top floors | none, plain on purpose |
| Material, colour | brown sandstone, some brick | red-orange brick, strong shopfront colours | beige brick, light stone base and top | red-brown brick only |
| Window rhythm | tall, aligned, parlor floor tallest, bay window | dense even grid, light sills and lintels | even grid, pairs, small balconies | small, even, no frames |
| Signature | stoop, iron railing, bay | fire escapes, shop awnings, AC units | canopy, belt courses, corner tower | repeated buildings on lawns |
| Roof | flat, hidden | flat, parapet, water tank | flat, penthouse, water tank | flat, mechanical box |
| Fit | middle to upper, quiet | poor to mixed, dense (Slums) | rich, by parks and river | poor, city edge |

**Buildable from the Cratial kit (4 m bay, 3 m floor):**

- Have: flat, rectangular-window and arched-window walls, corners, bay-window walls (outcrops
  left, right, centre), main and service doors, trim strips, roof edges, fire-escape platform
  and stairway, brick colours (dark, red, tan), trim colours (white, brown, green).
- Missing, to model as small extra modules (cheap, a few hundred faces each): stoop with railing,
  bracketed cornice, shopfront with awning, entrance canopy, balustrade, rusticated stone base
  (can be a texture swap on the ground-floor wall), air conditioner (already Meshy).
- To test: the kit has one window per 4 m bay, but a real tenement has about two. Check whether
  the wider wall and window variants carry two, otherwise halve the bay with a narrow module.
- Order of value for the Slums: tenement first (fire escapes, shopfront, brick), then projects
  (easiest: one tower or slab, rotated), then brownstone, then prewar for the rich districts.

Projects are laid out at block level (free-standing in a superblock with lawns and paths), unlike
the other three, which sit on the street line in rows; that is a layout rule, not a building rule.

## Facade rules (from the reference photos, tested in the Facade Lab)
Windows follow rules, not dice. Lab: https://claude.ai/artifact/Vn8t5saorTDnzZgoErVpwM (source `/mnt/project-files/art/tools/facade-lab.html`).
- **One dominant window per building** (tenement: plain or tall; brownstone: tall, taller on the parlor floor; prewar: plain or square). The top floor may switch to arched.
- **Column groups = apartments.** Tenement windows come in pairs. Air conditioners and curtains belong to a column group and repeat up its floors, never per single window.
- **Renovation by column.** One or two whole columns get a large modern window with a dark frame and no sill.
- **Wildness (0-1), one meter per scene.** Raises renovated columns, boarded windows, graffiti on shop shutters and grime streaks; also widens the per-building floor-height scale (up to 12%), so neighbours' floor lines do not line up.
- **Seen in 3D (Google Earth, 12 shots, reference only, on Eilam's PC under `claude\refs\3d`):** tenement: jagged roofline with water tanks, bare brick side walls with an air-shaft notch, a shop on almost every ground floor. Brownstone: front depth from stoop and yard, rear extensions with gardens. Prewar: E, H and U plans around courtyards, setbacks, busy rooftops. Projects: cross and Y towers turned off the street grid, no street wall, no shops.
- **In the lab so far:** shop awnings, air-shaft strip on tenement side walls, roof clutter when wildness is high.
- **Massing varies with the seed:** floors, width, depth (14-18 m), colour, a front courtyard notch (cut into a U), a lower rear extension, roof bulkheads, shop awnings. Projects pick a slab, a cross or a Y plan, turned a little off the street grid.
- **Cornice rule.** A cornice may only sit on an *anchor*: the exposed top edge of a street-facing wall, with sky or a setback above it. It is never on a side or back wall. When the top floor steps back, the cornice drops to the full wall below and the recessed floor gets only a thin band or parapet, so it never floats. The "cornice kept" meter (0-1) decides per building and per anchor: intact, partly lost (a shorter run), or stripped to a parapet or nothing. The profile (bracketed, band, heavy, parapet) is picked per building from a list per style. Projects get no cornice. Still to add: one run across neighbours of the same height, and a base band on prewar buildings.
- **Still to add:** continuous sill bands (brownstone, prewar), a fixed fire-escape column, roofs that differ between neighbours, side walls and courtyards, signs.

## Assets in use (and rules)

- Kenney modular buildings (CC0) for facades, merged per building by `building_visual.gd`.
- Meshy props in `assets/models/meshy/`, 512 px JPEG textures, matte, scaled in metres, base at
  y = 0. AI-generated: keep the list for Steam's AI disclosure.
- Cratial Stylized Modular Apartment Kit (bought 2026-11-01) is the next building set, see
  the pipeline below.
- Everything shown with MultiMesh or a shared mesh and material; no per-instance materials.

### Slums: first asset list, in priority order

1. Abandoned and patched low-rise facades (use Kenney now, Cratial later), with boarded windows. *Have it.*
2. Laundry line, fire escape, dumpster, trash bags, water tank. *Have them.*
3. Peeling-paint colour variants of the facades (palette work only, no new models).
4. Graffiti/poster decals on ground floors (new, cheap).
5. Homeless archetype props: shopping cart, blanket, barrel fire (new).
6. Cult headquarters: the multi-purpose core building with a hand statue and banner. *Mostly have it.*
7. Street clutter: puddles, cracked sidewalk decals, stray cats (new).

## How we work

- **Quick experiment, then a picture.** Eilam decides by looking. For any art question the Artist
  makes the cheapest test that answers it (one building, one street, one render), sends the picture
  with a clear recommendation, and does not write long reports. Token cost is part of the brief.
- **Honest objection first.** If a direction is weak, too costly or hurts the look, say so plainly
  and offer an alternative. Eilam decides.
- Concept sheets and comparison renders go in the project's shared folder under `art/`.

## Decisions

- 2026-11-11: **Building look = simplified Cratial modules** (decimated by about half, clean UV per
  module, one 1024 px atlas, one merged mesh per building). Tested against Kenney as it is, and
  Kenney's shapes with Cratial brick (`art/compare-*.png`): the brick-only hybrid loses the trim
  and window frames that make the miniature read, so it is dropped. Kenney stays only where a
  district has no Cratial modules yet. Licence for shipping the models still to be checked.

## Cratial kit pipeline

Source (Eilam's Google Drive folder, link-shared, not committed to the repo because of size):
https://drive.google.com/drive/folders/1NP4JkBa8uaWG2b9tQObL27SoMHdWWg22
Remote Control on his PC is no longer needed: the files download straight from Drive.

Inventory (checked 2026-11-11, Blender 3.6 file):

- `Modular_Apartment_Kit.blend` (519 MB) and `Textures_Modular_Apartment.zip` (917 MB, TGA at
  1024, 2048 and 4096 px). A third file, `blender-geometry-nodes_procedural-buildings.zip`,
  is an unrelated 2021 free Blender procedural-buildings demo (blend and video); ignore it.
- 71 modules, 4 m wide and 3 m per floor (1 floor = 3 m, so no rescale needed): flat, curved and
  rectangular window walls, corner and accent corners, outcrop (bay) walls left, right and centre,
  main and maintenance doors, roof straights, corners and outcrops, trim pieces, fire stairs
  (platform and stairway), window accents. Most modules come in two detail levels (`_01` simple,
  `_02` detailed). Modules are 15 to 2300 faces each.
- 6 ready-made apartment buildings (about 21 x 10 x 9.5 m). They cost 37k to 126k faces each:
  far too heavy to repeat in a city, so we never use them as-is.
- 20 materials in 6 texture sets (Accessories, Brick, Entrances, Roof, Trim, Windows) with
  colour variants (brick dark, red, tan; trim brown, green, white; roofs beige, blue, charcoal).
  Full PBR maps (base colour, normal, roughness, metallic and more).

Plan:

1. Use only the `_01` (low) modules plus a few `_02` for the district core buildings; skip the six
   ready-made apartments.
2. Build each building from modules in code, as now with Kenney (`building_visual.gd` merges to one
   mesh per building); colour variants by material swap.
3. Textures: use the 1024 px set, converted to JPEG, one atlas per set; drop normal, metallic and
   roughness maps (the toon shader makes everything matte). The repo stays small.
4. Export as `.glb` to `assets/models/cratial/` with the licence file, only the modules in use.
5. Far buildings use a plain merged box in the facade colour (LOD).
6. Compare a Slums street built from Cratial with the Kenney one and show Eilam both before
   anything is replaced.

Risks (honest): the kit is realistic, so the toon shader and a matte material do the toy look;
the free Kenney set may already be close enough for a clear Slums readout, so step 6 is a real
decision, not a formality. The licence must be checked for redistributing models in a shipped game.

## Open questions for Eilam

- Does the cult's gold stay the only "meaning" colour?
- Day only, or a day/night mood per district (nightlife wants night)?
