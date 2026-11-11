# Spin Cycle: Game Design Document

Living document, owned by the Game Designer thread. Eilam (Creative Director) gives direction and raw notes; the designer merges them here. Last rewrite: 2026-11-11.

Legend: **[DECIDED]** is settled by Eilam (slides of 2026-11-11 win over older docs) or by an earlier approved round. **[OPEN]** still needs a decision. **[PROPOSED]** is the designer's default until Eilam says otherwise; the programmer may build it.

Working title: "Spin Cycle" (temporary). Platform: PC, Godot 4, 3D toy/dollhouse look, tilt-shift, saturated colours, no outlines. The god's hand is a white cloth glove and is the whole interface.

---

## 1. Pitch **[DECIDED]**

A chaotic, humorous god game. You are the god of a small, hunted cult. Your goal is to help it take over a city: win over its people, and turn it into a city living under your grace, using missions and supernatural powers. Full comedy, no good or evil meter. The cult's Secretary narrates in deadpan meeting-minutes style. Cult names, ranks and paperwork are original satire, never real organisations.

## 2. Structure **[DECIDED]**

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
- Layers of residents with different ambitions and different difficulty to convert (sections 3 to 6).
- Pacing is minutes to hours, never seconds.
- Rivals (earlier decisions, kept): rival cult, police, media, City Hall. Their detailed roles per stage are **[OPEN]**.

## 3. Residents: 8 archetypes **[DECIDED]**

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

Consequence: stage 1 contains only homeless and blue collar; every later stage introduces new people and drops others.

### 3.2 Character traits (fixed coefficients; H/M/L)

| | Homeless | Blue | Student | Bohemian | Pink | Clubber | Pensioner | White |
|---|---|---|---|---|---|---|---|---|
| Anxiety: negative factor on influence received from others | L | L | L | M | L | M | M | H |
| Sociability: positive factor on influence on others | H | H | H | M | M | L | L | L |
| Curiosity: positive factor on conversion chance | H | M | M | M | L | L | L | L |
| Skepticism: negative factor on loyalty to the cult | L | M | H | M | M | M | H | H |

### 3.3 Asset meters (fixed; H/M/L)

Wealth = money a person can generate without working. Connections = how many people can be in contact with them. Faith = how much belief they can produce.

| | Homeless | Blue | Student | Bohemian | Pink | Clubber | Pensioner | White |
|---|---|---|---|---|---|---|---|---|
| Wealth | L | L | L | M | M | M | H | H |
| Connections | H | H | H | M | M | M | M | L |
| Faith | H | M | L | H | M | L | L | L |

Reading: the poor are cheap to convert and generate belief; the rich generate money but resist.

## 4. Believer needs **[DECIDED, cells to be double-checked in play-test]**

Each believer has four needs. Meeting them gives bonuses, failing gives penalties.

- **Livelihood**: a factor that keeps the believer in the cult.
- **Security**: a factor on how long police influence lasts (how police act on believers, and why it matters, is **[OPEN]**).
- **Pleasure**: a factor on how readily the believer answers a call to action.
- **Meaning**: a factor on the believer's productivity.

Two tables per archetype: how strongly the need affects them (influence) and how much they want it (desire). H/M/L.

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

Design note: the more a person wants something the less it moves them once met (the poor are moved by basics, the rich by status and meaning). Keep this as data, not code.

## 5. Player units **[DECIDED]**

| Unit | Role |
|---|---|
| Believer | Most basic. Produces money and belief. |
| Missionary | Needs training. Converts people. |
| Priest | Needs training. Works in a sermon house, trains missionaries, essential for producing belief. |
| Special agent | Trained for a special mission; used to take over public buildings. Training building changes from district to district. |
| High priest | The starting character. Works as missionary and priest. Exactly one exists. |

Training flow: resident -> (converted by a missionary or the high priest) believer -> (training at a sermon house) missionary -> (training at a sermon house by the high priest) priest. Special agent branches from a believer through special training in a building that depends on the district.

Extra unit meters, on top of the archetype they came from: **Education** (a need whose fulfilment shortens or lengthens upgrade time), **Charisma** (a trait that scales the unit's special actions), **Experience** (an accumulated internal currency spent on upgrading the unit).

Unit tables (H/M/L; n/e = does not exist; same = no change from the believer):

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

"n/e" for a trait means a trained unit no longer rolls it (a convert has no skepticism or curiosity left). Cells that looked ambiguous in the slides are to be confirmed with Eilam in conversation.

## 6. Core loop **[DECIDED in outline, numbers PROPOSED]**

1. Hold the start building (core). Residents nearby are neutral.
2. A missionary or the high priest talks to residents. Chance to convert = base x curiosity x (1 - skepticism), further scaled by the target's anxiety and the preacher's charisma and sociability. Only trained people convert; miracles never convert on their own, they speed missionaries up and protect them.
3. Believers earn money and belief according to their wealth and faith assets, multiplied by how well the four needs are met. Belief is produced in staffed sermon houses (an empty house makes none). Believers are capped by housing.
4. Spend: money and belief on buildings, upgrades, decrees (floors, luxury, facade, change use, preserve) and miracles; mission coins on buildings, miracles and upgrades.
5. Train believers into missionaries and priests (limited number of priests), and agents when the district's special building exists.
6. The police react to visible activity (crowds, sermons, rule-breaking) by closing streets. City Hall watches for rule-breaking (floors over the limit, luxury, combat training) and slowly escalates: inspector, notice, bulldozer.
7. A building is yours when most of its residents believe. A district is yours when its core building and enough buildings are yours (threshold **[OPEN]**: 60% in code, 75% in the economy notes). The stage then ends and the next district opens.
8. Final stage: take City Hall with a majority of special agents inside, plus believers, money and belief.

Direction decisions kept from earlier rounds: only trained units convert; belief drifts back to a baseline; each visible person stands for a group of similar people; commuting between home and work; captured workplaces convert to shops, seminaries or combat sites; capturing a poor district is cheap and each later one costs more; police block streets instead of demolishing.

## 7. Open questions

Asked of Eilam one at a time, in conversation. Resolved items move up into the sections above.

1. District capture threshold: 60% (current code) or 75% (economy notes).
2. Name and source of the special coin ("Grace"): which missions give it.
3. What each stage's special-agent training building is.
4. Stage length of the first playable slice (proposal: 45 to 60 minutes for Slums, 3 to 4 hours for the finished stage).
5. How police affect believers, and why security matters.
6. What a person's unmet need does (leaves the cult, stops working, or both).
7. Role and timing of rival cult and media per stage.
8. Ambiguous cells of the unit tables (section 5).
9. Mission list for stage 1.
10. The story: who the god is, why this cult, why this city.

## 8. Numbers we already trust (balance simulator v4 to v10)

- Max priests 12; stage clock about 300 minutes; police raid threshold 120 heat; City Hall: 6 agents (30% of its staff), academy cost 100, agent cost 150. A skilled player wins about 60 to 86% in 3.5 to 4.8 hours; a sloppy one fails within the limit. The time limit is the skill gap.
- Heat and price growth are the real steering wheel (+15% cost cliff).
- The bottleneck is capturing the houses around City Hall, not money or conversions.

These are starting values and live in `data/*.tres`.

## 9. Not in the game (pruned) **[DECIDED]**

Good/evil meter, three worlds, end-of-world backstory, the creature, tree lifting by hand, plague and bedbugs, miracle conversions, Metropolygonia assets.
