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
- Tone: a comedy about a tiny cult taking over an NYC-like city. No good or evil colour coding;
  the cult's gold is the only "meaning" colour.

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

## Cratial kit pipeline (planned)

The kit is on Eilam's PC (desktop folder `claude`), too large to upload, so it is processed
there over Remote Control and only the trimmed result is committed.

1. Inventory the pack: list modules, formats, polycount, texture sizes.
2. Import into a scratch Godot project; fix scale to metres (1 floor = 3 m, ground at y = 0).
3. Materials: swap to the shared matte material set; textures cut to 512-1024 px JPEG;
   atlas where possible so a building is one draw call.
4. Keep only the modules the 7 districts need; drop the rest (always prune).
5. Export `.glb` into `assets/models/cratial/` with its licence file.
6. LOD: a low version per module (merged box with the facade colour) for far chunks.
7. Hand the programmer a module list and a build recipe per district (what goes where).
8. Show Eilam a rendered turntable and a district screenshot for his verdict before it replaces Kenney.

## Open questions for Eilam

- Does the cult's gold stay the only "meaning" colour?
- Day only, or a day/night mood per district (nightlife wants night)?
