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
scripts/people/      residents: Population, Resident records, archetypes, staffing, building upgrades, debug card
scripts/props/       Meshy props: facade and roof dressing, sidewalk props, building-state props, their models
scripts/inspection/  the city's answer: Inspectors, the Inspector body, settings
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
| `Main` | `city.gd` (`City`; + `world/city_plan.gd`, `world/plan_builder.gd`) | Builds the stage's map (`CityPlan.load_file(CitySettings.map_path)`, made in the Map Lab, see Stage maps): `PlanBuilder` lays the ground with its land colours, the streets as ribbons along their centre lines, every building turned to face its street (local -z), doors and trees; every building is its own node in group `buildings` (what the player takes, `City.building_nodes[i]`, index = map building index) with meta `block` (the map unit it stands in); `BuildingBox.building_of(collider)` turns a hit into a building. Taxis, litter, pigeons. The street graph people walk: `node_position`, `nearest_node`, `random_neighbor`, `walk_from`, `route(from, to)` (the shortest walk). Day/night (`set_daylight`). Tunables `data/city.tres`. |
| `CityProps` | `props/city_props.gd` (+ `street_prop.gd`, `prop_model.gd`, `prop_kind.gd`) | Dresses the built city with the Meshy models: air conditioners under windows and water tanks / cooling units on roofs (MultiMesh per kind and chunk of town; roof props follow new floors and hide under a penthouse), and sidewalk props the hand can pick up (`StreetProp`; trash bags squash under weight and on landing; dumpsters and bags in poor districts). Tunables `data/city_props.tres`. |
| `StateProps` | `props/state_props.gd` | Shows who holds a building with Meshy props on top of it, redressed on `Districts.building_changed` and on the floors decree: banner and roof flag (yours), laundry (poor districts). |
| `TypeMarkers` | `props/type_markers.gd` (+ `use_marker.gd`) | Shows a building's Change Use with a Meshy prop on its roof or by its front. Kept apart from `StateProps` so the source of a building's type can change. |
| `CoreMarkers` | `props/core_markers.gd` | Each district's core building (`Districts.core_of`) gets a portico in front and a signboard with the district's name on the roof; moves on `core_changed`. |
| `CameraRig` | `god_camera.gd` | B&W-style camera: grab-and-drag the city, orbit, zoom to cursor, fly-to, fade buildings that block the view. |
| `Surroundings` | `world/surroundings.gd` (+ `world/outskirts.gd`) | Scenery past the map, built once: land and hills (with a height-map collision floor), the river, promenade and bridges, the map's streets running on into it, outer neighbourhoods and woods, clouds, and the depth haze that hides the edge. |
| `Population` | `people/population.gd` | The people you can see. Every person is a `Resident` record (name, `ResidentArchetype`, rank, home, family, friends); `census.gd` (`Census`) builds them, a family of up to 3 per building, each with an archetype by the kind of district (`Districts.kind_at`, `data/archetypes.tres`); `add_household` adds one. About one in `residents_per_body` has a `Citizen` body at a time (`street.gd`, `Street`); `crowd.gd` (`Crowd`) draws every body in one MultiMesh. **Followers are not counted here** (see `Followers`): residents are the faces. Ranks that matter (`Resident.Rank`): the Secretary (`HIGH_PRIEST`, `priest`, found by `found_cult` at the Office), Reps (`MISSIONARY`) and the Fixer (`AGENT`); `convert_to` changes one and emits `rank_changed`. `start_training(rank, building)` picks someone (`recruit`) and `staffing` (`people/staffing.gd`, `Staffing`: `post`, `train`, `tick_training`, `training_for`) counts the training down, faster while the hand points at the Office. A Rep or the Secretary set down by the hand at a building that is not yours emits `canvasser_set_down` (`Campaigns` listens); nobody else takes orders. `make_manager(rep, building)` puts a Rep in as Manager; a lost building loses its Manager. Counts: `missionary_count`, `free_rep_count`, `reps_out` (Reps and trainees that are not Managers: what the cap limits), `agent_count`. |
| `Faith` | `faith.gd` (`Faith`) | The paperwork pool (`belief_pool`, the old name; fed by `Followers.paperwork_rate`, `spend`), and exposure. Miracles `report()` here; a few times a second witnesses with line of sight react once per event. |
| `GodHand` | `god_hand.gd` (+ `hand_visual.gd`, `gesture.gd`) | The interface: pick up, throw, tap, knock, right-button gestures. Emits signals (`long_pressed`, `tool_clicked`, `circle_drawn`, ...) for the tools. |
| `Miracles` | `miracles.gd` | Casts the miracles offered (`MiracleSettings.offered`: water, money, block party, rain of frogs): spends paperwork and reports to `Faith`; money goes to `Treasury.add_money` (which pays a loan off first). Effects: `rain.gd`, `money_rain.gd`, `block_party.gd`, `frog_rain.gd`. To be rebuilt as a small refilling stock. |
| `ConversionNotes` | `conversion_notes.gd` (+ `floating_note.gd`) | Floats "+ Rep" and the like over people from `Population.rank_changed`, and why a building can't be worked on (`Campaigns.mark_refused`); `FloatingNote.pop` is the shared pop-up text |
| `Decrees` | `decrees.gd` (`Decrees`, + `decree_looks.gd`) | The two decrees on a building of yours (`Districts.owns()`): `&"floors"` (more room for followers) and `&"use"` (opens a shop: meta `decree_use`, group `shops`); paid in paperwork and `Treasury` money; `issue`, `price`, `is_done`, signal `decree_issued`. |
| `BuildingMenus` | `building_menus.gd` (`BuildingMenus`) | What the wheel of a building of yours offers: `items(building, group)` and `choose(id, building)`. First wheel: Train Rep / Train Fixer (the Office), Upgrades, +Floors, Shop or Open a Shop, Loan (the Office); second wheels `&"upgrades"` and `&"shop"` (one seller more or fewer). Every slice says its price or why not (`why_not_train`). |
| `HandTools` | `hand_tools.gd` (`HandTools`, + `radial_wheel.gd`) | The wheels opened by holding the button still: `BuildingMenus` on your building, "Send a Rep" (`Campaigns.send`) on one in reach, miracles elsewhere. A chosen miracle sits in the hand until cast. |
| `Districts` | `world/districts.gd` (+ `district_view.gd`, `district_hud.gd`) | Knows the stage map's districts (`CityPlan.districts`, each of a kind, `DistrictSettings.kinds`: Slums, Workers, ..., that says who lives there; the Slums stage has one) and keeps who holds every building (index = map building index): yours while a Rep manages it (`take`, `lose`; the base always is), with a takeover meter per building (`meter_of`, `add_meter`, `wants_you` when full, `meter_changed`; a lost one keeps `lost_meter`). Eilam's rule: buildings are taken one at a time, and a block (a map unit: `block_of`, `block_members`, `block_held`, `block_size`) whose standing buildings are all yours is complete (`is_block_complete`, `in_complete_block`, signal `block_changed`): followers come to its buildings faster (`Followers.attraction_of`). The cult's base (`headquarters`, `is_base`) is the largest building of the start district's block farthest from its core, always yours; the core (the largest building of the unit the map marks) has to be won; only the start district is open (`is_unlocked`, `is_open`). A district is yours (`district_controlled`, set by `win(d)`) once `DistrictProgress` says its bar is full. A building can only become yours if it borders one you hold (`can_claim`; `world/building_graph.gd`, `BuildingGraph.set_from_plan`: walls within `border_gap`, and blocks the map calls neighbours always join), so the city is taken outwards from the base; a core also needs `core_base_share` of the buildings around it. Key buildings (`keys`, `is_key`, `key_name`; `_find_keys`: the core and the largest building of one block in `blocks_per_key`, spread out, never in the base's block) are where inspectors come from and can't be taken until round C. A per-district `independence` value waits for the story. `DistrictView` puts a gold plate on every roof of yours, a ring on the ground round each block (warming toward gold, solid once complete) and the takeover bar over each building. Tunables `data/districts.tres`. |
| `Followers` | `world/followers.gd` (`Followers`, + `people/building_upgrades.gd`) | The model's economy (GDD section 0 item 7). Followers are a number per building of yours: `room_of` (by size, so floors add room), `count_of` (starts at `start_share` of the room, grows by `attraction_of`), `total` is the one pool. Roles are slots filled by `_fill_roles` from the pool: clerks at the Office first (`clerk_slots`, `paperwork_rate`), then sellers one at a time to the shop where the next brings the most while worth the pay (`has_shop`, `shop_slots`, `sellers_in`, `next_seller_net`, `change_sellers` for the player's own number), giving `money_rate`. `take_one` removes a follower for training; `rep_cap`; `idle`. Buildings of yours pull up the meters of their neighbours inside a block (`_pull`). `upgrades` (`BuildingUpgrades`: `Kind` ATTRACTION, SECURITY, SHOP, DESKS, TRAINING; `level`, `cost`, `add`), `kinds_for(i)`. Signal `changed`. Tunables `data/followers.tres`. |
| `Inspectors` | `inspection/inspectors.gd` (`Inspectors`, + `inspector.gd`, `inspector_settings.gd`) | The city's answer (round B). Reps at work and buildings taken raise `Faith.exposure`; every so often (sooner and more at once with exposure, `allowed()`) an `Inspector` (a RigidBody the hand can lift and throw; he lies a moment, then walks on along `City.route`) leaves the nearest key building for a Rep's door, or past `audit_from` for a building of yours (not the Office, not in a complete block, least Security first). Arriving, he demands paperwork: `demand_cost()` from a Rep (else the Rep is sent home), `audit_cost(i)` for a building (else `Districts.lose`). He gives up after `patience_seconds`. `bury()` spends paperwork to lower exposure (dearer each time). `send_to(building, audit)` for tests. Signals `sent`, `papers_shown`, `rep_sent_home`, `audit_passed`, `turned_back`, `gave_up` (shown by `ConversionNotes`). Tunables `data/inspectors.tres`. |
| `KeyMarkers` | `props/key_markers.gd` | A signboard with its name on each key building (`Districts.keys`). Placeholder look. |
| `DistrictProgress` | `world/district_progress.gd` | One bar per open district; until round C it is `following(d)` (the share of buildings that are yours over `control_share`) plus `key_places(d)` (`core_points` once the core is yours); `value(d)`, signal `changed`; calls `Districts.win(d)` at 1. Shown by `district_hud.gd`. |
| `DistrictWon` | `world/district_won.gd` | The "district captured" screen with a line from the Secretary's minutes (texts in `data/districts.tres`). |
| `Treasury` | `world/treasury.gd` (`Treasury`) | The money: `income` is `Followers.money_rate`; `spend_money`, `add_money`, `can_afford`. One loan at a time (`borrow`, `owed`): paperwork for money now, paid back from a share of the takings or by `add_money`. Tunables `data/treasury.tres`, the loan in `data/followers.tres`. |
| `Campaigns` | `world/campaigns.gd` (`Campaigns`, + `campaign_marks.gd`) | Reps at work on buildings. `send(building)` sends the nearest free Rep (the Secretary when there is none); a Rep set down by the hand joins. Each tick the meter rises by the Reps at the door, the building's size (`seconds_for`) and the god's attention (`GodHand.pointed_part`); full, `_take` makes the building yours and the Rep its Manager (`taken`). `why_not`, `marked`, `clear`, `is_sent`. Tunables `data/campaigns.tres`. |
| `StageScreens` | `world/stage_screens.gd` | The Slums stage's briefing (pauses the tree; skipped headless or with `--no-briefing`). Texts in `data/districts.tres`. |
| `ResidentCard` | `people/resident_card.gd` | Debug (B): hover a person to see who they are and lines to family, friends, home, work. |
| `DebugPanel` | `debug_panel.gd` | Testing shortcuts, hidden until F1. Not part of the game. |
| `HUD` | `hud.gd` (+ `help_label.gd`, `mission_card.gd`, `world/building_tooltip.gd`) | The numbers the player may see (paperwork, money, followers with sellers and clerks, Reps free and out of the cap, buildings), the controls folded into one hint line (H opens them), `MissionCard`: the one thing to do next with a progress bar (texts in `data/districts.tres`, "Missions"), and the card over the building under the hand (followers of room, sellers, Manager, or what it takes to take it). |

World objects, each self-contained and built in code: `citizen.gd`, `taxi.gd`, `swaying_tree.gd`,
`door.gd`, `litter.gd`, `pigeon.gd`.
`building_visual.gd` merges Kenney facade modules into one mesh per building.
`building_box.gd` (`BuildingBox.size_of`) reads a building's box from its collision shape.
`shared_meshes.gd` (`SharedMeshes`) hands out low-poly primitive meshes shared by every instance.
`sfx.gd` makes placeholder sounds in code.

Groups used for lookups: `citizens`, `buildings`, `doors`, `god_grabbable`, `shops`,
`wind_reactive`, `no_toon`.

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
| `data/miracles.tres` | `MiracleSettings` | which miracles are offered, their costs, reach and effects |
| `data/decrees.tres` | `DecreeSettings` | the floors and shop decrees: costs and limits |
| `data/people.tres` | `PeopleSettings` | residents, names, walking, bodies on the street |
| `data/archetypes.tres` | `ArchetypeSettings` (+ `ResidentArchetype`s) | the eight archetypes: where they live, traits, assets, needs (levels), and what a level is worth |
| `data/units.tres` | `UnitSettings` | ranks (names, colours), training times |
| `data/art_style.tres` | `ArtStyleSettings` | cel shading, depth of field, tilt-shift, colour grade |
| `data/planning.tres` | `PlanningSettings` | planning model |
| `data/surroundings.tres` | `SurroundingsSettings` | land, river, outer neighbourhoods, clouds, haze |
| `data/city_props.tres` | `CityPropsSettings` (+ `PropKind`s) | which Meshy props go where, how many, how bags squash, building-state and poor-district props, the taxi model |
| `data/districts.tres` | `DistrictSettings` | district kinds and their wealth, borders, the lost meter, the bar, block rings, mission and briefing texts |
| `data/city.tres` | `CitySettings` | which stage map, floor height, glass kinds, street and ground colours, trees, taxis, litter, pigeons |
| `data/treasury.tres` | `TreasurySettings` | starting money, tick |
| `data/campaigns.tres` | `CampaignSettings` | a Rep's time per building and how size scales it |
| `data/inspectors.tres` | `InspectorSettings` | exposure from work and takings, how often and how many inspectors, the inspector's walk, patience and look, what he demands, burying the file, the notes |
| `data/followers.tres` | `FollowersSettings` | the economy: room, growth, attraction, seller and clerk slots and rates, the Rep cap, training costs, upgrade costs, the pull inside a block, the god's attention, the loan |
| `data/mapgen.tres` | `MapGenSettings` (+ `Archetype`s) | the neighbourhood kinds the map generator places |
| `data/map_lab.tres` | `MapLabSettings` (+ `LabParams`, `LabSlider`s, `LandUseMix`es) | map lab menu, land use per archetype, block finding, colours |

### Who owns what

The studio has four standing role threads. All code here belongs to the Programmer.

| Area | Files | Owner thread |
| --- | --- | --- |
| Design, research | `docs/GDD.md` | "מעצב המשחק" (Game Designer) |
| Balance: simulations before a system is coded, the numbers the Designer briefs | `tests/pace_sim.gd` findings, sim artifacts | "בודק איזון" (Balance Tester) |
| All code, tests, builds, the `alpha` branch, the web export, `CLAUDE.md`, `CHANGELOG.md` | everything else | "המתכנת" (Programmer) |
| Look, 3D assets, shaders' art direction, UI art | `docs/ART.md`, `assets/` | "האמן" (Artist) |

The Programmer builds only what the Designer briefed or Eilam asked, and asks the Designer
when the design is unclear.

Role threads in the project can message each other; a session outside the project cannot, so
for it the documents are the channel. Either way, decisions by Eilam
go at the top of `docs/GDD.md` (section 0) and `docs/ART.md` the day they are made, with what
each thread owes; read both before starting work.

### Standing decisions (Eilam, 2026-11-12)

- The story is a god against the bureaucracy, not a cult taking over, and not a street-artist
  god. Two ways to resist: control (you write the rules anew: fast, focused, little spreading)
  and freedom (a real majority: slower, with time to invest in buildings and people). The game
  should feel considered, not a fast takeover; do not tune it to go faster.
- Chosen direction, not built yet (GDD section 0): the god asked City Hall to be recognised and
  was refused (the background story, kept for its humour); from there a journey in one of two ways, sweeping
  believers along behind you (freedom) or taking things over yourself (control); the hand's two
  verbs are stamp (your own rules) and tear (no rules). No signatures or petition.
- `docs/GDD.md` is a copy of the Designer's page (the link is at its top). If Eilam says the
  design changed and the copy has not, read the page with the Artifact tool and sync the copy.
- **The model (2026-11-13, GDD section 0 item 7) is the game now**; anything older that
  disagrees is void. Followers are a number per building in one pool; roles (seller, clerk) are
  slots that fill themselves; a Rep (`MISSIONARY`, capped) fills a building's meter and stays as
  its Manager; money from shops, paperwork from clerks; the main Office is the heart; key
  buildings send inspectors and become offices; only Reps, the Fixer and the Secretary are
  lifted by the hand. Built in three rounds: A the economy, B the danger, C the goal. **Rounds A and B are built (0.15.0, 0.16.0)**; key buildings can't be taken and the district bar is a placeholder until round C. Old identifiers kept: `Faith.belief_pool` is the paperwork, `Campaigns` are Reps at work. `ResidentArchetype` still carries the old needs and traits data, unused: remove it when the residents are next touched.
- Buildings are taken one at a time; a whole block pays a bonus.
- The system has three layers (GDD section 13): a base that no stage changes, branches the player
  balances by style, and a stage profile of numbers. A later stage is harder by its numbers
  (residents, buildings, reactions), never by new rules; before a second stage, the per-stage
  numbers move into one profile per stage.
- Names on screen (the code keeps the old identifiers): `BELIEVER` is a Member, `MISSIONARY`
  a Rep (a Manager once in a building), `PRIEST` a Clerk, `HIGH_PRIEST` the Secretary, `AGENT`
  the Fixer, the cult is the Committee, a prayer house is a Branch (`data/units.tres`).
- The hand places people: where it sets someone down, and who they are, is what they do
  (`Population._on_set_down`, `_take_order`, `willingness`, `effort_of`, `Resident.strain`); an
  unwilling one still goes, at a price. Prefer this to adding wheel slices.
- A district is won by filling one bar from two sources, a wide following that lives well and
  focused actions on key places; either alone must stay hard and the mix flexible.
- **Feature freeze**: no new systems and no other districts until the Slums' base loop is good.
  Fix, tune, simplify and make readable; judge balance with `tests/pace_sim`.
- No cap on believers by housing. No abandoned or empty buildings: every building has residents
  and is won by winning them; an empty building of yours (a shop, a branch) stays yours.
- Nobody is converted on the street: only at a door the player chose, or slowly by the
  neighbours inside a block. The Office (the base) is the strongest building.
- Decided, not built: Paperwork replaces belief; miracles come from a small refilling stock,
  never touch buildings, the bar or notices, and City Hall fines each one (GDD section 0).
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
   `godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,send,shop,upgrade,bury`.
4. Test the feature you changed. For visual changes, take a screenshot
   (`godot --path . -- --shot=out.png` saves one after 120 frames) and share it.
5. Check that both renderers still start (`--rendering-method gl_compatibility`); for an
   Alpha, also that the web export loads (see The Alpha build).
6. Add an entry to `CHANGELOG.md`: date, what changed, how to try it.
7. Update this file when the structure changes (new system, new scene, new owner).
