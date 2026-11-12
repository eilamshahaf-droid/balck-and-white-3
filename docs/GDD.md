# Spin Cycle: Game Design Document

The repo's copy of the designed version (https://claude.ai/artifact/3SbaznH5KKjxk2jop61iBf), which is the source: owned by the Game Designer thread, with Eilam as Creative Director. Synced from the page on 2026-11-12 by the Programmer; sections 1 to 3 and 7 to 11 are the page's text, the tables in 4 to 6 are unchanged, section 12 is the Programmer's.

Working title: "Spin Cycle". Platform: PC, Godot 4, toy-like 3D with tilt-shift. The god's hand is a white cloth glove and is the whole interface.

---

## 0. Direction from Eilam, 2026-11-12, after this version (not yet folded in by the Designer)

Where this disagrees with the text below, this wins.

1. **Not a street-artist god.** Eilam did not connect with it. The god stands for resistance to bureaucracy, and there are two ways to resist it:
   - **Control** (the "bad" way, so to speak): you write the bureaucracy anew yourself. Faster, focused, with less spreading out: an allegory for the few who dictate the rule.
   - **Freedom** (the "good" way): you win people their freedom. Unhurried; you need a real majority to succeed, so it is slower, and the game lets you enjoy the pace by investing: in key buildings, in planning the believers' apartments (section 9), in their welfare.
2. **The game should feel considered, not a fast takeover of everything.** The player has time to put into each building, into the believers' welfare, and into cultivating their own values.
3. **Chosen direction (Eilam agreed with the Programmer's recommendation, 2026-11-12; nothing of it is built yet).**
   - **Story: the god applied and was refused.** The god filed a request with City Hall to be recognised as a god, and it was turned down (a form was missing). The whole game is the appeal. Each district is a department, belief is signatures on a petition, and the Secretary keeps the case file. This gives a reason to what the game already has: a majority in a building, the minutes, landmarks that are offices.
   - **Freedom** is collecting real signatures: it takes a real majority and it is slow. Ending: the city abolishes the register, and nobody needs a permit for anything.
   - **Control** is forging, leaning on people and opening an office of your own: fast and focused. Ending: you are the new City Hall, and the game laughs at you.
   - **Mechanics: stamp or tear.** Every building stands under City Hall's rules. The hand can stamp rules of its own in their place (control; today's decrees are this) or tear them up and let the residents decide (freedom; tearing the condemnation notice off is this). Two plain verbs for the hand.
   - Kept as inspiration for the Artist: bureaucracy as a physical thing in the city (red tape round buildings, forms in the wind, people stuck in queues). Dropped: a second, dark hand (too close to good and evil).
4. Open for the Designer: what the Vandalist, street art and "colour is freedom" become when the god is not a street artist; how each style wins the Slums (the Programmer's suggestion: the district's independence sets how much of it you need, a real majority when it is high, the core and a small tight area when it is low).

---

## 1. Pitch

You play a god nobody asked for, in a modern city that denies you. Your cult is tiny and chased by the authorities. Its Secretary narrates everything in deadpan meeting minutes, with ranks, paid courses and paperwork that satirise cults without copying any real one.

There is no good or evil. There is a city, seven districts, and the question of how far a few believers can go with a lot of nerve, some miracles and a laundromat basement.

## 2. The story

*What the game is about underneath the cult.*

### A god against bureaucracy

You are a street-artist god. You try to make the city friendly and alive, and City Hall wants everything grey and in order, by force if needed. Every district has its own status quo that holds people in place, and that is what you break.

The opposition is not only municipal inspectors. It is also residents who are afraid of change, and many of the people who stand against you simply want their own rules. The game laughs at the system, never at the people stuck in it.

### The opposition

**Police** close streets in response to visible activity. **City Hall** watches the building code and escalates from inspector to notice to bulldozer. **Residents** who cling by force to what is familiar resist through their own skepticism and fear. **The media** does two jobs: it is the channel through which the game hints that awareness of the player is rising, and it amplifies the residents' resistance. There is no rival cult.

### What the believers believe

They believe in freedom from the bureaucracy that cages them. Colour is how that freedom shows up on the street, but it is the freedom they follow. Their religion draws inspiration from anarchist movements.

### The religion in the city

Every district has an ordinary religious building. The special agent is what changes: each district has its own kind, shaped by that district's challenges and residents.

### The Slums agent: the Vandalist

In the Slums the special agent is the Vandalist, a funny cross between vandal and evangelist, who makes street art, and the neighbourhood tries to wash it away. The player sends the agent to a spot, and each visit draws a different reaction from a pool of responses. The chance of each response grows the more it is used, so the city adapts. The pool includes painting over the art, fines and installing cameras, and cameras can go up even when no art is nearby. At first people simply paint over it. The agent can then paint where nothing is painted yet, or answer what has been painted, using the walls the city has already covered. The more directly the player steers the agent, the more control they have and the less the neighbourhood does by itself.

The Vandalist is the one who can be arrested, never the priest. An arrest turns him into a martyr: conversion near him gets easier for a while, at the price of losing him until he is freed. The player has three ways out: rescue him with the hand for a cost in belief, pay a fine for his release, or wait out the time.

### Landmarks of the status quo

Each district holds five designated buildings that stand for its status quo. In the Slums they are the landlord's office, the city notice board, the police booth, the inspector's office and the post office. The Vandalist marks them without getting caught, and each mark makes the core much easier to take, so three marks bring the heart of the district within reach. Without him the core stays very hard, though not impossible.

Marks can be undone. City Hall or radical elements can wipe them out, so a player who is too slow has to do the work again, and every attempt costs time and resources. How the player chooses to mark also shapes the people: painting it for them leans toward control, and handing the residents the paint leans toward freedom, which is slower.

The Vandalist is trained from any believer, at the base, in about two minutes for a fee.

### What limits you in the Slums

Police are not the only brake. Two lighter limits come from everyday life, exaggerated. **Neighbour complaints** flood the city's complaints line about noise and paint, and raise the district's awareness. A **condemnation notice** declares a building unsafe and closes it temporarily, which empties it of its residents. The player can step in against a condemnation notice, since the game knows the player is a supreme being: tearing it off with the hand costs some belief and reopens the building at once, to a witty line from the Secretary. Or the player can leave it alone, and the building reopens by itself, more slowly. Both are milder than an arrest, so the first district stays gentle. Later districts bring harsher limits, and difficulty rises step by step from district to district.

### The colour of the city

Colour on screen follows independence. Your own area is rendered in colour that grows richer with the freedom you have won there, and the rest of the city stays grey. A piece of street art in a newly reached district stands out sharply against the grey around it. A building turns colourful gradually as it gets closer to your area, so the border between colour and grey is a slope, not a line.

### Neighbours help each other

Buildings of yours standing next to each other give each other a bonus. A player who builds out a compact area wins on freedom: residents feel at ease, believers act on their own without guidance, and the area becomes stronger by itself. A player who builds a narrow line of buildings toward a target has no such help and must control people aggressively to make it work. Both can succeed, and the two styles can be mixed during play.

The bonus is protection and a little extra output. Once an area is yours, City Hall stops interfering inside it, so there is no need to defend against intrusion. Resources influenced by the surroundings get a small boost, so the player does not have to micromanage and can set supply to what is needed. The result is slow and steady progress for the compact player, against fast progress through intense work on the believers for the one who strikes out in a line.

### Control spreads continuously

A building can only be taken if it borders the area you already hold. Progress grows out of your sphere of influence, and the player can never suddenly take a building elsewhere in the district.

Buildings are taken one at a time. A block of five to twelve buildings whose buildings are all yours is safe: it cannot give way, it draws no complaints, its people produce 25 percent more, and the district calms a little.

### Awareness keeps the styles in balance

Each district has its own awareness of you, and it matters as much as City Hall's attention. A concentrated, visible presence raises awareness steadily, which makes further progress harder. In return it gives a strong base from which the player can issue general orders. Full control of the believers, moving them like chess pieces, keeps awareness low but leaves the player with few resources, and the heart of the district is then hard to take, because it means a real strategic war with awareness spiking all at once.

The thin line of buildings is a legitimate challenge, not a mistake. It is continuous, but it produces little and is easy to take apart. In exchange it is fast, and it is a personal challenge: reaching the target with the minimum possible, using micromanagement that not everyone can keep up.

No style runs away with the game. The two are meant to be mixed, so the player can move between a strong base and tight control as the situation changes.

### Independence

A hidden measure tracks the independence of each district. What moves it is how you intervene, not how much: clearing obstacles and letting people act on their own raises it, while commanding people and forcing decisions on them lowers it. It builds slowly through the whole game and shapes the character of play along the way. The player sees it in the streets, in how much people do by themselves, and never as a number.

### Two endings

The ending closes the circle the player has been drawing. If you ruled from above, you replace City Hall and become the new authority, and the game gently mocks it. If you let people lead, the ending is anarchist: everyone reaches their potential without social pressure.

## 3. The city, in seven stages

*One city made of public, workplace, residential, faith, empty and abandoned buildings, split into seven districts. Each district is a stage and takes about three to four hours. The districts are taken in this order, each harder than the last.*

1. **Slums.** The cult's home. Cheap to win, poor in everything but time.
1. **Workers.** Factory and shift workers with just enough to lose.
1. **Students.** A university quarter. Curious, broke and hard to keep.
1. **Gentrification.** Old tenants and new money share one street.
1. **Tourism and nightlife.** Crowds that never sleep and never stay.
1. **Financial.** Towers of money and sceptics, guarded by police.
1. **Old civic district.** City Hall. Win it and the city is yours.

Every stage starts in one multipurpose building for faith, money and housing: the **base**. From there converts go out, the district changes and a strategy takes shape. Resources are money, belief, believers, priests, people with special abilities, and special coins from completed missions that buy buildings, miracles and upgrades.

Pacing is slow on purpose: minutes and hours, never seconds.

For now the work is the Slums alone. No other districts and no new systems until the opening of the Slums is good; the first target is ten good opening minutes, not a full stage.

## 4. Residents: 8 archetypes

Homeless, blue collar, student, pensioner, clubber, pink collar, white collar, bohemian.

### 4.1 Where each archetype lives (X = exists)

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

### 4.2 Character traits (fixed coefficients; H/M/L)

| | Homeless | Blue | Student | Bohemian | Pink | Clubber | Pensioner | White |
|---|---|---|---|---|---|---|---|---|
| Anxiety: lowers influence received from others | L | L | L | M | L | M | M | H |
| Sociability: raises influence on others | H | H | H | M | M | L | L | L |
| Curiosity: raises conversion chance | H | M | M | M | L | L | L | L |
| Skepticism: lowers loyalty to the cult | L | M | H | M | M | M | H | H |

### 4.3 Asset meters (fixed; H/M/L)

Wealth = money a person makes without working. Connections = how many people they can be in touch with. Faith = how much belief they can produce.

| | Homeless | Blue | Student | Bohemian | Pink | Clubber | Pensioner | White |
|---|---|---|---|---|---|---|---|---|
| Wealth | L | L | L | M | M | M | H | H |
| Connections | H | H | H | M | M | M | M | L |
| Faith | H | M | L | H | M | L | L | L |

The poor are cheap to convert and generate belief; the rich generate money but resist.

## 5. Believer needs

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

## 6. Player units

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

In a free style of play the training chain reads as mentoring between friends, with no ranks worn on the head; in a controlled style the same steps look like a chain of command. The mechanics are the same either way.

## 7. The loop

*What the player does, in the order it happens in a stage.*

1. **Hold the base.** Each stage starts from one multipurpose base building for faith, money and housing, at the edge of the district. Everything grows out of it, inward toward the district's core.
2. **Convert.** A missionary or the high priest talks to residents. Chance depends on curiosity, skepticism, anxiety and the preacher's charisma. Miracles never convert anyone; they speed missionaries up and protect them.
3. **Earn.** Believers produce money and belief according to their wealth and faith, scaled by how well their four needs are met. Belief comes from staffed sermon houses only. There is no fixed cap on believers. The limit is soft: the district holds a finite number of residents, a large concentration raises awareness and the district reacts, and every believer needs a place to be (a free space or meeting spot) and costs a little upkeep. When spaces fill up, people stay out on the street where everyone can see them.
4. **Spend.** Money pays for upkeep, training agents and upgrades, and for the Slums: the agent's supplies (paint, ladders, signs; every action costs), fines and bail when the Vandalist is caught, repainting a mural City Hall covered, soothing a complaint or condemnation notice for a price (with a dry line from the Secretary), and free spaces such as a community kitchen, workshop or garden that raise comfort and output in the area. Later: answering the media, and a kiosk that earns money but raises awareness.
5. **Train.** Believers become missionaries and priests, and agents where the district has the special building.
6. **Stay unseen.** Crowds, sermons and broken building rules raise heat. Police close streets. City Hall watches the building code and escalates from inspector to notice to bulldozer.
7. **Take the district.** A building is yours when most of its residents believe. A district is yours when its core building and most of its buildings are. The core is a separate building near the centre that has to be won. Then the next district opens.
8. **Take City Hall.** The last stage: a majority of special agents inside, plus believers, money and belief.

Further rules: belief drifts back to a baseline unless priests keep it up; each visible person stands for a group of similar people; residents commute between home and work; captured workplaces turn into shops, seminaries or combat sites; poor districts are cheap to take and every later district costs more; police close streets and never tear buildings down.

## 8. Missions

*Completed missions give the special coins that buy buildings, miracles and upgrades. Two kinds, from Eilam's first examples.*

Missions are optional. They are a bonus that asks for the player's specific attention: they earn coins for upgrades and purchases, and, as with the extreme believer, they also help push the player's own style of play forward. Nobody is stuck for skipping them.

### Operations

A task for a specific unit. Example: send the special agent to mark five designated buildings without being caught.

### Dilemmas

A believer who acts in an extreme way forces a choice. Example: a fanatic believer, where the player can restrain them, get rid of them, or channel them into something useful. Restraining leans toward control and channelling leans toward freedom, so those choices move the district's independence. The third answer is to fling them away with the hand and a dry remark from the narrator, a piece of black humour. It gives nothing back, because it pushes independence in no direction.

## 9. The building editor

*Something to do while the district grows.*

Each building of yours opens as a cutaway, like a dollhouse, with rooms and slots. The player places items that feed the four needs: kitchen or workbench for livelihood, lock and lighting for security, a music corner for pleasure, a painted wall or a place to talk for meaning. A smart arrangement improves the believers' welfare and gives the building a personal design.

The editor is optional. Every building fills itself with a sensible default, and a hand-made arrangement adds only a small bonus, around 10 to 15 percent. It is a way for players who prefer not to direct people to influence them in a small way, and a way to pass the time and improve efficiency without micromanaging. It comes in a later round, after the Slums work.

## 10. Starting numbers

- Priests at most: 12.
- Heat at which the Slums police act: 30.
- City Hall: 6 agents (30% of its staff) to take it.
- Time limits on a stage: none.

The first district is the shortest, about one to one and a half hours, and teaches the game; later districts grow toward three to four hours. There is no clock on a stage. Pace comes from how the district and City Hall react to the player, which keeps the game dynamic and does not punish a player who lets things develop. The hard part of the last stage is taking the houses around City Hall, not money or conversions.

These live in `data/*.tres`. To judge a change, run the bot: `godot --headless --path . res://tests/pace_sim.tscn -- --minutes=60 --bot=train,pray,preach`. With 0.10.0 it holds about 150 of the Slums' 417 buildings after an hour, with no hand and no miracles.

## 11. Left out

Good and evil meter, three worlds, end-of-world backstory, the creature, lifting trees, plague and bedbugs, conversion by miracle, a rival cult.

## 12. The Slums as built (0.10.0), and what the game still needs from the Designer

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

1. **The hand's verbs in the loop.** Today the loop runs by itself and the hand mostly opens wheels. Suggestions from the Programmer, cheapest first: setting a missionary down at a building starts the sky sign there (no wheel); knocking on a door brings its residents out to be talked to; a miracle near a preacher is the main way to speed a street up, shown on screen. Today a miracle only adds hidden "proof".
2. **The two styles as rules** (section 0): what counts as control and what as freedom among today's actions (the skull and dollar marks, decrees, posts, lifting people with the hand against preaching, upgrades for comfort, the block bonus), what moves independence, and how each style wins.
3. **The first ten minutes**, step by step: what the player does, sees and wins.
4. **Fewer hidden meters.** Awareness, heat, exposure, suspicion, fear, comfort and four needs all work unseen; the player only feels the game slow down. Each one kept needs a sign in the world.
5. **Money has no use yet** in the Slums (the bot ends an hour with $24,000): the spending list in section 7 is not built.
6. **Numbers** for the block bonus, residents per building (now 1 to 3), awareness and fragility (changed in 0.10.0, provisional).
