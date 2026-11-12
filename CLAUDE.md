# CLAUDE.md

Guide for every Claude session that works on this repo. Read it before writing code.

## The project

An original god game with city building, made in **Godot 4** (standard build, GDScript, no C#).
A comedy: you are the god of a small cult taking over an NYC-like city, district by district,
up to City Hall; the hand is the whole interface. The design is `docs/GDD.md` (owned by the
Game Designer thread) and the look is `docs/ART.md` (owned by the Artist thread); build what
they say. `README.md` is the player-facing guide in Hebrew; `CHANGELOG.md` is the update log
in English.

Eilam, the owner, is not a programmer. Code quality is our responsibility, not his.
He chats in Hebrew; everything in the repo and in the game (UI, dialogue, code, comments,
commits) is in English.

Eilam runs the latest Godot 4 on Windows (4.7 at the time of writing). The project declares
the 4.3 feature level; do not use APIs newer than that without updating `project.godot`.

## Architecture

```
project.godot        main scene, autoloads, window settings
scenes/              main.tscn (the game), city_planning.tscn (planning sandbox), map_lab.tscn (2D map generator playground)
scripts/             gameplay scripts for main.tscn
scripts/people/      residents: Population, Resident records, archetypes, needs, preaching, staffing, debug card
scripts/props/       Meshy props: facade and roof dressing, sidewalk props, building-state props, their models
scripts/planning/    the city-planning sandbox (model, roads, terrain, visuals, UI)
scripts/maplab/      the map lab: districts' street styles, blocks, land use, menu
data/                every tunable number, as .tres resources (one per system); data/maps/ the stage maps
shaders/             toon (cel) shading, ghost fade, depth of field, tilt-shift + colour grade
assets/models/       third-party models (Kenney CC0, the god's glove from the WebXR hand, MIT) and our Meshy props (meshy/), with licence notes
tests/               headless tests that drive the real game (run before pushing), and pace_sim (a bot that plays the Slums fast, for balance)
tools/maplab/        the Map Lab generator and the stage map exporter (Node)
docs/                GDD.md (design), ART.md (art bible), screenshot for the README
```

### Main game (`scenes/main.tscn`)

The scene is small; most nodes are built in code at startup.

| Node | Script | Role |
| --- | --- | --- |
| `Main` | `city.gd` (`City`; + `world/city_plan.gd`, `world/plan_builder.gd`) | Builds the stage's map (`CityPlan.load_file(CitySettings.map_path)`, made in the Map Lab, see Stage maps): `PlanBuilder` lays the ground with its land colours, the streets as ribbons along their centre lines, every building turned to face its street (local -z), doors and trees; every building is its own node in group `buildings` (what the player takes, `City.building_nodes[i]`, index = map building index) with meta `block` (the map unit it stands in); `BuildingBox.building_of(collider)` turns a hit into a building. Taxis, litter, pigeons. The street graph people walk: `node_position`, `nearest_node`, `random_neighbor`, `walk_from`. Day/night (`set_daylight`). Tunables `data/city.tres`. |
| `CityProps` | `props/city_props.gd` (+ `street_prop.gd`, `prop_model.gd`, `prop_kind.gd`) | Dresses the built city with the Meshy models: air conditioners under windows and water tanks / cooling units on roofs (MultiMesh per kind and chunk of town; roof props follow new floors and hide under a penthouse), and sidewalk props the hand can pick up (`StreetProp`; trash bags squash under weight and on landing; dumpsters and bags in poor districts). Tunables `data/city_props.tres`. |
| `StateProps` | `props/state_props.gd` | Shows who holds a building with Meshy props on top of it, redressed on `Districts.building_changed` / `building_abandoned` and on the floors and luxury decrees: banner and roof flag (yours), boarded windows and rubble (abandoned), flower boxes and planters (luxury), laundry (poor districts). |
| `TypeMarkers` | `props/type_markers.gd` (+ `use_marker.gd`) | Shows a building's Change Use with a Meshy prop on its roof or by its front. Kept apart from `StateProps` so the source of a building's type can change. |
| `UpgradeMarkers` | `props/upgrade_markers.gd` (+ `upgrade_marker.gd`) | Shows the upgrades a building has bought (`BuildingUpgrades.upgraded`, `bought_in`) with Meshy props, one marker per `BuildingUpgrades.Kind` (housing, sermon house, shop). |
| `CoreMarkers` | `props/core_markers.gd` | Each district's core building (`Districts.core_of`) gets a portico in front and a signboard with the district's name on the roof; moves on `core_changed`. |
| `CameraRig` | `god_camera.gd` | B&W-style camera: grab-and-drag the city, orbit, zoom to cursor, fly-to, fade buildings that block the view. |
| `Surroundings` | `world/surroundings.gd` (+ `world/outskirts.gd`) | Scenery past the map, built once: land and hills (with a height-map collision floor), the river, promenade and bridges, the map's streets running on into it, outer neighbourhoods and woods, clouds, and the depth haze that hides the edge. |
| `Population` | `people/population.gd` | Every person is a `Resident` record (name, `ResidentArchetype`, rank, home, work, family, friends, traits, assets, needs); `census.gd` (`Census`) builds them, at least `min_residents_per_home` (1) and a family of up to 3 per building, about 600 in all (each record stands for a group of like people), each with an archetype picked by the kind of district they live in (`Districts.kind_at`, `data/archetypes.tres`). About one in `residents_per_body` (at least one per lived-in home) has a `Citizen` body at a time; the rest are indoors and swap with housemates out of view (`street.gd`, `Street`). Ranks (`Resident.Rank`): resident, believer, missionary, priest, special agent (the Vandalist in the Slums, trained at a core you hold), high priest; `convert_to` changes one and emits `rank_changed`. The cult starts with the high priest alone in the start district's core building (`found_cult`). `preaching` (`people/preaching.gd`, `Preaching`, a child): missionaries and the high priest try once per `attempt_interval` on a non-believer near them, `chance` is the GDD formula times sermon-house upgrades and miracle proof; miracles never convert. `staffing` (`people/staffing.gd`, `Staffing`): posts (PRAY, PRIEST, SHOP) and training (TRAIN: believer to missionary, missionary to priest at the high priest's house, up to `max_priests`); `staffed`, `is_staffed`, `fighters_of`, `buy_price_factor`. `upgrades` (`people/building_upgrades.gd`, `BuildingUpgrades`): purchases per building (`Kind`, rising `cost`, `upgraded`). Each believer makes money (`tithes`) by wealth and, in a staffed sermon house (group `prayer_houses`), belief (`prayer`) by faith, both times `Needs.multiplier` (`people/needs.gd`); one whose livelihood is unmet may leave. There is no cap on believers. Preachers stop now and then for sermons (`people/sermons.gd`, `Population.sermons`): a crowd gathers, attempts come faster, a hidden chance of a police raid. Fear and comfort (`scare`, `add_comfort`): too much fear moves people out. Believers the hand sets down on or at a building sit in there; `power_presence(building)` and `believer_share(building)` feed who holds it; `evacuate`, `evict` change who lives where. `crowd.gd` (`Crowd`) draws every body in one MultiMesh. Still about 600 lines: the sit-ins and comfort/fear are the next pieces to split out. |
| `Heat` | `heat.gd` | The police's hidden criteria: per-building heat from sit-ins, crowds and broken building rules (`raise`), decaying; `police_called(building, reason)` past a threshold scaled by district hardness (`set_hardness`). Tunables: `data/heat.tres`. |
| `Faith` | `faith.gd` | Belief pool, believers, exposure. Miracles `report()` here; a few times a second witnesses with line of sight react once per event. |
| `GodHand` | `god_hand.gd` (+ `hand_visual.gd`, `gesture.gd`) | The interface: pick up, throw, tap, knock, right-button gestures. Emits signals (`long_pressed`, `tool_clicked`, `circle_drawn`, ...) for the tools. |
| `Miracles` | `miracles.gd` | Casts the miracles (water, fire, roaches, money, block party, rain of frogs): spends belief and reports to `Faith`. A burnt-out, roach- or frog-infested building is emptied (`Population.evacuate`) and announced with `building_abandoned`; a fire put out in time is `building_saved`. Effects: `rain.gd`, `fire.gd`, `roaches.gd`, `money_rain.gd`, `block_party.gd`, `frog_rain.gd`. |
| `ConversionNotes` | `conversion_notes.gd` (+ `floating_note.gd`) | Floats "+ Believer" / "+ Missionary" / "Lost a believer" (rank names from `data/units.tres`) over people from `Population.rank_changed`; `FloatingNote.pop` is the shared pop-up text |
| `Decrees` | `decrees.gd` (+ `decree_looks.gd`) | Divine decrees on the god's own buildings (`Districts.owns()`): add floors, luxury, facade, change use, preserve; paid in belief and `Treasury` money. Preserved buildings are in group `preserved`. |
| `SermonAlerts` | `sermon_alerts.gd` | A ring on the ground and a click-to-fly button for each sermon and police raid (`Population.sermons` signals). |
| `BuildingMenus` | `building_menus.gd` | The second wheels of a building of yours: upgrades (paid from `Treasury`, applied with `Population.upgrade`), posts for free believers and priests in sermon houses and shops, and training missionaries and priests. |
| `HandTools` | `hand_tools.gd` (+ `radial_wheel.gd`) | The two wheels opened by holding the button still: decrees on your building, the three `Campaigns` takeover marks on anyone else's, miracles elsewhere. A chosen miracle sits in the hand until cast. |
| `Districts` | `world/districts.gd` (+ `district_view.gd`, `district_hud.gd`) | Knows the stage map's districts (`CityPlan.districts`, each of a kind, `DistrictSettings.kinds`: Slums, Workers, ..., that says who lives there; the Slums stage has one) and keeps who holds every building (index = map building index): yours once most of its residents believe (an empty one, while a believer sits in or lives there). Eilam's rule: buildings are taken one at a time, and a block (a map unit: `block_of`, `block_members`, `block_held`, `block_size`) whose standing buildings are all yours is complete (`is_block_complete`, `in_complete_block`, signal `block_changed`): its people make `block_output_bonus` more (`block_bonus`, used by `Population.money_rate` / `belief_rate`), its buildings can't give way (`Fragility`) or draw complaints (`Condemnation`), and awareness drops once. The cult's base (`headquarters`, `is_base`) is the largest building of the start district's block farthest from its core, always yours; the core (the largest building of the unit the map marks) has to be won; only the start district is open (`is_unlocked`, `is_open`). A district is yours (`district_controlled`) once its core and `control_share` (60%) of its buildings are. A building can only become yours if it borders one you hold (`can_claim`; `world/building_graph.gd`, `BuildingGraph.set_from_plan`: walls within `border_gap`, and blocks the map calls neighbours always join), so the city is taken outwards from the base; a core also needs `core_base_share` of the buildings around it. A per-district `independence` value waits for the story. `DistrictView` puts a gold plate on every roof of yours and a ring on the ground round each block (warming toward gold, solid once complete). Tunables `data/districts.tres`. |
| `DistrictWon` | `world/district_won.gd` | The "district captured" screen with a line from the Secretary's minutes (texts in `data/districts.tres`). |
| `Treasury` | `world/treasury.gd` | The cult's money: tithes from believers, and each building of yours earns or costs money by its decrees (`net_of`, `net_if`: rent, use upkeep, shop, luxury speed, floor efficiency) and its district's wealth; `spend_money` / `add_money`. Tunables `data/treasury.tres`. |
| `Campaigns` | `world/campaigns.gd` (+ `campaign_marks.gd`) | The three takeover marks on a building (force, buy, missionaries), carried out by believers until most residents believe. Tunables `data/campaigns.tres`. |
| `Government` | `government/government.gd` (+ `bulldozer.gd`, `demolition_notice.gd`) | City Hall: a hidden building code (floors past the limit, luxury, Combat Training) feeds `Heat` and slowly raises suspicion; at the limit an inspector visits, then a demolition notice and the bulldozer. Tunables `data/government.tres`. |
| `Police` | `government/police.gd` | Crews at marked buildings raise `Heat`; when `Heat.police_called` fires the street is closed with a roadblock and the campaign waits (`Campaigns.block`). Controlled districts are exempt; hardness follows district wealth. Tunables `data/police.tres`. |
| `Arrests` | `government/police_arrests.gd` (+ `police_officer.gd`, `arrest_alert.gd`) | A squad of grabbable officers surrounds the Vandalist (called by `Murals`) and holds him still; that makes him a martyr (`Awareness.add_martyr`). The hand or a miracle (`scatter_near`) clears them for belief, or he is taken to jail (`jailed`, `Resident.jailed_left`) until `bail()` or time served. `arrest_started` / `arrest_ended` / `released`; a banner shows the countdown and the bail button. |
| `Awareness` | `world/awareness.gd` | Per-district awareness 0..1 from how concentrated the preaching attempts are, fading faster with a joined-up front; `factor_for(home)` scales conversion (with the core spike, core protection and martyr bonus). Tunables `data/awareness.tres` (`AwarenessSettings`, also for the next three). |
| `Landmarks` | `world/landmarks.gd` | The five landmarks of the start district on a ring around its core (`buildings`, signs); `mark`, `clean` (City Hall scrubs old marks), `core_ease(d)` which `Awareness.factor_for` applies at a core. Tunables `data/landmarks.tres` (`LandmarkSettings`). |
| `StageScreens` | `world/stage_screens.gd` | The Slums stage's briefing (pauses the tree; skipped headless or with `--no-briefing`) and the lose screen (had `lose_after_believers`, then none for `lose_minutes`). Texts in `data/districts.tres`. |
| `Fragility` | `world/fragility.gd` | Exposed buildings of yours (at most one of yours next to them) may be lost (`crumble`: `Population.revert_believers`, `Districts.lose`). |
| `Murals` | `world/murals.gd` | The Vandalist set down by a building (`Population.agent_set_down`) paints a mural; murals feed `Population.pleasure_bonus` and awareness; the neighbourhood's answer (painted over, fine, camera; weights grow with use) may call `Arrests.arrest`. |
| `Condemnation` | `government/condemnation.gd` (+ `condemnation_notice.gd`) | Complaints from loud buildings of yours raise awareness; at `condemn_at` a notice, then `Population.close_building` for `close_minutes` and `reopen_building`. The hand can tear the notice off for belief. Replaces the inspector in `GovernmentSettings.condemn_kinds` (the Slums). |
| `ResidentCard` | `people/resident_card.gd` | Debug (B): hover a person to see who they are and lines to family, friends, home, work. |
| `DebugPanel` | `debug_panel.gd` | Testing shortcuts, hidden until F1. Not part of the game. |
| `HUD` | `hud.gd` (+ `help_label.gd`) | The numbers the player may see, and the controls folded into one hint line (H opens them). |

World objects, each self-contained and built in code: `citizen.gd`, `taxi.gd`, `swaying_tree.gd`,
`door.gd`, `litter.gd`, `pigeon.gd`.
`building_visual.gd` merges Kenney facade modules into one mesh per building.
`building_box.gd` (`BuildingBox.size_of`) reads a building's box from its collision shape.
`shared_meshes.gd` (`SharedMeshes`) hands out low-poly primitive meshes shared by every instance.
`sfx.gd` makes placeholder sounds in code.

Groups used for lookups: `citizens`, `buildings`, `fires`, `doors`, `god_grabbable`, `shops`,
`prayer_houses`, `wind_reactive`, `no_toon`, `preserved`.

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

### Stage maps (`tools/maplab/`, `data/maps/<stage>/`)

Each stage's city is a map made with the browser Map Lab (https://claude.ai/artifact/3Y7T4pbrZucKNvQnHiFbuC).
`tools/maplab/generator.js` is that page's generator (no view), with one change: a city hall only
where there is a civic district. `node tools/maplab/export_map.js data/maps/slums/stage.json`
writes `data/maps/slums/map.json`, which the game loads (`CityPlan`). The stage file holds the
Map Lab settings (a map code from the page, `code`, and/or `params`), the scale (real metres to
game metres, 0.5; floors stay full height), the names of the districts, which game district kind
each Map Lab archetype becomes, and the unit rules (`unit_max`, `unit_min` buildings, `unit_gap`
real metres for neighbours across a street). Each district kind can have a style file,
`data/maps/styles/<kind>.json` (street pattern, land use, building mix, height, ART.md facade style
per building kind), applied before the map is made. Units are the game's blocks (buildings are taken one at a time; a whole block pays a
bonus): a block or a run of one, 5 to 12 buildings; each district's core is its own unit (the public building nearest
its middle). The exporter prints the start district's unit count and how far its farthest unit
is from the core, for the Balance Tester. `json` files are in the web export
(`include_filter` in `export_presets.cfg`).

### Map generator (`scripts/mapgen/`)

Makes the layout of a city, with no nodes: `MapGenerator.generate(spec, settings)` turns a
`MapSpec` (seed, streets, plazas, park, district grid, optional fixed archetypes) into a
`MapLayout` (road lines, block kinds, skyline, district per block, an `Archetype` per district,
the start district). Deterministic by seed, so the sandbox can roll fresh maps and levels can
be saved specs in `data/maps/`. `map_preview.gd` (`scenes/map_preview.tscn`) draws one. Archetypes
live in `data/mapgen.tres` (`MapGenSettings`); load it with `load()`, as its array is typed.
`organic_streets.gd` (`OrganicStreets`, with `tensor_field.gd` and `street_tracer.gd`) makes bending
streets from a direction field, as street lines only; the 3D city does not use it yet. A `StreetStyle`
(four of them in `data/mapgen.tres`, grouped from `tools/city_stats.csv` by `tools/cluster_city_styles.py`)
sets how grid-like or winding they are.
Test: `tests/mapgen_test.tscn`.

### Map lab (`scenes/map_lab.tscn`)

A 2D playground for the map generator. `LabMap.build(LabParams, MapLabSettings, MapGenSettings)`
makes districts with `MapGenerator`, streets with `StreetTracer` over a `DistrictField` (a
`TensorField` in which each district lays out its streets in the `StreetStyle` its archetype's
`LandUseMix` names), joins ends that stop short (`EndJoiner`), finds blocks by painting the streets
on a grid (`CityBlocks`) and gives each a `LandUse.Use` (`LandUsePlanner`). `map_lab.gd` draws it,
`LabPanel` is the menu (sliders listed as `LabSlider`s), `LabCamera` zooms and pans. Pure data up to
the view, so `tests/map_lab_test.tscn` checks the same maps. Tunables: `data/map_lab.tres`.

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
| `data/balance.tres` | `Balance` | miracle witnesses, exposure, starting belief |
| `data/miracles.tres` | `MiracleSettings` | miracle costs, reach and effects |
| `data/decrees.tres` | `DecreeSettings` | divine decree costs, exposure and limits |
| `data/people.tres` | `PeopleSettings` | residents, names, walking, comfort and fear, jobs and places, upgrades, sermons |
| `data/archetypes.tres` | `ArchetypeSettings` (+ `ResidentArchetype`s) | the eight archetypes: where they live, traits, assets, needs (levels), and what a level is worth |
| `data/units.tres` | `UnitSettings` | ranks (names, colours, charisma), the conversion formula, output per believer, needs, training |
| `data/heat.tres` | `HeatSettings` | when the police step in |
| `data/landmarks.tres` | `LandmarkSettings` | landmark names, ring, marks: time, cost, arrest chance, core multiplier, City Hall cleaning |
| `data/awareness.tres` | `AwarenessSettings` | district awareness, fragility, complaints and condemnation, murals and the neighbourhood's answers, arrest and martyr |
| `data/art_style.tres` | `ArtStyleSettings` | cel shading, depth of field, tilt-shift, colour grade |
| `data/planning.tres` | `PlanningSettings` | planning model |
| `data/surroundings.tres` | `SurroundingsSettings` | land, river, outer neighbourhoods, clouds, haze |
| `data/city_props.tres` | `CityPropsSettings` (+ `PropKind`s) | which Meshy props go where, how many, how bags squash, building-state and poor-district props, the taxi model |
| `data/districts.tres` | `DistrictSettings` | district kinds and their wealth, who holds a building, borders, the block bonus, block rings |
| `data/city.tres` | `CitySettings` | which stage map, floor height, glass kinds, street and ground colours, trees, taxis, litter, pigeons |
| `data/treasury.tres` | `TreasurySettings` | money: tithes, rent, use upkeep, shops, luxury, floors |
| `data/campaigns.tres` | `CampaignSettings` | takeover marks: crews, prices, sermons |
| `data/police.tres` | `PoliceSettings` | roadblocks: crew heat, force and exposure multipliers, closing time |
| `data/mapgen.tres` | `MapGenSettings` (+ `Archetype`s) | the neighbourhood kinds the map generator places |
| `data/map_lab.tres` | `MapLabSettings` (+ `LabParams`, `LabSlider`s, `LandUseMix`es) | map lab menu, land use per archetype, block finding, colours |

### Who owns what

The studio has three standing role threads. All code here belongs to the Programmer.

| Area | Files | Owner thread |
| --- | --- | --- |
| Design, balance, research | `docs/GDD.md` | "מעצב המשחק" (Game Designer) |
| All code, tests, builds, the `alpha` branch, the web export, `CLAUDE.md`, `CHANGELOG.md` | everything else | "המתכנת" (Programmer) |
| Look, 3D assets, shaders' art direction, UI art | `docs/ART.md`, `assets/` | "האמן" (Artist) |

The Programmer builds only what the Designer briefed or Eilam asked, and asks the Designer
when the design is unclear.

A session cannot message the other threads: the documents are the channel. Decisions by Eilam
go at the top of `docs/GDD.md` (section 0) and `docs/ART.md` the day they are made, with what
each thread owes; read both before starting work.

### Standing decisions (Eilam, 2026-11-12)

- The story is a god against the bureaucracy, not a cult taking over, and not a street-artist
  god. Two ways to resist: control (you write the rules anew: fast, focused, little spreading)
  and freedom (a real majority: slower, with time to invest in buildings and people). The game
  should feel considered, not a fast takeover; do not tune it to go faster.
- Chosen direction, not built yet (GDD section 0): a journey in one of two ways, sweeping
  believers along behind you (freedom) or taking things over yourself (control); the hand's two
  verbs are stamp (your own rules) and tear (no rules). No signatures or petition.
- `docs/GDD.md` is a copy of the Designer's page (the link is at its top). If Eilam says the
  design changed and the copy has not, read the page with the Artifact tool and sync the copy.
- Buildings are taken one at a time; a whole block pays a bonus.
- **Feature freeze**: no new systems and no other districts until the Slums' base loop is good.
  Fix, tune, simplify and make readable; judge balance with `tests/pace_sim`.
- No cap on believers by housing; no abandoned buildings at the start.
- Tell Eilam in a line what you are about to do before long work, and what happened after.

### The Alpha build

The Alpha is the build Eilam plays. It is the branch `alpha`. Eilam never opens the Godot
editor, so every Alpha must be playable in the browser.

- **Browser (the main way):** https://eilamshahaf-droid.github.io/balck-and-white-3/
  `.github/workflows/alpha-web.yml` builds the `alpha` branch but runs on every push to `main`
  (GitHub lets only the default branch deploy to Pages), so push `alpha` first, then `main`;
  it can also be started by hand from `main` (workflow_dispatch). It downloads Godot and
  its web templates, exports the `Web` preset (`export_presets.cfg`, no threads so GitHub
  Pages needs no special headers; the web always uses the Compatibility renderer) and
  publishes it on GitHub Pages. Check that the run is green after each Alpha push.
- **Download (fallback):** https://github.com/eilamshahaf-droid/balck-and-white-3/archive/refs/heads/alpha.zip
  always gives the branch's newest commit. Also keep `/mnt/project-files/builds/alpha.zip`
  in step with it.

To refresh the Alpha: bump the version (see Versions), merge the work into `alpha` and push
it, then push `main`, tag, check the workflow run, then open the page and play a minute. To test a web build
before pushing, export it locally with
`godot --headless --path . --export-release Web build/web/index.html` (needs the
`web_nothreads_release.zip` template under `~/.local/share/godot/export_templates/<version>/`),
serve `build/web/` with `python3 -m http.server` and open it in Chromium.

Text resources stay text in the export (`editor/export/convert_text_resources_to_binary=false`
in `project.godot`): converting a `.tres` whose typed array holds a custom class drops the
properties after that array (the residents lost their names and the web build crashed).

Do not rename or delete the `alpha` branch, or the links break.

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
- Don't index an array or call a method on a property of a `const` preloaded settings
  resource (`U.rank_titles[i]`, `S.kinds.size()`) when the `.tres` doesn't store it: in the
  editor the parser folds it to null and the script fails to load there (the game still
  runs, so only `--import` shows it). Give the settings class an accessor
  (`U.title(i)`) instead.
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

### Versions

The build is "<stage> <major.minor.patch>", set in `project.godot` (`config/release_stage`,
`config/version`) and shown in the HUD corner and the window title. Bump the minor for a new
feature round and the patch for a fix-only build; tag the commit `vX.Y.Z`; head the CHANGELOG
section of the release with the version. Stages in order: Pre-Alpha, Alpha, Beta.

### Before pushing

1. `git pull` right before you push; message the owning thread before changing its files.
2. Run the project headless with no errors and no warnings:
   `godot --headless --path . --debug --quit-after 600` and the same for
   `res://scenes/city_planning.tscn`. `--debug` makes Godot print the GDScript warnings
   (shadowed names, integer division, ...) that Eilam sees in the editor; without it they
   stay silent. They print as `ERROR: '<warning text>'` with no file name, so if one shows
   up, load the scripts one by one to find it. Read the output, not only the exit code: a
   script that fails to compile still exits 0, and the hand test can still print PASS. After adding a `class_name`, run
   `godot --headless --path . --import` once so the class is registered.
3. Run the tests: `godot --headless --path . res://tests/hand_test.tscn` must print
   `HAND TEST: PASS` and `res://tests/cult_test.tscn` must print `CULT TEST: PASS` (exit
   code 0). Add a check there when you add a hand behaviour or change the core loop.
   After a balance change, run the bot and compare with the last CHANGELOG numbers:
   `godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,pray,preach,buy`.
4. Test the feature you changed. For visual changes, take a screenshot
   (`godot --path . -- --shot=out.png` saves one after 120 frames) and share it.
5. Check that both renderers still start (`--rendering-method gl_compatibility`); for an
   Alpha, also that the web export loads (see The Alpha build).
6. Add an entry to `CHANGELOG.md`: date, what changed, how to try it.
7. Update this file when the structure changes (new system, new scene, new owner).
