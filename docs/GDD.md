# Spin Cycle: Game Design Document

Source text of the designed version (https://claude.ai/artifact/3SbaznH5KKjxk2jop61iBf). Owned by the Game Designer thread; Eilam (Creative Director) gives direction and the designer merges it here. Last rewrite: 2026-11-11.

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
3. Believers earn money and belief by their wealth and faith assets, multiplied by how well the four needs are met. Belief is produced in staffed sermon houses (an empty house makes none). Believers are capped by housing.
4. Spend: money and belief on buildings, upgrades, decrees (floors, luxury, facade, change use, preserve) and miracles; mission coins on buildings, miracles and upgrades.
5. Train believers into missionaries and priests (limited number of priests), and agents where the district has the special building.
6. Police react to visible activity (crowds, sermons, rule-breaking) by closing streets. City Hall watches rule-breaking (floors over the limit, luxury, combat training) and escalates: inspector, notice, bulldozer.
7. A building is yours when most of its residents believe. A district is yours when its core building and most of its buildings are (starting threshold 60%, a tunable). The next district then opens.
8. Final stage: take City Hall with a majority of special agents inside, plus believers, money and belief.

Further rules: belief drifts back to a baseline; each visible person stands for a group of similar people; residents commute between home and work; captured workplaces become shops, seminaries or combat sites; poor districts are cheap to take and every later one costs more; police close streets and never demolish.

## 7. Starting numbers (balance simulator)

- Max priests 12; stage clock about 300 minutes; police raid threshold 120 heat; City Hall: 6 agents (30% of its staff), academy cost 100, agent cost 150. A skilled player wins in 3.5 to 4.8 hours; a sloppy one fails within the limit.
- Heat and price growth steer the pace (+15% cost cliff).
- The hard part of the last stage is taking the houses around City Hall, not money or conversions.

These live in `data/*.tres`.

## 8. Left out

Good/evil meter, three worlds, end-of-world backstory, the creature, lifting trees, plague and bedbugs, conversion by miracle.
