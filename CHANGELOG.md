# Changelog

One entry per update, newest first. Each entry says what changed and how to try it.
Run the main game with F5; run a single scene by opening it in the FileSystem panel and pressing F6.

## 2026-10-26: Taking over a place: the claim meter
- Every building now has a claim meter from 0 to 100%. At 100% it is yours; it slips back below 50%. For now only the power route fills it: believers who live there, believers in the street outside, and your buildings next door. With nothing holding it, the claim slowly fades.
- The beachhead rule: outside your influence zone (the buildings next to yours) only an abandoned place can be claimed. The cult starts from its headquarters, the building where most believers live; its district is the neglected start district, where about a third of the buildings are abandoned. A few more are scattered through the city.
- Abandoned places nobody holds have a grey roof plate; yours stay gold. The bottom-left panel shows the claim on the building in the middle of the screen ("Building: 40% claimed, abandoned").
- City Hall's inspection now cuts the claim on the building it inspects (35 points), on top of the demolition notice.
- Decrees follow the claim meter: a building is yours for decrees once its claim is full, no longer when half of its residents believe (`owner_share` is gone from `data/decrees.tres`).
- Numbers: `data/districts.tres` (Claim meter, Start district) and `inspection_claim_cut` in `data/government.tres`.
- Try it: press F5. Move the view to a grey roof near the start, then drag a couple of believers next to it with the hand and watch the "Building" line climb.

## 2026-10-26: Fix: crash when a tree in the hand's wind disappears
- The game stopped with "Trying to assign invalid previously freed instance" in `god_hand.gd` (`_blow`) when a tree the hand's wind had just reached was removed, for example uprooted. The wind now skips anything that no longer exists.
- The hand test checks this case.
- Try it: press F5, wave the hand over a tree, then pull it out by its roots.

## 2026-10-26: Divine decrees: edit your buildings from the building wheel
- Holding the left button still on a building now opens the building wheel: five divine decrees plus the three signs.
- The decrees: +3 Floors (the building grows out of its roof; up to three times), Luxury (marble lobby, gold canopy, penthouse), Facade (banners and lights in your colours), Change Use (a rooftop sign: Prayer House, then Course Center, then Free Personality Test) and Preserve (a "Form 12-B" plaque; the building joins the `preserved` group, for the demolition code to respect).
- A decree only works on your own building: one where at least half of the residents believe. Elsewhere its slices are grey and say "not yours". Decrees are paid in belief for now (money and influence come later) and are cheaper among believers, like the miracles. Each one raises exposure a little; new floors raise it the most.
- Signs: the "Clear" slice is gone. Choosing the sign a building already has takes it down.
- Numbers: `data/decrees.tres`.
- Try it: press F5, click "Believers come here" on the debug panel (F1), then hold the left button still on one of the buildings they moved into and pick +3 Floors.

## 2026-10-26: No more good and evil for the people
- The new direction has no good or evil, so the god's path is gone: no good/evil deed counting, no "Path" in the HUD, no Path buttons on the debug panel.
- Believers answering a cursed building now hold a rally in front of the entrance (no more vandalising, boycotts or asking for the manager). A protected building gets a human chain in robes, which still fights fire. Blessed is unchanged: they pray.
- Try it: press F5, hold the left button still on a building, pick the storm cloud, and watch nearby believers walk over and rally.

## 2026-10-26: Districts follow the residents; City Hall respects landmarks
- One answer to "is this building yours?", shared by districts and decrees: a building people live in is yours while at least half of its residents believe; an empty one (offices, shops) turns through influence, from believers in the street outside and your buildings next door. Its gold roof plate comes and goes with it, and you can now decree on an empty building you won through influence.
- City Hall never targets a preserved building, and a visit with a notice up is called off if the building is preserved in the meantime ("the building was declared a landmark").
- The gold roof plate rises with +3 Floors, and the bulldozer measures the building when it arrives, not when it was sent.
- Try it: press F5, open the debug panel (F1), click "Take 10 buildings here" (their residents now start believing), then preserve one of them from the building wheel and raise exposure.

## 2026-10-26: A city that doesn't end in a void
- The city no longer sits on a grey slab in white emptiness. Around it now: green land that rises into wooded hills, a river along the east side with a promenade on both banks and two bridges, and outer neighbourhoods. The avenues and side streets carry on past the grid and bend and fan out, ring roads circle the city, and houses line the roads and turn with them: blocks near the city, houses with red roofs further out, and a second little skyline across the river. Clouds drift around the horizon, and a haze in the colour of the sky melts the far land into it, so there is no edge.
- The grid itself is less even: avenues and streets are spaced unevenly, so blocks come in different sizes; towers rise in two clusters (downtown at the south tip and midtown), with low streets between them; four half blocks are open plazas with a lawn and trees. The sky is a brighter blue.
- All of it is scenery, built once into a few merged meshes. Things thrown out of town land on the hills or in the river.
- Numbers: `data/surroundings.tres` (land, river, roads, neighbourhoods, clouds, haze, colours).
- Try it: press F5, zoom all the way out (mouse wheel) and tilt the camera low (R/F), then look toward the river and the hills.

## 2026-10-26: Districts, buildings that change sides, and City Hall's bulldozer
- The city is split into 9 districts (3 x 3), outlined on the roads. The bottom left of the screen shows the district in the middle of the screen, how much of it is yours, and what City Hall is doing.
- Buildings change sides on their own: believers on the street outside lean on a building, and every building that is already yours leans on its neighbours across the street. Wide avenues stop the spread. A building of yours gets a glowing gold plate on its roof; a district is yours at 60%, and its outline turns gold.
- City Hall: once exposure reaches 10%, a building inspector in a white hard hat walks to one of your buildings (one with a blessed or protected sign first) and posts a red demolition notice. 45 seconds later a bulldozer drives up and pushes the building into the ground, leaving rubble.
- What stops it: a shield over the bulldozer, three believers standing at the building (put a Protected or Blessed sign on it), lightning near the bulldozer, or simply picking the bulldozer up. Picking up the inspector before he arrives also sends him home. After a visit City Hall waits a minute (30 seconds if you stopped it); taking a district brings it right away.
- Numbers: `data/districts.tres` and `data/government.tres`. Debug panel: "Exposure +20%" and "Take 10 buildings here".
- Try it: press F5, click "Believers come here", "Take 10 buildings here" and "Exposure +20%", then follow the inspector and get a shield ready for the bulldozer.

## 2026-10-26: Smoother city, faster planning scene, sturdier hand
- Trees, pigeons and people are drawn with far fewer triangles (round shapes were 4,000 triangles each; now a few hundred), and every tree shares one shape. The city draws about 2.3 million triangles a frame instead of 6.2 million. It looks the same.
- The art style now styles each object once, when it appears, instead of re-checking every object every frame.
- The planning scene recounts its city totals only when the city changes, and rebuilds the hover text only when the cursor moves to something new. Its scripts went from about 9 ms to under 1 ms a frame.
- The hand only looks at things near it when choosing what to grab and what its wind blows on (it used to check every person, tree and taxi in the city). About three times cheaper, and the cost no longer grows with the city.
- Switching windows (Alt+Tab) while holding something now puts it down, and closes an open wheel, instead of leaving it stuck in the hand.
- New automatic hand test: `tests/hand_test.tscn` picks up, throws, taps, knocks, blows on a tree, scares pigeons and checks focus loss, with a simulated mouse.
- Try it: press F5 and play as usual; press Alt+Tab while holding a taxi. The test runs from the command line: `godot --headless --path . res://tests/hand_test.tscn`.

## 2026-10-26: Every resident is a person: name, home, work, family, friends
- The 60 residents are no longer anonymous. Each has a name, one of 7 groups (student, office worker, shopkeeper, retiree, artist, police officer, banker), a home in a real building, a workplace (glass towers are offices; retirees don't work), 1 to 3 family members living with them, and 2 to 5 close friends, mostly neighbours and colleagues. Their hidden skepticism comes from their group.
- New system: `Population` (scripts/people/) holds these records; the walking body (citizen.gd) reads and writes belief on the record. Other systems can ask it who lives where, and what share of a building believes.
- Skipping the opening, the congregation is now whole families moving into the homes nearest one corner. "Believers come here" on the debug panel moves believers into the nearest home.
- Numbers, groups and names: `data/people.tres`. Falling, walking and wandering numbers moved there from citizen.gd.
- Try it: press F5, press B, and hover over a person. A card shows who they are, with lines to their family (gold), friends (blue), home (green) and work (grey).

## 2026-10-26: Miracles grow with the believers nearby
- A miracle's power now comes from the believers around the spot it is cast on. Among your believers it is bigger (up to 1.6x the radius), lasts longer (up to 1.5x) and costs less (0.6x). Among skeptics it is small (0.6x), short (0.7x) and dear (1.3x). This affects the rain, the street fire, the lightning blast, the shield dome and the healing light.
- You can see it: the hand turns warm and glows over your believers and pale grey away from them. The HUD shows "Miracle power here", and the miracle wheel shows the cost at that spot.
- The hand can still lift anything; only the miracles depend on believers.
- Numbers: `data/miracles.tres`, group "Miracle power" (radius 70 m; the summed belief of 6 devoted believers gives full power).
- Try it: press F5, click "Believers come here" on the debug panel (F1), then hold the left button still next to them and far from them and compare the costs in the wheel and the size of a shield.

## 2026-10-26: Softer colours with a warm wash
- Colours are calmer: less saturation, vibrance and contrast than yesterday's toy-box grade.
- A soft warm wash lies over the whole picture and ties the colours together, like The Sims. It replaces the old warmth multiply.
- Settings: `data/art_style.tres`, group "Colour grade" (`wash_color`, `wash`; `warmth` is gone).
- Try it: press F5; press V to compare with the plain look.

## 2026-10-26: Watercolour removed; playful toy-town colours
- The watercolour look is gone: no paper texture, no colour bleeding, no darkened edges, no grain, no wobble, no paper border, no wash blotches on buildings. (To bring it back, see the 2026-10-25 entries and git history.)
- The tilt-shift and depth of field are unchanged.
- Colours lean more game-like: a bit more saturation, warm sunlight, cool (not lavender) shadows. No outlines.
- The screen pass is now `shaders/screen_pass.gdshader` (tilt-shift + colour grade). Settings in `data/art_style.tres`; the "Pigment" and "Paper pass" groups are gone, `saturation` moved to "Colour grade".
- Try it: press F5; press V to compare with the plain look.

## 2026-10-25: Depth of field: what is near stays sharp, the background melts
- Like a macro photo of a miniature: whatever stands in the middle of the screen is in focus, and everything further away blurs softly. Things nearer than that (the hand, whatever it lifts, the tops of tall towers) stay sharp. It adds to the tilt-shift for a smoother, more natural blend between the city and the background.
- Numbers: `data/art_style.tres`, group "Depth of field" (`dof_blur` 0 turns it off). V still switches the whole style off to compare.
- Try it: press F5 and tilt the camera toward the horizon (middle-drag) to see the far streets melt.

## 2026-10-25: A short click casts the miracle in the hand
- With a miracle in the hand, a short click on the ground or a building casts it (a long press still works too). Dragging still moves the city.
- The miracle fills the hand: until it is cast or dropped (right click), the hand doesn't pick anything up or highlight people, so a click on someone casts the miracle there instead of lifting them.
- Try it: press F5, hold the left button still on a street, pick Lightning, then click on a group of people.

## 2026-10-25: Debug panel for testing
- A small panel on the right (F1 hides it): Believers +5 (the nearest non-believers to the middle of the screen), Believers -5, Believers come here (every believer moves to the corner in the middle of the screen), Belief +100, and Path: good / evil / neutral.
- Try it: press F5, click "Believers come here", then put a sign on a building next to them.

## 2026-10-25: Believers answer the divine signs
- A sign on a building now costs 3 belief, and up to six believers nearby walk over and act on it, each by the sign and by the god's path. The path ("Path" at the top of the screen) comes from your miracles so far: water, shield and heal are good deeds, fire and lightning evil ones; one kind has to lead by 3 to set it, otherwise you are neutral.
- Blessed: they gather to pray, and each one adds belief to the pool.
- Cursed: on the evil path they vandalise it until it catches fire (raises exposure); on the good path they picket it from across the street; on the neutral path they ask to speak to the manager.
- Protected: they stand guard and fight any fire on that building.
- Unsure believers now and then misread the sky ("Wait... was that a cloud or a halo?") and do something else.
- Signs still don't change anyone's belief: only miracles do.
- Numbers: group "Divine signs" in `data/miracles.tres`; how big a lead sets the path: `path_lead` in `data/balance.tres`.
- Try it: press F5, cast fire and lightning a few times until Path says evil, then hold the left button still on a building near your believers (the start area) and pick Cursed.

## 2026-10-25: Picking a miracle puts it in the hand
- Choosing a miracle on the wheel no longer casts it straight away. It goes into the hand (a glowing orb in the palm, and "In the hand: ..." at the top of the screen). The next long press, on the ground or on a building, casts it there. A right click drops it. Moving, lifting and throwing work as usual while it is in the hand.
- Try it: press F5, hold the left button still on a street, pick Fire and let go. Then hold the left button still on a building.

## 2026-10-25: Wheel drawn on its own top layer
- The miracle and sign wheels now draw on their own screen layer above everything else (the HUD and the art style's watercolour pass), sized to the whole window. Fix attempt for the wheel not showing on one Windows PC while its clicks worked.
- Try it: press F5 and hold the left button still on a street.

## 2026-10-25: Dollhouse look: stronger tilt-shift, crisp sun shadows, livelier colours
- Tilt-shift is much stronger and starts lower: from above, the top and bottom of the screen blur like a photo of a miniature, with a narrower sharp band.
- New sun lighting in the toon shader: a lower sun (longer shadows), crisp shadow edges (no blur), cast shadows with their own darkness, a warm key light and a bright toy-like rim on sunlit edges. The art style now sets the sun's angle and shadow quality; the day/night cycle still sets its brightness and colour.
- Livelier, more playful colours: stronger saturation, a vibrance and contrast grade, a slightly warm picture.
- The Kenney buildings now get the art style too (their textures go through the toon shader).
- Every number: `data/art_style.tres` (new groups "Sun and shadows" and "Colour grade"; tilt-shift numbers changed).
- Try it: press F5, zoom out with the wheel to see the tilt-shift, and press V to compare with the plain look.

## 2026-10-25: Both wheels open with a long left press; easier uprooting
- Hold the LEFT button still for half a second on the ground: the miracle wheel opens around the hand. On a building: the sign wheel. The hand stays in the middle, grows so it can be seen from high up, and points where you move the mouse; the slice it points at lights up. Let go to cast the miracle on that spot, or give the sign to that building. Letting go in the middle, or a right click, cancels.
- The right-button wheel and the "miracle in the hand" mode are gone. Drawing a circle with the right button still casts water.
- Fire cast at the foot of a building sets the building alight; water cast near a fire goes onto it.
- Trees come out much more easily (about seven times less effort).
- Try it: press F5, hold the left button on a street, point at Fire and let go next to a building. Then do the same with Water and Heal. Grab a tree and pull.

## 2026-10-25: Miracle wheel, five miracles and divine signs on buildings
- Hold the RIGHT mouse button still for a moment: the miracle wheel opens around the hand. Point at a miracle and let go. The miracle stays in the hand (a glowing orb in the palm), and every short left click casts it there. Dragging the city, lifting and throwing work as before meanwhile. A short right click puts the miracle away. Drawing a circle with the right button still casts water straight away.
- Five miracles, each costing belief: Water (rain puts out fires), Fire (the building under the hand catches fire, or a small fire in the street; it burns out after a minute), Lightning (people nearby are knocked off their feet, cars jump and their alarms go off), Shield (a dome for 20 s; no fire or lightning inside it, fires under it go out), Heal (people lying hurt get up, burnt buildings are rebuilt). Every miracle is seen by the people around and changes what they believe.
- Hold the LEFT mouse button still on a building for half a second: the building lights up and the sign wheel opens. Blessed (a beam of light), Cursed (a storm cloud), Protected (a ring of light) or Clear. Signs only mark buildings for now; believers will act on them later.
- The belief pool starts at 100 so there is room to try the miracles.
- All the numbers: `data/miracles.tres` (water moved there from `data/balance.tres`). Wheel timings: `data/hand_settings.tres`.
- Try it: press F5, hold the right button, pick Fire, click a building, then pick Water and click it, then Heal.

## 2026-10-25: CLAUDE.md with the architecture and coding rules
- Added `CLAUDE.md` at the repo root: a map of the scenes, scripts, data files and who owns what, plus the coding rules every session follows (GDScript style guide, static typing, signals over hard references, tunables in `data/*.tres`, no per-frame allocations or node searches, MultiMesh for repeated objects, 60 fps on a mid-range PC, Compatibility renderer support, checks before pushing).
- No game code changed. A code-quality audit with a fix plan is waiting for Eilam's approval.
- Try it: nothing to run; open `CLAUDE.md` to read it.

## 2026-10-25: The main scene is a hand test bed; lifting is play, not a miracle
- The opening (the burning building) is switched off for now: the game starts straight in free play in daylight, with a congregation ready. To bring it back, select the `Opening` node in `scenes/main.tscn` and turn on `enabled`.
- No strength limit: the hand lifts anything anywhere, at full grip, for free. The strength ring under the hand and the strength number at the top are gone. A different limit will come later.
- Lifting and throwing no longer change anyone's belief and no longer raise exposure. Belief comes only from miracles (for now, the water miracle).
- Try it: press F5 and pick up a taxi or a tree far from your believers.

## 2026-10-25: Real building models instead of boxes
- The towers in the main city are now built from Kenney's free Modular Buildings kit (CC0): a facade module for every floor and bay, a shopfront ground floor, a flat roof, and three colour schemes. Towers over 60 m use large glass windows on every floor.
- The models are used as they come from the kit for now; the soft cel-shading style does not apply to them yet (that needs a small shader change). Gameplay is unchanged: same city layout, same collision, the opening fire, the camera fade and the hand all work as before.
- Kit files and licence: `assets/models/kenney_modular/`.
- Try it: press F5. The first time you open the project, Godot imports the new models (a few seconds).

## 2026-10-25: Changelog and in-game language
- Added this changelog. All in-game text is in English (it already was; this is now the rule).

## 2026-10-25: City planning on 3D terrain with streets you can draw (7896c11)
- The planning scene sits on hills and a river. The starting streets follow the land: straight on the flat, bending around slopes, stepped paths where too steep for cars, bridges on a few avenues, a road along each bank.
- Draw streets, avenues and paths like the paths in BW2. While you drag, the line is green, yellow or red by slope. Roads bend around slopes unless Straight is on. A new road splits the roads it crosses, and the blocks are re-shaped around it.
- Make a street car-free or remove it. Buildings on slopes stand on stone bases. Landmarks built higher reach further (hill bonus).
- The three example plans now shape streets too.
- Try it: open `scenes/city_planning.tscn`, press F6, pick Street / Avenue / Path and drag on the map.

## 2026-10-25: City planning: organic growth and three example plans (4ce1dfe)
- Lots of different widths, landmarks anywhere in a block, soft heat overlays on the ground and tinted buildings.
- Buildings are gradually rebuilt in the look of the god their street belongs to: good (warm colours, roof gardens), evil (grey slabs, red neon) or neutral (glass, billboards).
- Example plans: good god (Jacobs and Gehl), evil god (Moses and Haussmann), neutral god (business district around stations), each showing what the city produces per minute.
- Try it: in the planning scene, click Good god / Evil god / Neutral god at the top.

## 2026-10-25: City-planning model as a separate scene (7acd18a)
- A sandbox with no god and no people, built on the design doc's three building levels: zoning (homes, shops, industry, density), landmarks (temple, station, square, tower, factory) and street details (tree, bench, camera, shrine).
- Keys 1-7 switch colour overlays: zoning, belief, commerce, quality of life, fear, influence. Hovering a tool shows its reach and what it would add before you place it.
- Try it: open `scenes/city_planning.tscn` and press F6.

## 2026-10-25: Art style: tilt-shift (10d85dc)
- A gentle tilt-shift blur that grows as the camera rises, for a miniature look.
- Try it: run the game and zoom out. V toggles the art style.

## 2026-10-25: Art style: soft cel shading and watercolour (7aafbb9, e22efc0)
- Soft cel shading with three light levels and lavender shadows, plus a watercolour paper pass over the screen. Later softened.
- Try it: run the game. V compares with the plain look. Numbers are in `data/art_style.tres`.

## 2026-10-25: Opening: the Keepers of the Hand (ef80283)
- Maya is replaced by the Keepers of the Hand: Old Nadia teaches the god, and Victor the strategist gives the next task.
- Try it: run the game (F5). The opening starts by itself.

## 2026-10-25: Opening scene: the burning building (29769df)
- Night, a building on fire, someone trapped on the roof. Right-drag a circle to make it rain (the water miracle).
- Each witness picks an explanation (miracle, luck, hoax or plot), shown above their head. The survivor becomes the first believer, and a newspaper reports a "localised weather event" in the morning.
- Try it: run the game. Space advances the dialogue, Tab skips to free play.

## 2026-10-25: Soft hand limit (1d945b5)
- The hand can lift anything. Past the local strength the grip weakens and costs belief per second; prayers refill the pool. A ring under the hand shows the strength there.
- Try it: lift a taxi far from your believers and watch the ring and the Belief counter.

## 2026-10-24: Hand milestone 3: witnesses and strength (599508e)
- People who see a miracle stop and stare, and their hidden belief changes. People with phones film it, which raises exposure.
- Hand strength comes from nearby believers. Placeholder sounds per surface. The hand holds one thing at a time.
- Try it: lift people near the congregation and watch the counters at the top.

## 2026-10-24: Whole-hand grab and easier uprooting (b3e66ba)
- One grab rule for everything, with a forgiving reach. The building under the hand never fades. Uprooting tension comes from pull distance plus hand speed.
- Try it: grab and yank a tree.

## 2026-10-24: Uproot trees, see-through buildings (a0f51d3)
- Wiggle to uproot a tree, place gently to replant, throw it to kill the roots.
- Buildings that hide the hand turn see-through instead of pushing the camera.
- Try it: drag a tree, or move the hand behind a tall building.

## 2026-10-24: Hand milestone 2: the world reacts (50bffea)
- Forgiving selection with a gentle pull towards people. Wind moves trees, litter and pigeons. Knocking opens doors, a tapped taxi sets off its alarm, thrown people tumble and get up.
- Try it: wave the hand fast over a street, or click a wall.

## 2026-10-24: The hand is the cursor (d508460)
- The system cursor is hidden; the hand's fingertip is the pointer.

## 2026-10-24: Hand milestone 1: Black & White camera and hand (ecc0720)
- Grab-drag the city, double-click to fly, orbit and zoom at the cursor. Spring holding, throws with an arc.
- Try it: drag the ground to move, double-click to fly. Numbers are in `data/hand_settings.tres`.

## 2026-10-24: First playable prototype (eb9b18a)
- A procedural Manhattan-style city, a god camera, a hand that grabs and throws, and 60 citizens with hidden belief.
- Try it: run the game and press B to see belief.
