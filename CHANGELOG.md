# Changelog

One entry per update, newest first. Each entry says what changed and how to try it.
Run the main game with F5; run a single scene by opening it in the FileSystem panel and pressing F6.

## 2026-10-25: CLAUDE.md with the architecture and coding rules
- Added `CLAUDE.md` at the repo root: a map of the scenes, scripts, data files and who owns what, plus the coding rules every session follows (GDScript style guide, static typing, signals over hard references, tunables in `data/*.tres`, no per-frame allocations or node searches, MultiMesh for repeated objects, 60 fps on a mid-range PC, Compatibility renderer support, checks before pushing).
- No game code changed. A code-quality audit with a fix plan is waiting for Eilam's approval.
- Try it: nothing to run; open `CLAUDE.md` to read it.

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
