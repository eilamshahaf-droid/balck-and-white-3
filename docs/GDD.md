# Spin Cycle: Game Design Document

Source text of the designed version (https://claude.ai/artifact/3SbaznH5KKjxk2jop61iBf). Owned by the Game Designer thread; Eilam (Creative Director) gives direction and the designer merges it here. Last rewrite: 2026-11-11.

## 0. Decisions by Eilam, 2026-11-12 (read first)

These override anything below that disagrees; the Designer folds them into the sections.

1. **The story is a god against the bureaucracy.** Not "a cult takes over a city". The enemy is City Hall and the status quo (the landlord, the inspector, the notice board, the police booth, the post office). The art direction "grey to colour: freedom" (ART.md) is the same story. Everything that reads as a cult exploiting people (tithes, luxury, buying residents out, taking by force, the gold branding) is to be re-themed or cut by the Designer; the code keeps the mechanics until then.
2. **Buildings are taken one at a time; a whole block pays a bonus.** A building is yours when most of the people living in it are with you, and only if it borders a building of yours. A block (5 to 12 buildings, the ring on the ground) whose buildings are all yours is safe (no giving way, no complaints), its people make 25% more, and the district calms a little. Built in 0.10.0.
3. **Feature freeze.** No new systems and no other districts until the Slums' base loop is good. The first target is ten good opening minutes, not a 3 to 4 hour stage.
4. **No cap on believers by housing.** It made no sense to the player. Removed in 0.10.0.
5. **No abandoned buildings at the start.** A third of the Slums stood empty and could only be taken by moving a believer in; Eilam disliked it and the test bot showed it walling the cult in. A building is still abandoned when a fire or roaches empty it. Off since 0.10.0 (`abandoned_start` in `data/districts.tres`).
6. **Open: what the divine hand is for.** Today the loop runs by itself and the hand mostly opens wheels. The Designer owes a proposal for the hand's verbs in the core loop (see section 9).

Working title: "Spin Cycle". Platform: PC, Godot 4, 3D toy/dollhouse look, tilt-shift, saturated colours, no outlines. The god's hand is a white cloth glove and is the whole interface.

---

## 1. Pitch

A chaotic, humorous god game. You are the god of a small, hunted cult. Your goal is to help it take over a city: win over its people, and turn it into a city living under your grace, using missions and supernatural powers. Full comedy, no good or evil meter. The cult's Secretary narrates in deadpan meeting-minutes style. Cult names, ranks and paperwork are original satire, never real organisations.

## 2. Structure

- One city made of districts, built from public, workplace, residential, faith, empty-lot and abandoned buildings.
- Seven districts = seven stages, played in this order of difficulty. Each takes roughly 3 to 4 hours. The final goal is to capture City Hall.
  1. Slums
  2. Workers
  3. Students (university)
  4. Gentrification
  5. Tourism and nightlife
  6. Financial
  7. Old civic district (City Hall)
- Every stage starts from one multipurpose building (faith, money, housing) that is the stage's **core**. From it the player sends out converts, changes the district and builds a strategy to rule it.
- Resources: money, belief (faith), believers, priests, special-ability people, and special coins earned from missions that buy buildings, miracles and upgrades.
- Pacing is minutes to hours, never seconds.
- Rivals: rival cult, police, media, City Hall.

## 3. Residents: 8 archetypes

Homeless, blue collar, student, pensioner, clubber, pink collar, white collar, bohemian.

### 3.1 Where each archetype lives (X = exists)

| | Slums | Workers | Students | Gentrif. | Nightlife | Financial | Old civic |
|---|---|---|---|---|---|---|---|
| Homeless | X | | | | | | |
| Blue collar | X | X | | | | | |
| Student | | | X | X | | | |
| Bohemian | | | | X | X | | |
| Clubber | | | | | X | | |
| Pink collar | | | | | X | X | |
| White collar | | | | | | X | X |
| Pensioner | | | | | | X | X |

Stage 1 contains only homeless and blue collar; every later stage introduces new people and drops others.

### 3.2 Character traits (fixed coefficients; H/M/L)

| | Homeless | Blue | Student | Bohemian | Pink | Clubber | Pensioner | White |
|---|---|---|---|---|---|---|---|---|
| Anxiety: lowers influence received from others | L | L | L | M | L | M | M | H |
| Sociability: raises influence on others | H | H | H | M | M | L | L | L |
| Curiosity: raises conversion chance | H | M | M | M | L | L | L | L |
| Skepticism: lowers loyalty to the cult | L | M | H | M | M | M | H | H |

### 3.3 Asset meters (fixed; H/M/L)

Wealth = money a person makes without working. Connections = how many people they can be in touch with. Faith = how much belief they can produce.

| | Homeless | Blue | Student | Bohemian | Pink | Clubber | Pensioner | White |
|---|---|---|---|---|---|---|---|---|
| Wealth | L | L | L | M | M | M | H | H |
| Connections | H | H | H | M | M | M | M | L |
| Faith | H | M | L | H | M | L | L | L |

The poor are cheap to convert and generate belief; the rich generate money but resist.

## 4. Believer needs

Each believer has four needs. Meeting them gives bonuses, failing gives penalties.

- **Livelihood**: keeps the believer in the cult.
- **Security**: sets how long police influence lasts.
- **Pleasure**: sets how readily the believer answers a call to action.
- **Meaning**: sets the believer's productivity.

Influence = how strongly the need affects them. Desire = how much they want it. H/M/L.

| Need | | Homeless | Blue | Student | Bohemian | Pink | Clubber | Pensioner | White |
|---|---|---|---|---|---|---|---|---|---|
| Livelihood | influence | H | H | H | M | M | M | L | L |
| | desire | L | M | M | M | M | H | H | H |
| Security | influence | n/a | M | M | M | L | L | L | L |
| | desire | L | L | L | M | M | M | M | H |
| Pleasure | influence | H | M | M | M | M | M | M | L |
| | desire | L | M | M | M | M | M | H | H |
| Meaning | influence | H | H | M | M | M | L | L | L |
| | desire | L | L | M | M | M | H | H | H |

## 5. Player units

| Unit | Role |
|---|---|
| Believer | Most basic. Produces money and belief. |
| Missionary | Trained. Converts people. |
| Priest | Trained. Works in a sermon house, trains missionaries, essential for producing belief. |
| Special agent | Trained for a special mission; takes over public buildings. Training building changes from district to district. |
| High priest | The starting character. Works as missionary and priest. Exactly one exists. |

Training flow: resident -> (converted by a missionary or the high priest) believer -> (sermon house) missionary -> (sermon house, by the high priest) priest. Special agent branches from a believer through special training in a building that depends on the district.

Extra unit meters: **Education** (a need whose fulfilment shortens or lengthens upgrade time), **Charisma** (scales the unit's special actions), **Experience** (a saved-up currency spent on upgrading the unit).

(n/e = does not apply; same = no change from the believer)

| Needs: how much | Believer | Missionary | Priest | Agent | High priest |
|---|---|---|---|---|---|
| Livelihood | same | L | M | H | L |
| Security | same | M | H | H | L |
| Pleasure | same | M | M | H | L |
| Meaning | same | M | M | H | L |
| Education | n/e | M | H | H | L |

| Needs: influence strength | Believer | Missionary | Priest | Agent | High priest |
|---|---|---|---|---|---|
| Livelihood | same | same | same | same | H |
| Security | same | same | same | same | H |
| Pleasure | same | L | L | L | H |
| Meaning | same | L | L | same | H |
| Education | n/e | L | L | M | H |

| Assets | Believer | Missionary | Priest | Agent | High priest |
|---|---|---|---|---|---|
| Wealth | same | n/e | n/e | n/e | H |
| Connections | same | n/e | n/e | n/e | n/e |
| Faith | same | M | H | n/e | H |
| Experience | n/e | L | L | L | L |

| Traits | Believer | Missionary | Priest | Agent | High priest |
|---|---|---|---|---|---|
| Anxiety | same | n/e | n/e | n/e | n/e |
| Sociability | same | L | L | L | H |
| Skepticism | n/e | n/e | n/e | n/e | n/e |
| Curiosity | n/e | n/e | n/e | n/e | n/e |
| Charisma | n/e | L | L | L | H |

Converted followers no longer roll skepticism or curiosity.

## 6. Core loop

1. Hold the start building (core). Residents nearby are neutral.
2. A missionary or the high priest talks to residents. Chance to convert = base x curiosity x (1 - skepticism), scaled by the target's anxiety and the preacher's charisma and sociability. Only trained people convert; miracles never convert, they speed missionaries up and protect them.
3. Believers earn money and belief by their wealth and faith assets, multiplied by how well the four needs are met. Belief is produced in staffed sermon houses (an empty house makes none). There is no cap on believers.
4. Spend: money and belief on buildings, upgrades, decrees (floors, luxury, facade, change use, preserve) and miracles; mission coins on buildings, miracles and upgrades.
5. Train believers into missionaries and priests (limited number of priests), and agents where the district has the special building.
6. Police react to visible activity (crowds, sermons, rule-breaking) by closing streets. City Hall watches rule-breaking (floors over the limit, luxury, combat training) and escalates: inspector, notice, bulldozer.
7. A building is yours when most of its residents believe, and it borders a building of yours. A block whose buildings are all yours pays a bonus (section 0, decision 2). A district is yours when its core building and most of its buildings are (starting threshold 60%, a tunable). The next district then opens.
8. Final stage: take City Hall with a majority of special agents inside, plus believers, money and belief.

Further rules: belief drifts back to a baseline; each visible person stands for a group of similar people; residents commute between home and work; captured workplaces become shops, seminaries or combat sites; poor districts are cheap to take and every later one costs more; police close streets and never demolish.

## 7. Starting numbers (balance simulator)

- Max priests 12; stage clock about 300 minutes; police raid threshold 120 heat; City Hall: 6 agents (30% of its staff), academy cost 100, agent cost 150. A skilled player wins in 3.5 to 4.8 hours; a sloppy one fails within the limit.
- Heat and price growth steer the pace (+15% cost cliff).
- The hard part of the last stage is taking the houses around City Hall, not money or conversions.

These live in `data/*.tres`. The numbers in the game have drifted from this list (for example the police step in at 23 heat times the district's hardness, not 120); the game's files are the truth until the Balance Tester sets them again. To judge a change, run the bot: `godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,pray,preach`. With 0.10.0 it reaches about 150 of 417 buildings and 3 whole blocks in an hour, with no hand and no miracles.

## 8. Left out

Good/evil meter, three worlds, end-of-world backstory, the creature, lifting trees, plague and bedbugs, conversion by miracle.

## 9. The Slums as built (0.10.0), and what the Designer owes

Written by the Programmer on 2026-11-12 so this document matches the game again; the briefs for these lived in chat. The Designer keeps, changes or cuts each one.

Built and not described above:

- **Base and core.** The start building is the base, at the edge of the Slums. The core is a separate building in the middle that has to be won; its residents are 60 times harder to win.
- **Five landmarks of the status quo** on a ring around the core. The Vandalist marks them (4 minutes, $100, 10% chance of arrest); each standing mark makes the core 2.5 times easier. City Hall scrubs old marks.
- **Awareness** (hidden, 0 to 1 per district): working one building over and over raises it, a broad front lets it fade; it makes converting harder (down to x0.4). The first attempt on the core makes the district fully aware for 10 minutes.
- **Thin lines give way.** A building of yours with at most one of yours next to it can be lost (2% a minute times awareness plus heat). Not in a complete block.
- **Complaints and condemnation.** More than 2 believers in a building draw complaints; at 3 a notice goes up and the building closes for 5 minutes. The hand can tear the notice off.
- **The Vandalist and murals**, the neighbourhood's answers (painted over, fine, camera), arrest by a squad of officers the hand can throw off, martyr bonus, bail.
- **Takeover marks** on a building next to yours: sky sign (missionaries preach at its door), dollar (buy residents out), skull (force).
- **Win and lose.** Win: the core and 60% of the buildings. Lose: once you have had 8 believers, none for 3 minutes.

What the game needs from the Designer, in order:

1. **The hand's verbs in the loop** (decision 6). Suggestions from the Programmer, cheapest first: setting a missionary down at a building starts the sky sign there (no wheel); knocking on a door brings its residents out to be talked to; a miracle near a preacher is the main way to speed a street up, shown on screen. Today a miracle only adds hidden "proof".
2. **Re-theme for the story** (decision 1): what the resources, ranks, decrees and marks are called and mean when the enemy is the bureaucracy. Which of money, tithes, luxury, buy and force stay.
3. **The first ten minutes**, step by step: what the player does, sees and wins.
4. **Fewer hidden meters.** Awareness, heat, exposure, suspicion, fear, comfort and four needs all work unseen; the player only feels the game slow down. Each one kept needs a sign in the world.
5. **Money has no use** in the Slums (the bot ends an hour with $24,000). **Missions and mission coins**, the rival cult and the media are named above and not designed.
6. **Numbers** for the block bonus, residents per building (now 1 to 3), awareness and fragility (changed in 0.10.0, provisional).
