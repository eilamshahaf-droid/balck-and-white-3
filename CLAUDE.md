# CLAUDE.md

Guide for every Claude session that works on this repo. Read it before writing code.

## The project

**Godministration** (working title, Eilam 2026-11-15; was "Spin Cycle"): an original god game with city building, made in **Godot 4** (standard build, GDScript, no C#).
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
scenes/              title.tscn (the title screen, the main scene), main.tscn (the game), room_designer.tscn (furnishing the room kinds), city_planning.tscn (planning sandbox), map_lab.tscn (2D map generator playground)
scripts/             gameplay scripts for main.tscn
scripts/people/      residents: Population, Resident records, archetypes, staffing, debug card
scripts/props/       Meshy props: facade and roof dressing, sidewalk props, building-state props, their models
scripts/inspection/  the city's answer: Inspectors, the Inspector body, settings
scripts/rooms/       the rooms inside buildings: Rooms, layouts, room kinds, the editor
scripts/fixer/       the Fixer's actions at key buildings: settings, actions, one set per key building
scripts/roomdesign/  the room designer: format-1 room files, the furniture catalog, the 3D view
scripts/title/       the title screen and the player's settings
scripts/planning/    the city-planning sandbox (model, roads, terrain, visuals, UI)
scripts/maplab/      the map lab: districts' street styles, blocks, land use, menu
data/                every tunable number, as .tres resources (one per system); data/maps/ the stage maps
shaders/             toon (cel) shading, ghost fade, depth of field, tilt-shift + colour grade
assets/audio/kenney/ Kenney CC0 sounds (Interface Sounds, RPG Audio, Impact Sounds), with a licence note
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
| `Population` | `people/population.gd` | The people you can see. Every person is a `Resident` record (name, `ResidentArchetype`, rank, home, family, friends); `census.gd` (`Census`) builds them, a family of up to 3 per building, each with an archetype by the kind of district (`Districts.kind_at`, `data/archetypes.tres`); `add_household` adds one. About one in `residents_per_body` has a `Citizen` body at a time (`street.gd`, `Street`); `crowd.gd` (`Crowd`) draws every body in one MultiMesh. **Followers are not counted here** (see `Followers`): residents are the faces. Ranks that matter (`Resident.Rank`): the Secretary (`HIGH_PRIEST`, `priest`, found by `found_cult` at the Office, with `UnitSettings.start_reps` free Reps), Reps (`MISSIONARY`) and the Fixer (`AGENT`); `convert_to` changes one and emits `rank_changed`. `start_training(rank, building)` picks someone (`recruit`) and `staffing` (`people/staffing.gd`, `Staffing`: `post`, `train`, `tick_training`, `training_for`) counts the training down, faster while the hand points at the Office. A Rep set down by the hand at a building that is not yours emits `canvasser_set_down` (`Campaigns` listens), the Fixer `fixer_set_down` (`Breaches`); nobody else takes orders. `make_manager(rep, building)` puts a Rep in as Manager; a lost building loses its Manager. Counts: `missionary_count`, `free_rep_count`, `reps_out` (Reps and trainees that are not Managers: what the cap limits), `agent_count`. |
| `Faith` | `faith.gd` (`Faith`) | The paperwork pool (`belief_pool`, the old name; fed by `Followers.paperwork_rate`, `spend`), and exposure. Miracles `report()` here; a few times a second witnesses with line of sight react once per event. |
| `GodHand` | `god_hand.gd` (+ `hand_visual.gd`, `gesture.gd`) | The interface: pick up, throw, tap, knock, right-button gestures; a double click flies the camera, or on a building of yours emits `own_building_double_clicked` (`HandTools` opens its rooms). Emits signals (`long_pressed`, `tool_clicked`, `circle_drawn`, ...) for the tools. |
| `Miracles` | `miracles.gd` | Casts the miracles offered (`MiracleSettings.offered`: water, money, block party, rain of frogs): spends paperwork and reports to `Faith`; money goes to `Treasury.add_money` (which pays a loan off first). Effects: `rain.gd`, `money_rain.gd`, `block_party.gd`, `frog_rain.gd`. To be rebuilt as a small refilling stock. |
| `ConversionNotes` | `conversion_notes.gd` (+ `floating_note.gd`) | Floats "+ Rep" and the like over people from `Population.rank_changed`, and why a building can't be worked on (`Campaigns.mark_refused`); `FloatingNote.pop` is the shared pop-up text |
| `Decrees` | `decrees.gd` (`Decrees`, + `decree_looks.gd`) | The floors decree on a building of yours (`Districts.owns()`): more floors, so more rows for rooms; paid in paperwork and `Treasury` money; `issue`, `price`, `is_done`, signal `decree_issued`. `show_shop(building, on)` puts up or takes down the shop sign (meta `decree_use`, group `shops`) when `Rooms` says so. |
| `BuildingMenus` | `building_menus.gd` (`BuildingMenus`) | What the wheel of a building of yours offers: `items(building, group)` and `choose(id, building)`. First wheel: Train Rep / Train Fixer (the Office), Rooms (emits `rooms_requested`, which opens `RoomEditor`), +Floors, Sellers (a building with a shop), Loan and Bury the File (the Office); the second wheel `&"shop"` is one seller more or fewer. Every slice says its price or why not (`why_not_train`). |
| `HandTools` | `hand_tools.gd` (`HandTools`, + `radial_wheel.gd`) | The wheels opened by holding the button still: `BuildingMenus` on your building, "Send a Rep" (`Campaigns.send`) on one in reach, miracles elsewhere. A chosen miracle sits in the hand until cast. |
| `Districts` | `world/districts.gd` (+ `district_layout.gd`, `district_view.gd`, `district_hud.gd`) | Knows the stage map's districts (`CityPlan.districts`, each of a kind, `DistrictSettings.kinds`: Slums, Workers, ..., that says who lives there; the Slums stage has one) and keeps who holds every building (index = map building index): yours while a Rep manages it (`take`, `lose`; the base always is), with a takeover meter per building (`meter_of`, `add_meter`, `wants_you` when full, `meter_changed`; a lost one keeps `lost_meter`). Eilam's rule: buildings are taken one at a time, and a block (a map unit: `block_of`, `block_members`, `block_held`, `block_size`) whose standing buildings are all yours is complete (`is_block_complete`, `in_complete_block`, signal `block_changed`): followers come to its buildings faster (`Followers.growth_of`). The cult's base (`headquarters`, `is_base`) is the largest building of the start district's block farthest from its core, always yours; the core (the largest building of the unit the map marks) has to be won; only the start district is open (`is_unlocked`, `is_open`). A district is yours (`district_controlled`, set by `win(d)`) once `DistrictProgress` says its bar is full. A building can only become yours within the influence radius of one you hold (`can_claim`, `in_reach`, `yours_within`; `reach` borders, set by `Followers.reach()` from the followers; a key building must border one: `borders_yours`; `world/building_graph.gd`, `BuildingGraph.set_from_plan`: walls within `border_gap`, and blocks the map calls neighbours always join), so the city is taken outwards from the base. Where the core, the base and the key buildings stand is chosen once by `DistrictLayout` (`cores`, `pick_core`, `edge_building`, `keys`, `largest`; it reads only Districts' public answers). Key buildings (`keys`, `is_key`, `key_name`; `DistrictLayout.keys`: the core and the largest building of one block in `blocks_per_key`, today 1: every block but the base's; a block is complete without its key building) are where inspectors come from, and are locked to Reps until the Fixer opens them (`is_key_open`, `open_key`, `key_share(d)`; see `Breaches`). A per-district `independence` value waits for the story. `DistrictView` puts a gold plate on every roof of yours, a ring on the ground round each block (warming toward gold, solid once complete) and the takeover bar over each building. Tunables `data/districts.tres`. |
| `Followers` | `world/followers.gd` (`Followers`) | The model's economy (GDD section 3). Followers are a number per building of yours: `room_of` (from `Rooms`), `count_of` (starts at `start_share` of the room, grows by `growth_of`: faster in a complete block, `block_growth`; never over the room), `total` is the one pool. Roles are slots filled by `_fill_roles`; people work in the building they live in: clerks first (`clerks_in(i)`: desks, but no more than live there; `paperwork_rate`), then sellers (`sellers_possible(i)`: slots, but no more than live there after its clerks) one at a time to the shop where the next brings the most while worth the pay (`has_shop`, `shop_slots`, `sellers_in`, `next_seller_net`, `change_sellers` for the player's own number), giving `money_rate`. `take_one` removes a follower for training, `give_back` returns one; `reach()` (the influence radius, 1 + floor(sqrt(total / `reach_followers`)), pushed to `Districts.reach`); `desks_in`; `rep_cap`; `idle`; `security_of(i)`; `upkeep_rate(money)` (rooms in full; the buildings' share grows from 0 at $0 to all at `full_upkeep_at`); `people_in(d)`, `followers_in(d)`, `people_share(d)` (the district's people are your followers plus the plain room of every building not yours, so followers you make room for raise the total too); `paperwork_cap()` and `money_cap()` (what the archives and vaults hold; `Faith` and `Treasury` stop their income there). All slots, caps, attraction and security come from the rooms. Buildings of yours pull up the meters of their neighbours inside a block (`_pull`). Signal `changed`. Tunables `data/followers.tres`. |
| `Rooms` | `rooms/rooms.gd` (`Rooms`, + `building_layout.gd`, `room_kind.gd`, `room_settings.gd`) | The rooms inside every building of yours (GDD section 4). A `BuildingLayout` per building: a grid of bays (columns, by the front's width) and floors (rows, 0 the ground floor; the floors decree adds rows) and the `Piece`s on it (a `RoomKind` and an origin; rooms are never turned, Eilam 2026-11-16: each way round is a kind of its own sharing a `group`, e.g. `desks_mirrored` is a `&"desks"`), with a staircase nothing fits over: one place a floor (`stairs`, a column per row), climbing in flights of `stairs_flight` floors that change column (`_climb`; floors added later keep the stairs below). A cell with no piece is a plain flat, so a building works unplanned. A kind may need a neighbour (`RoomKind.needs_next`, by id or `group`: Archive by a Desk Room, Vault and Stock Room by a shop; `touches`, the stairs don't come between) and then that neighbour can't be taken out (`why_not_remove`, `leaning_on`). `offers(i, kind)`: office kinds in an office, homes up to the stage's `max_tier` (the Slums: basic only; `RoomKind.tier`). The Office is raised to `office_min_rows` floors at the start (`Decrees.raise_free`). `why_not`, `place` (pays `money_of(i, kind)` and `paperwork_of(i, kind)`: the kind's price raised `price_step` for each room already bought there, `bought_in(i)`, past the Office's first `office_steady_rooms`, kinds or groups in `price_step_exempt` never raised; emits `placed(index, kind)`, on which `Followers` brings half the people a home adds at once), `place_anywhere`, `remove` (part of what was paid back), `room_of(i)`, `totals_of(i)` (`Totals`: followers, clerks, sellers, reps, security, impression (on the buildings near it), paperwork_cap, money_cap), `count_in(i, kind or group)`, `homes_in(i)`, `is_office(i)` (the main Office and every key building you have taken: office-only kinds go there). Rooms with `upkeep` cost money a minute (`upkeep()`, taken by `Treasury`); when it can't be paid (`Treasury.ran_dry`) the dearest closes (`close_dearest`, `Piece.open`, signals `room_closed` / `room_reopened`) and gives nothing until there is `reopen_money` again. The Office opens with `office_start` (empty: the player plans it, the first lesson). A lost building loses its rooms. Signal `changed(index)`. `settings` is `data/rooms.tres` (`RoomSettings`, loaded with `load()`: twenty kinds as sub-resources). |
| `RoomEditor` | `rooms/room_editor.gd` (`RoomEditor`) | The editor's screen, drawn in code on one Control: the grid, a palette of kinds (its rows shrink to fit the screen), the ghost of the picked room (green or red with the reason), totals (with clerks and sellers short of homes). Left click picks and places, right click puts the room down, "Take a room out" removes, Esc closes. Does not pause the game. Placeholder look. |
| `Pause` | `pause.gd` (`Pause`) | The player's own pause (Space): pauses the tree but keeps `keep_awake` (camera, hand, wheels, editor, HUD) working; the hand lifts nothing meanwhile. Not available while the opening is up. |
| `Inspectors` | `inspection/inspectors.gd` (`Inspectors`, + `inspector.gd`, `inspector_settings.gd`) | The city's answer, on a timer (0.26.0): Reps at work and buildings taken raise `Faith.exposure`; at `first_seconds`, then every `interval_seconds` (`next_in`, shown on the HUD), `at_once()` inspectors (1 + floor(exposure x `per_exposure`)) leave the nearest key building, each for a building of yours (not the Office, least Security first). An `Inspector` is a RigidBody the hand can lift and throw (he lies a moment, shorter each throw, then walks on along `City.route`). Arriving he takes `demand_cost(i)` paperwork (15 + 1 per building held, divided by Security); short of it he takes what there is (`short_taken`) and comes back to the same building `return_seconds` later. He gives up after `patience_seconds`. `bury()` spends paperwork to lower exposure (dearer each time). `send_to(building)` for tests and for a loud action of the Fixer (`Breaches.loud`): with no papers at his door, `Breaches.caught`. Signals `sent`, `papers_shown`, `short_taken`, `fixer_caught`, `gave_up` (shown by `ConversionNotes`), and `thrown` (`MissionCard`). Tunables `data/inspectors.tres`. |
| `KeyMarkers` | `props/key_markers.gd` | A signboard with its name on each key building (`Districts.keys`). Placeholder look. |
| `Breaches` | `world/breaches.gd` (`Breaches`, + `props/breach_marks.gd`, `fixer/`) | The Fixer at a key building (round C). `send(building)` (or the hand setting the Fixer down there, `Population.fixer_set_down`) puts him at its door (`target`, `is_at`); there the building's wheel offers its own actions (`actions_at`, `FixerAction`s found by the key building's name in `data/fixer.tres`): `act(building, action)` costs paperwork, money and exposure, takes a while (`doing`, faster under the hand) and then fills part of the key building's bar (`bar_of`). Quiet and loud actions share their numbers by sort (`FixerSettings.paperwork(a)` and so on); a loud one emits `loud`, and `Inspectors` sends one to the door: with no papers the Fixer is sent back and the bar drops (`caught`). A Guard Room in any building of yours (`guarded()`, needs `rooms`) cuts his exposure (`exposure_of`, `guarded_exposure_share`) and what `caught` loses (`guarded_caught_loss`). From `gate_exposure` he starts nothing (`why_not_act`). While he is elsewhere a bar falls back `left_fade_per_minute`. A full bar: `Districts.open_key` lets a Rep take it, and taken it is an office (`Rooms.is_office`). `call_back`, `why_not`, `price_of`. Signals `action_started`, `loud`, `opened`, `changed`. `BreachMarks` writes the bar and the action over the building. `settings` is `data/fixer.tres` (loaded with `load()`). |
| `Impression` | `world/impression.gd` (`Impression`) | The gate on ordinary buildings (0.26.0): `of(i)` sums, over your buildings within `Districts.reach` (`yours_within`), `impression_per_building` plus their open rooms' `RoomKind.impression` (a home 1, a shop 2, the Laundry Room 5); `required(d)` = `impression_start` + `impression_step` x (ordinary buildings held - `impression_free`). `why_not(i)` ("impression 4 of 5: ...") is part of `Campaigns.why_not`; key buildings and the Office skip it (`applies`). Shown only on the card under the hand (`BuildingTooltip`). Tunables in `data/districts.tres` ("Impression"). |
| `UnitUpkeep` | `people/unit_upkeep.gd` (`UnitUpkeep`) | What the Committee's people cost in paperwork: `rate()` = `rep_upkeep` per Rep, a Manager `manager_upkeep_share` of it, `fixer_upkeep` for the Fixer, taken from `Faith` every second. With the pool at 0, every `revert_seconds` one Rep who isn't a Manager (a free one first), then the Fixer, goes back to being a follower (`Followers.give_back`, signal `reverted`). The HUD shows the paperwork rate net of it. Tunables in `data/followers.tres` ("Reps"). |
| `DistrictProgress` | `world/district_progress.gd` | One bar per open district, by the model's two ways to win: `control(d)` (`Districts.key_share(d)` over `key_win_share`) and `freedom(d)` (half for `key_part_share` of the key buildings, half for `Followers.people_share(d)` over `control_share`); `value(d)` is the better; signal `changed`; calls `Districts.win(d)` at 1. `district_hud.gd` shows both counts and the rule. |
| `DistrictWon` | `world/district_won.gd` | The "district captured" screen with a line from the Secretary's minutes (texts in `data/districts.tres`). |
| `Treasury` | `world/treasury.gd` (`Treasury`) | The money: `income` is `Followers.money_rate` less `Followers.upkeep_rate(money)` (rooms, and `building_upkeep` a minute for every building of yours, less in a complete block) (signal `ran_dry` when the upkeep can't be paid); `spend_money`, `add_money`, `can_afford`. One loan at a time (`borrow`, `owed`): paperwork for money now, paid back from a share of the takings or by `add_money`. Tunables `data/treasury.tres`, the loan in `data/followers.tres`. |
| `Campaigns` | `world/campaigns.gd` (`Campaigns`, + `campaign_marks.gd`) | Reps at work on buildings. `send(building)` sends the nearest free Rep (with none free the building waits, "needs a Rep"); a Rep set down by the hand joins, and such a door is dropped when the Rep leaves. Only Reps work on buildings: the Secretary stays at the Office. Each tick the meter rises by the Reps at the door, the building's size (`seconds_for`) and the god's attention (`GodHand.pointed_part`); full, `_take` makes the building yours and the Rep its Manager (`taken`). `why_not` (in reach, and impressed enough: `Impression`), `marked`, `clear`, `is_sent`. Tunables `data/campaigns.tres`. |
| `StageScreens` | `world/stage_screens.gd` | The opening scene: a few text panels (who speaks, what is seen, the line; `DistrictSettings.opening_*`, read through `opening_count`, `opening_speaker`, `opening_direction`, `opening_line`), Next and Skip, over the dimmed, paused world on its own high layer. First run only, remembered in `user://opening_seen`; skipped headless or with `--no-briefing`, shown again with `--briefing`. |
| `ResidentCard` | `people/resident_card.gd` | Debug (B): hover a person to see who they are and lines to family, friends, home, work. |
| `TrainingMarks` | `props/training_marks.gd` | The training meter over the Office (who, percent, seconds left) and a badge over every Rep and Fixer (`UnitSettings.badge`, "Training meter and badges"). |
| `SoundCues` | `sound_cues.gd` (`SoundCues`) | Plays what happened, from the systems' signals: rooms placed, closed and reopened; coins when `Treasury.money` jumps by `coins_min` or more at once; pages when paperwork is spent (not the Reps' upkeep); an inspector sent, stamping (`papers_shown`), short, thrown, giving up; a building taken, a Rep or the Fixer trained, a block complete, a key building opened, a district won, a mark refused. Keeps a low city hum looping (made in code, swelling slowly; not when headless) and makes every button click (`Sfx.watch_buttons`). Sound only. |
| `DebugPanel` | `debug_panel.gd` | Testing shortcuts and a per-minute log of money and paperwork in and out, hidden until F1. Not part of the game. |
| `HUD` | `hud.gd` (+ `help_label.gd`, `mission_card.gd`, `world/building_tooltip.gd`) | The numbers the player may see (paperwork, money, followers with sellers and clerks, Reps free and out of the cap, buildings), the controls folded into one hint line (H opens them), `MissionCard`: one step at a time with a progress bar, following what really happened and never repeating a done step (plan the Office's free room, send the Rep, take the first building, throw the inspector when one is out, train the Fixer, open a key building, then "Key buildings: 1 of 9"; texts in `data/districts.tres`, "Missions"), and the card over the building under the hand (followers of room, clerks and sellers and whether homes are short, Manager, or what it takes to take it: reach, impression). |

World objects, each self-contained and built in code: `citizen.gd`, `taxi.gd`, `swaying_tree.gd`,
`door.gd`, `litter.gd`, `pigeon.gd`.
`building_visual.gd` merges Kenney facade modules into one mesh per building.
`building_box.gd` (`BuildingBox.size_of`) reads a building's box from its collision shape.
`shared_meshes.gd` (`SharedMeshes`) hands out low-poly primitive meshes shared by every instance.
`sfx.gd` plays every sound: `play(tree, where, event)` in the world, `ui(tree, event)` on the screen; an event plays a random one of its files in `data/sounds.tres` (`SoundSettings`), or, with none set, the old sound made in code (surfaces, rain, fire, chimes). `watch_buttons(tree)` makes every button click; `ambience(seconds)` the city hum. The wheel (`HandTools`) and the room editor call it directly.

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
bonus): a block or a run of one, 8 to 14 buildings in the Slums (97 buildings, nine blocks and the core); each district's core is its own unit (the public building nearest
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

### Room designer (`scenes/room_designer.tscn`)

A tool scene for the Artist and Eilam, opened from the title screen ("Room Designer"); "Back
to title" returns. It furnishes each room kind (`data/rooms.tres`) at levels 1 to 3 with the
Kenney Furniture Kit (`assets/models/kenney_furniture/`, CC0, with the side-view icons the
Artist's browser editor used). `room_designer.gd` (`RoomDesigner`, a CanvasLayer above the art
style's screen layer) is the screen; `designer_preview.gd` the 3D view in its own world, always
editing: put a piece on a floor and drag it, with grid lines every `grid_step` on each floor.
How a piece is placed (`FurnitureCatalog.Place`, `place_of`): FLOOR pieces take whole grid squares
(their footprint, turned in quarter turns) on lit places of their row and never overlap
(`furniture_spots.gd`, `FurnitureSpots`: `squares`, `area`, `fits`, `move_to`, `settle`); WALL pieces
slide along the back wall (`hang`); SMALL things (the `small` name pattern, or no wider than
`small_max`) snap to `snap` anywhere and rest on surfaces. A model may have a sidecar
`<model>.place.json` beside its glb (`type` floor/small/wall, `scale`, `footprint` [x, z] metres,
`front` quarter turns, `wall_height`, `surface`, `slots`), which wins over the settings' lists.
Models are drawn their place's `scale` times (default `furniture_scale`: the Kenney pieces are
about half true size, and the room files store unscaled sizes); `furniture_catalog.gd` each model's scene (Kenney's in `model_folder`, the Artist's Blender pieces, `artist_models`, in `artist_folder`), icon, size from its meshes, groups, its `Place`, `new_item` and `rest_height` (stacking);
`room_design.gd` (`RoomDesign`, `Item`) the design and its file, format 1 as the Artist set it
(x per cell to the item's middle, y above that floor, z from the room's middle, back negative);
`design_store.gd` keeps every design in `user://room_designs.json` at once, starts from shipped
files in `data/rooms/designs/` (`room_<id>_L<level>.json`), and hands files out (a download in the
browser, `user://room_files/` on a PC) or reads one back (the page's file picker, or a
FileDialog). Not yet used by the game. Tunables `data/room_designer.tres`. Test:
`tests/room_designer_test.tscn`.

### Title screen (`scenes/title.tscn`, the main scene)

`title/title_screen.gd` (`TitleScreen`, a CanvasLayer) builds the menu in code: New Game
(`main.tscn`), Room Designer, Settings, Credits, Quit (not on the web), the version. Headless, or
with a `--shot` argument, it goes straight to the game, so the checks and screenshots run as
before. `title/player_settings.gd` (`PlayerSettings`) keeps volume, full screen and the art style
in `user://settings.cfg` and applies them at start (`ArtStyle.set_enabled`). Texts, colours and the
credit lines in `data/title.tres` (`TitleSettings`); add the CC-BY lines of `art/kits/CREDITS.md`
there when one of those models goes into the game.

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
| `data/decrees.tres` | `DecreeSettings` | the floors decree: costs and limits |
| `data/people.tres` | `PeopleSettings` | residents, names, walking, bodies on the street |
| `data/archetypes.tres` | `ArchetypeSettings` (+ `ResidentArchetype`s) | the eight archetypes: where they live, traits, assets, needs (levels), and what a level is worth |
| `data/units.tres` | `UnitSettings` | ranks (names, colours), training times |
| `data/art_style.tres` | `ArtStyleSettings` | cel shading, depth of field, tilt-shift, colour grade |
| `data/planning.tres` | `PlanningSettings` | planning model |
| `data/surroundings.tres` | `SurroundingsSettings` | land, river, outer neighbourhoods, clouds, haze |
| `data/city_props.tres` | `CityPropsSettings` (+ `PropKind`s) | which Meshy props go where, how many, how bags squash, building-state and poor-district props, the taxi model |
| `data/districts.tres` | `DistrictSettings` | district kinds and their wealth, borders, the lost meter, the two ways to win, impression (the gate), key buildings, block rings, mission texts, the opening scene |
| `data/fixer.tres` | `FixerSettings` (+ `FixerActionSet`s of `FixerAction`s) | the Fixer at key buildings: what quiet and loud actions cost and fill, the exposure gate, what an inspector at the door takes, each key building's own actions and jokes |
| `data/city.tres` | `CitySettings` | which stage map, floor height, glass kinds, street and ground colours, trees, taxis, litter, pigeons |
| `data/treasury.tres` | `TreasurySettings` | starting money, tick |
| `data/campaigns.tres` | `CampaignSettings` | a Rep's time per building and how size scales it |
| `data/inspectors.tres` | `InspectorSettings` | exposure from work and takings, the inspectors' timer and how many at once, coming back, the inspector's walk, patience and look, what he demands, burying the file, the notes |
| `data/followers.tres` | `FollowersSettings` | the economy: growth, seller and clerk rates, the base Rep cap, training costs, what Reps cost in paperwork a second, the influence radius, the pull inside a block, building upkeep, the god's attention, the loan |
| `data/rooms.tres` | `RoomSettings` (+ `RoomKind`s) | the room kinds (shape, price, upkeep, what each gives, where it fits, what it must be next to), the stairs, upkeep and reopening, the grid (bay width, floor height, limits), the stores with no room built, the refund, the Office's first rooms and its steady prices, the editor's look |
| `data/sounds.tres` | `SoundSettings` | which files each sound event plays, volumes, pitch spread, how far sounds carry, the city hum, when money clinks |
| `data/title.tres` | `TitleSettings` | title screen: subtitle, colours, sizes, credit lines |
| `data/room_designer.tres` | `RoomDesignerSettings` | room designer: furniture scale, snap and grid, small things, a place's size, the furniture list and groups, surfaces, wall heights, category colours |
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
go into the Designer's page (synced to `docs/GDD.md`) and `docs/ART.md` the day they are made, with what
each thread owes; read both before starting work.

### Standing decisions (Eilam; the full text is `docs/GDD.md`, synced from the Designer's page)

The Designer's page is the design; the GDD's last section says what is built. In short:

- **The story**: a god against the bureaucracy, a comedy, in two ways: control (take the offices
  over) and freedom (a real majority). Considered, not a fast takeover: do not tune it to go
  faster.
- **The model**: followers are a number per building in one pool; people work where they live
  (clerks make paperwork, sellers money); a Rep (capped) fills a building's bar and stays as
  its Manager; inspectors come from key buildings and are paid in paperwork or carried off by
  the hand; the Fixer opens a key building, which becomes an office; rooms are fitted into
  every building's grid and set room, slots, ceilings and upkeep. Win: 80% of the key buildings,
  or 30% of them and 60% of the district's people.
- **Buildings are taken one at a time**, only next to one you hold; a whole block pays a bonus.
  No empty or abandoned buildings, ever. Nobody is converted in the street.
- **The hand** lifts only Reps, the Fixer and inspectors; where it sets one down is what they
  do. Prefer that to adding wheel slices. Pause is the player's own; nothing pauses by itself.
- **It must work when ignored**: a building never opened in the room editor still works.
- **Only the Slums** until its loop is good, and it is the teaching stage: basic homes only.
  A later stage is harder by its numbers, never by new rules; before a second stage the
  per-stage numbers move into one profile.
- **Decided, not built** (GDD section 9; section 14 is what is built): the planner inside the
  building as a doll's house, advanced and luxury blocks, fear and attractiveness as two dials,
  outside decorations, divine powers paid in faith from a Shrine that City Hall fines (GDD
  section 6), stamp and tear.
- Names on screen (the code keeps the old identifiers): `BELIEVER` a Member, `MISSIONARY` a Rep,
  `PRIEST` a Clerk, `HIGH_PRIEST` the Secretary, `AGENT` the Fixer, the cult the Committee;
  `Faith.belief_pool` is the paperwork, `Campaigns` are Reps at work.
- Leftovers to clear when next touched: `ResidentArchetype` still carries the old needs and
  traits data, and `Miracles` still spends paperwork.
- `docs/GDD.md` is a copy of the Designer's page (the link is at its top) plus the Programmer's
  section on what is built. If Eilam
  says the design changed and the copy has not, read the page with the Artifact tool and sync.
- Tell Eilam in a line what you are about to do before long work, and what happened after. He
  wants to be shown, not told at length.

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
- **Windows (for the heavier art):** https://eilamshahaf-droid.github.io/balck-and-white-3/Godministration-windows.zip,
  built by the same workflow from the `Windows Desktop` preset (one .exe with the pack embedded,
  `application/modify_resources=false` so no rcedit is needed) and published next to the web build.
  To export it locally, put `windows_release_x86_64.exe` from the 4.4.1 templates beside the web template.
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
   `godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,send,shop,upgrade,bury,fixer`
   (add `hand` for the god's attention, `loan` to take the loan when the gate asks for it).
4. Test the feature you changed. For visual changes, take a screenshot
   (`godot --path . -- --shot=out.png` saves one after 120 frames) and share it.
5. Check that both renderers still start (`--rendering-method gl_compatibility`); for an
   Alpha, also that the web export loads (see The Alpha build).
6. Add an entry to `CHANGELOG.md`: date, what changed, how to try it.
7. Update this file when the structure changes (new system, new scene, new owner).
