# CLAUDE.md

Guide for every Claude session that works on this repo. Read it before writing code.

## The project

An original god game with city building, made in **Godot 4** (standard build, GDScript, no C#).
The player is a real god in a modern city that denies him; the hand is the whole interface.
Design doc and research live outside the repo (links in `README.md`). `README.md` is the
player-facing guide in Hebrew; `CHANGELOG.md` is the update log in English.

Eilam, the owner, is not a programmer. Code quality is our responsibility, not his.
He chats in Hebrew; everything in the repo and in the game (UI, dialogue, code, comments,
commits) is in English.

Eilam runs the latest Godot 4 on Windows (4.7 at the time of writing). The project declares
the 4.3 feature level; do not use APIs newer than that without updating `project.godot`.

## Architecture

```
project.godot        main scene, autoloads, window settings
scenes/              main.tscn (the game), city_planning.tscn (planning sandbox)
scripts/             gameplay scripts for main.tscn
scripts/planning/    the city-planning sandbox (model, roads, terrain, visuals, UI)
data/                every tunable number, as .tres resources (one per system)
shaders/             toon (cel) shading, ghost fade, watercolour paper pass
assets/models/       third-party models (Kenney CC0), with their licence files
docs/                screenshot for the README
```

### Main game (`scenes/main.tscn`)

The scene is small; most nodes are built in code at startup.

| Node | Script | Role |
| --- | --- | --- |
| `Main` | `city.gd` | Builds the procedural Manhattan grid: ground, blocks, towers, park, trees, doors, taxis, citizens, litter, pigeons. Grid helpers used by citizens. Day/night (`set_daylight`). |
| `CameraRig` | `god_camera.gd` | B&W-style camera: grab-and-drag the city, orbit, zoom to cursor, fly-to, fade buildings that block the view. |
| `Faith` | `faith.gd` | Belief pool, believers, exposure. Miracles `report()` here; a few times a second witnesses with line of sight react once per event. |
| `GodHand` | `god_hand.gd` (+ `hand_visual.gd`, `gesture.gd`) | The interface: pick up, throw, tap, knock, uproot, gestures (circle = water miracle). |
| `Opening` | `opening.gd` | The burning-building opening and the Keepers of the Hand. Off for now (`enabled = false` in `main.tscn`), so the game starts in free play with a ready congregation. |
| `HUD` | `hud.gd` | The numbers the player may see. |

World objects, each self-contained and built in code: `citizen.gd`, `taxi.gd`, `swaying_tree.gd`
/ `uprooted_tree.gd`, `door.gd`, `litter.gd`, `pigeon.gd`, `fire.gd`, `rain.gd`.
`building_visual.gd` merges Kenney facade modules into one mesh per building.
`sfx.gd` makes placeholder sounds in code.

Groups used for lookups: `citizens`, `buildings`, `fires`, `doors`, `god_grabbable`,
`wind_reactive`, `no_toon`.

Physics layers: 1 = world (ground, buildings), 2 = citizens, 3 (bit value 4) = props.

### Art style (autoload `ArtStyle`, `scripts/art_style.gd`)

Gameplay code creates plain `StandardMaterial3D`s; `ArtStyle` swaps them for the toon shader
and draws the watercolour paper pass over the screen. Gameplay must not know about the style.
`V` toggles it. The god's hand and anything in group `no_toon` are left alone.
Tunables: `data/art_style.tres`.

### City-planning sandbox (`scenes/city_planning.tscn`)

A separate scene with no god and no people; may become a spin-off game.
`city_model.gd` is the pure model (no nodes): blocks, lots, zones, landmarks, growth, metrics.
`road_network.gd` is the street graph, `terrain.gd` the land, `planning_examples.gd` the three
example plans, `planning_visuals.gd` the placeholder looks, `planning.gd` the scene, tools and UI.
Tunables: `data/planning.tres`.

### Tunables

| File | Script (class) | Covers |
| --- | --- | --- |
| `data/hand_settings.tres` | `HandSettings` | hand and camera feel |
| `data/balance.tres` | `Balance` | belief, witnesses, exposure |
| `data/art_style.tres` | `ArtStyleSettings` | shading and watercolour |
| `data/planning.tres` | `PlanningSettings` | planning model |

### Who owns what

Several threads push to `main`. Message the owning thread before changing its files.

| Area | Files | Owner thread |
| --- | --- | --- |
| City, opening, planning | `city.gd`, `opening.gd`, `scripts/planning/`, `scenes/city_planning.tscn` | game-planning |
| Look | `art_style.gd`, `art_style_settings.gd`, `shaders/`, hand model | visual-style |
| Building models | `building_visual.gd`, `assets/models/` | model-library |

## Coding rules

These are binding for every change.

### Style

- Follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):
  tabs, `snake_case` functions and variables, `PascalCase` classes and nodes,
  `CONSTANT_CASE` constants, `_private` names with a leading underscore, lines up to 100
  characters, and the standard order of a script (signals, enums, constants, exports,
  public vars, private vars, onready vars, `_ready`, other virtuals, public methods,
  private methods).
- **Static typing everywhere**: every variable, parameter, return value and loop variable that
  is not obvious from `:=`. Give a resource preload its type
  (`const S: HandSettings = preload(...)`), not a bare `const S = preload(...)`.
- Give every script that other scripts talk to a `class_name`, and type references with it
  (`var city: City`, not `var city: Node3D` plus duck typing). Avoid `get()`, `has_method()`
  and untyped `Dictionary` records where a typed class would do.
- Comments explain why, not what. No dead code, no commented-out code, no unused files.

### Structure

- Small, focused scripts and scenes. One system per script; split a script when it passes
  roughly 400 lines or mixes jobs (model, visuals and UI belong in separate scripts).
- Systems talk through **signals**, not hard references. A child never reaches up with
  `get_node("../Something")`; the parent wires it, or it emits a signal.
- Autoloads only for truly global systems (today: `ArtStyle`).
- Keep visuals separate from logic, so real art can replace placeholders without touching
  gameplay.

### Tunable numbers

- Every number a designer might want to change lives in a `.tres` resource under `data/`,
  as an `@export` on its settings class, never hard-coded in a script. Constants are only for
  true constants (physics layer bits, array indices, maths).

### Performance

Target: a steady **60 fps on a mid-range PC**, and the game must also run on the
**Compatibility renderer** (OpenGL), not only Forward+.

- Nothing in `_process` / `_physics_process` that allocates or searches: no
  `get_node`, `find_children`, `get_nodes_in_group`, `load`, new arrays/dictionaries or string
  formatting every frame. Cache references in `_ready`, keep lists up to date with
  signals, and update UI text only when the value changes.
- Repeated objects (trees, people, cars, litter, windows, props) use **MultiMesh** or at least
  share one `Mesh` and one `Material` resource. Never create a mesh or material per instance.
- Keep primitive meshes low-poly (set `radial_segments` / `rings` on `SphereMesh`,
  `CapsuleMesh`, `CylinderMesh`; the defaults are thousands of triangles each).
- Far objects simulate and animate at lower detail (fewer updates, no physics, LOD or
  visibility ranges). Avoid O(n²) loops over all citizens; use a spatial grid.
- Turn off `_process` (`set_process(false)`) on objects with nothing to do.
- Measure with the Godot profiler and the Monitors tab (draw calls, primitives, script time).

### Before pushing

1. `git pull` right before you push; message the owning thread before changing its files.
2. Run the project headless with no errors and no new warnings:
   `godot --headless --path . --quit-after 600` and the same for
   `res://scenes/city_planning.tscn`.
3. Test the feature you changed. For visual changes, take a screenshot
   (`godot --path . -- --shot=out.png` saves one after 120 frames) and share it.
4. Check that both renderers still start (`--rendering-method gl_compatibility`).
5. Add an entry to `CHANGELOG.md`: date, what changed, how to try it.
6. Update this file when the structure changes (new system, new scene, new owner).
