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
scripts/people/      residents: Population, Resident records, social groups, debug card
scripts/props/       Meshy props: facade and roof dressing, sidewalk props, their models
scripts/planning/    the city-planning sandbox (model, roads, terrain, visuals, UI)
data/                every tunable number, as .tres resources (one per system)
shaders/             toon (cel) shading, ghost fade, depth of field, tilt-shift + colour grade
assets/models/       third-party models (Kenney CC0) and our Meshy props (meshy/), with licence notes
tests/               headless tests that drive the real game (run before pushing)
docs/                screenshot for the README
```

### Main game (`scenes/main.tscn`)

The scene is small; most nodes are built in code at startup.

| Node | Script | Role |
| --- | --- | --- |
| `Main` | `city.gd` | Builds the procedural Manhattan grid (unevenly spaced avenues and streets): ground, blocks, towers in two height clusters, park, plazas, trees, doors, taxis, citizens, litter, pigeons. Grid helpers (`intersection`, `nearest_grid`, `block_of`, ...) used by citizens and districts. Day/night (`set_daylight`). |
| `CityProps` | `props/city_props.gd` (+ `street_prop.gd`, `prop_model.gd`, `prop_kind.gd`) | Dresses the built city with the Meshy models: air conditioners under windows and water tanks / cooling units on roofs (MultiMesh per kind and chunk of town; roof props follow new floors and hide under a penthouse), and sidewalk props the hand can pick up (`StreetProp`; trash bags squash under weight and on landing). Tunables `data/city_props.tres`. |
| `CameraRig` | `god_camera.gd` | B&W-style camera: grab-and-drag the city, orbit, zoom to cursor, fly-to, fade buildings that block the view. |
| `Surroundings` | `world/surroundings.gd` (+ `world/outskirts.gd`) | Scenery past the grid, built once: land and hills (with a height-map collision floor), the river, promenade and bridges, roads leaving the grid, outer neighbourhoods and woods, clouds, and the depth haze that hides the edge. |
| `Population` | `people/population.gd` | Gives every person a `Resident` record (name, `SocialGroup`, home, work, family, friends). `resident.gd` is the record, `social_group.gd` the per-group traits, `crowd.gd` (`Crowd`, a child it makes) draws every person's body in one MultiMesh. Believers the hand sets down on or at a building sit in there; `power_presence(building)` (cached) and `believer_share(building)` feed the claim meter; `evacuate`, `evict` and `preach_to` change who lives where and believes. Drops a building that leaves the tree. |
| `Faith` | `faith.gd` | Belief pool, believers, exposure. Miracles `report()` here; a few times a second witnesses with line of sight react once per event. |
| `GodHand` | `god_hand.gd` (+ `hand_visual.gd`, `gesture.gd`) | The interface: pick up, throw, tap, knock, uproot, right-button gestures. Emits signals (`long_pressed`, `tool_clicked`, `circle_drawn`, ...) for the tools. |
| `Miracles` | `miracles.gd` | Casts the miracles (water, fire, lightning, shield, heal, roaches, money): spends belief and reports to `Faith`. A burnt-out or roach-infested building is emptied (`Population.evacuate`) and announced with `building_abandoned`. Effects: `rain.gd`, `fire.gd`, `lightning.gd`, `shield.gd`, `heal.gd`, `roaches.gd`, `money_rain.gd`. |
| `Decrees` | `decrees.gd` (+ `decree_looks.gd`) | Divine decrees on the god's own buildings (`Districts.owns()`): add floors, luxury, facade, change use, preserve; paid in belief and `Treasury` money. Preserved buildings are in group `preserved`. |
| `HandTools` | `hand_tools.gd` (+ `radial_wheel.gd`) | The two wheels opened by holding the button still: decrees on your building, the three `Campaigns` takeover marks on anyone else's, miracles elsewhere. A chosen miracle sits in the hand until cast. |
| `SignFollowers` | `sign_followers.gd` (+ `divine_sign.gd`) | Believers act on the divine signs, by the sign and the god's path. |
| `Districts` | `world/districts.gd` (+ `district_view.gd`, `district_hud.gd`) | Splits the city into 3 x 3 districts and keeps who holds every building: yours once most of its residents believe (an empty one, while a believer sits in); abandoned buildings; the cult starts from its headquarters; a district is yours at 60%. `DistrictView` puts a gold plate on yours. Tunables `data/districts.tres`. |
| `Treasury` | `world/treasury.gd` | The cult's money: tithes from believers, and each building of yours earns or costs money by its decrees (`net_of`, `net_if`: rent, use upkeep, shop, luxury speed, floor efficiency) and its district's wealth; `spend_money` / `add_money`. Tunables `data/treasury.tres`. |
| `Campaigns` | `world/campaigns.gd` (+ `campaign_marks.gd`) | The three takeover marks on a building (force, buy, missionaries), carried out by believers until most residents believe. Tunables `data/campaigns.tres`. |
| `Government` | `government/government.gd` (+ `bulldozer.gd`, `demolition_notice.gd`) | City Hall: inspector, demolition notice, bulldozer. Tunables `data/government.tres`. |
| `ResidentCard` | `people/resident_card.gd` | Debug (B): hover a person to see who they are and lines to family, friends, home, work. |
| `DebugPanel` | `debug_panel.gd` | Testing shortcuts (F1 hides). Not part of the game. |
| `Opening` | `opening.gd` | The burning-building opening and the Keepers of the Hand. Off for now (`enabled = false` in `main.tscn`), so the game starts in free play with a ready congregation. |
| `HUD` | `hud.gd` | The numbers the player may see. |

World objects, each self-contained and built in code: `citizen.gd`, `taxi.gd`, `swaying_tree.gd`,
`door.gd`, `litter.gd`, `pigeon.gd`.
`building_visual.gd` merges Kenney facade modules into one mesh per building.
`shared_meshes.gd` (`SharedMeshes`) hands out low-poly primitive meshes shared by every instance.
`sfx.gd` makes placeholder sounds in code.

Groups used for lookups: `citizens`, `buildings`, `fires`, `doors`, `god_grabbable`,
`wind_reactive`, `no_toon`, `preserved`.

Physics layers (bit values in code): 1 = world (ground, buildings), 2 = citizens,
3 (4) = props (taxis, trees, litter), 4 (8) = critters (pigeons, as Area3D so the hand's wind
query finds them). The hand finds what to pick and what to blow on with physics shape queries
around itself, never by scanning a group.

### Art style (autoload `ArtStyle`, `scripts/art_style.gd`)

Gameplay code creates plain `StandardMaterial3D`s; `ArtStyle` swaps them for the toon shader
once, the frame after a mesh enters the tree, and draws depth of field, tilt-shift and the
colour grade over the screen. Gameplay must not know about the shader. One rule: code that
changes a mesh's `material_override` later (a burnt building, the belief debug tint, a planning
overlay) calls `ArtStyle.restyle(mesh)`. Colour changes on a plain material are synced
automatically. `V` toggles the style. The god's hand and anything in group `no_toon` are left
alone. Tunables: `data/art_style.tres`.

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
| `data/miracles.tres` | `MiracleSettings` | miracle costs, reach and effects |
| `data/decrees.tres` | `DecreeSettings` | divine decree costs, exposure and limits |
| `data/people.tres` | `PeopleSettings` (+ `SocialGroup`s) | residents, groups, names, walking |
| `data/art_style.tres` | `ArtStyleSettings` | cel shading, depth of field, tilt-shift, colour grade |
| `data/planning.tres` | `PlanningSettings` | planning model |
| `data/surroundings.tres` | `SurroundingsSettings` | land, river, outer neighbourhoods, clouds, haze |
| `data/city_props.tres` | `CityPropsSettings` (+ `PropKind`s) | which Meshy props go where, how many, how bags squash, the taxi model |
| `data/districts.tres` | `DistrictSettings` | districts, wealth, who holds a building, start district |
| `data/treasury.tres` | `TreasurySettings` | money: tithes, rent, use upkeep, shops, luxury, floors |
| `data/campaigns.tres` | `CampaignSettings` | takeover marks: crews, prices, sermons |

### Who owns what

Several threads push to `main`. Message the owning thread before changing its files.

| Area | Files | Owner thread |
| --- | --- | --- |
| Hand, miracles, decrees, wheels, city, opening, planning | `god_hand.gd`, `hand_tools.gd`, `miracles.gd`, `decrees.gd`, `decree_looks.gd`, `city.gd`, `opening.gd`, `scripts/planning/` | "Design the hand" (game-planning) |
| People | `citizen.gd`, `faith.gd`, `sign_followers.gd`, `scripts/people/` | "Build the people in the city" |
| Look | `art_style.gd`, `art_style_settings.gd`, `shaders/`, `hand_visual.gd`, hand model | visual-style |
| Building models | `building_visual.gd`, `assets/models/kenney_modular/` | model-library |
| Meshy props | `scripts/props/`, `assets/models/meshy/`, `data/city_props.tres` | "Test the Meshy connection" |
| World: districts, City Hall, surroundings | `scripts/world/`, `scripts/government/` | "World and stages" |
| Code quality, `CLAUDE.md`, `tests/`, `shared_meshes.gd` | | code-quality |

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
- Load a `.tres` whose typed arrays hold a custom `Resource` class with `load()` at run time,
  not a `const` `preload()`: the parse-time preload loads the element script before its
  `class_name` is registered and breaks the typed array.
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
   `res://scenes/city_planning.tscn`. After adding a `class_name`, run
   `godot --headless --path . --import` once so the class is registered.
3. Run the hand test: `godot --headless --path . res://tests/hand_test.tscn` must print
   `HAND TEST: PASS` (exit code 0). Add a check there when you add a hand behaviour.
4. Test the feature you changed. For visual changes, take a screenshot
   (`godot --path . -- --shot=out.png` saves one after 120 frames) and share it.
5. Check that both renderers still start (`--rendering-method gl_compatibility`).
6. Add an entry to `CHANGELOG.md`: date, what changed, how to try it.
7. Update this file when the structure changes (new system, new scene, new owner).
