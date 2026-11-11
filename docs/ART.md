# Art bible

The one living document for the look of the game. Owner: the Artist thread. Art Director: Eilam.
Older research (dollhouse-style, visual-style, hand-moodboard) is folded in here; the originals
stay in the project's shared folder under `research/` and `style-refs/`.

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
| Zealots | orange `#FF7319` | |
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

The map lab/3D city currently still uses the old 9-district layout and names. The programmer
maps these 7 onto it when the district system changes.

## Residents (8 archetypes)

Markers first, models later. One colour per archetype, readable in the crowd, plus a small
head/hat or prop shape when close.

| Archetype | Colour | Close-up cue |
| --- | --- | --- |
| Homeless | muted brown | shopping cart / blanket |
| Blue collar | denim blue | hard hat |
| Student | bright teal | backpack |
| Retiree | lilac grey | cane |
| Partier | hot pink | party hat |
| Pink collar | coral | name badge / apron |
| White collar | pale grey-white | tie, briefcase |
| Bohemian | olive green | beret / scarf |

Believers get a gold ring or tint over the archetype colour; zealots orange. Exact values
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
