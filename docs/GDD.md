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
3. **Chosen direction (Eilam, 2026-11-12; nothing of it is built yet).**
   - **Background story (kept by Eilam as an opening for humour): the god applied and was refused.** The god filed a request with City Hall to be recognised as a god, and it was turned down (a form was missing). That is why the god is against City Hall, and where the Secretary's case file and minutes come from.
   - **A journey, in one of two ways.** There are no signatures and no petition; believers stay believers.
   - **Freedom: you sweep people along behind you.** A following that grows because people choose to come. It takes a real majority and it is slow, and the time goes into the buildings and the people. Ending: nobody needs a permit for anything.
   - **Control: you take things over yourself.** Buildings, offices and rules pass into your hands. Fast and focused, with little spreading out. Ending: you are the new City Hall, and the game laughs at you.
   - **Mechanics: stamp or tear.** Every building stands under City Hall's rules. The hand can stamp rules of its own in their place (control; today's decrees are this) or tear them up and let the residents decide (freedom; tearing the condemnation notice off is this). Two plain verbs for the hand.
   - Kept as inspiration for the Artist: bureaucracy as a physical thing in the city (red tape round buildings, forms in the wind, people stuck in queues). Dropped: a second, dark hand (too close to good and evil).
4. **One bar per district, two sources (Eilam, 2026-11-12; built in 0.11.0 with provisional numbers).** Not an independence meter alone. A district is won when its bar is full, and two kinds of action fill it:
   - **A wide following**: sweeping people along, their welfare and their freedom. In the game: the share of the district's buildings that are yours, over 60%, times 0.85 to 1.15 by how well your believers' needs are met.
   - **Focused actions on key places**: the agent defacing things, and other options to come. In the game: the core held is worth 20%, each marked landmark 8%.
   - Either way alone is very hard: the following alone needs most of the district (52% to 70% of its buildings, by welfare); the key places alone give 60% and still need about a quarter of the buildings. Mixed, the player can raise a large force and use the agent lightly, and put the time into other things.
   - Key places are not required: an aggressive player needs more of them and plans the takeover to reach them; a player who cultivates a large area can use them to get ahead, or take none and win on most of the district.
   - The core is therefore no longer a condition for winning, only the largest key place.
5. **The hand places people (Eilam, 2026-11-12; first step built in 0.12.0).** The hand is a spirit that moves people, tears and stamps, and now and then works a miracle; it never talks anyone round itself and never builds.
   - **Where it sets someone down, and who they are, is what they do**: a canvasser at a door talks to the people inside; a member at a branch joins it; a clerk at a branch serves there; the field delegate at a key place does their act.
   - **Willingness.** Someone who lives well goes gladly and gives full effort. Someone neglected or worn out by orders still goes, with a penalty in three parts, all approved: their work is worth less; it wears them further and after a few such orders they leave; and the neighbours who see it raise the district's awareness.
   - This is the dial between the two ways: moving people like pieces is fast and wears them down, and a following that lives well acts by itself.
6. **Names (Eilam chose set B, 2026-11-12; in the game since 0.12.0).** Believer: Member. Missionary: Canvasser. Priest: Clerk. High priest: the Secretary, who is also the narrator of the minutes. Special agent: Field Delegate. The cult: the Committee. Sermon house: Branch. The text of sections 1 to 12 still uses the old names.
7. **The model (Eilam with the Programmer, 2026-11-13). This is the game now; it replaces everything below that disagrees, and the systems listed under "Removed" are deleted from the code.** The other threads were told to stop until round A is out. **Status: rounds A (the economy, 0.15.0) and B (the danger, 0.16.0) are built; round C is not.** As built in B: an inspector who arrives demands paperwork (a Rep shows papers, a building passes its audit) and only takes the Rep or the building when there is none, so paperwork is the shield and the hand saves it; "Bury the File" at the Office spends paperwork to lower exposure; key buildings have placeholder names. Open for the Designer and the Balance Tester from round A: paperwork and money have few sinks late in a run (see the CHANGELOG numbers), and the district bar is a placeholder (share of buildings) until round C.
   - **Followers are a number per building.** Each building of yours has room (by its size and floors) and a count that starts at half its room when taken and grows by itself, by how attractive the building is. All followers are one pool. No building is ever empty.
   - **A building has three upgrade tracks**: floors (room), attraction (how fast followers come), security (how hard it is to turn back: cameras, a guard, your portrait in every flat); and one use.
   - **Roles are slots, filled by themselves from the pool.** Seller in a shop, clerk in an office. Someone with a role is still a follower and still counts toward the majority. A follower with no role produces nothing and is only counted.
   - **Rep**: trained from one follower for paperwork and time. There is a cap on Reps: 2 at the start, +1 by upgrading the main Office, +1 for every key building turned into an office. A Rep who becomes a Manager leaves the cap, so another can be trained. **Fixer**: one, a second after a high upgrade of the main Office; trained only there.
   - **Taking a building.** Press a building in reach and choose "Send a Rep" (the wheel is kept for more options later, such as a ruse at a police building), or set a Rep down at its door by hand. The meter fills by the building's size, the exposure and the number of Reps at the door; full, the building is yours and the Rep is its Manager. A building next to yours inside a block fills by itself, slowly, and then only needs a Rep.
   - **The god's attention.** The building the hand hovers over fills faster, and so does training at an office: one place at a time, so the player chooses where to be.
   - **Danger: cat and mouse (round B).** An inspector comes out of the area's key building and walks to a working Rep, in plain sight. If he arrives the Rep is lost. The hand can lift the inspector and set him down far away, and he starts walking again from there; another may come out. At high exposure several come at once and cannot all be held off: send a second Rep to finish sooner, or post the Fixer as a guard.
   - **Turned back.** A building of yours can be turned back by the key building's people, by neglect, or both: its followers leave the pool, its Manager is lost, and its meter stays at 60%.
   - **Money** comes from sellers. A shop has slots; each further seller brings in less and is paid the same (diminishing returns), and the pay comes off that shop's own takings, so a shop is never at a loss unless the player packs it by hand. The button to add a seller shows what the next one adds, net. A seller can be let go.
   - **Paperwork replaces belief.** Clerks make it. It pays for training, for stamped decrees, and to open a loan.
   - **A loan**: one at a time, opened with paperwork, paid back slowly from takings or at once with the banknotes of the money miracle (the miracle makes real notes; it does not erase the debt, so "a miracle cannot move the bureaucracy" holds).
   - **Three kinds of building.** The **main Office** is homes, shop, clerks, and training for Reps and for Fixers: the heart; its use is never changed. An **ordinary building** is homes and can be turned into a shop. A **key building**, one to every four or five blocks (about nine in the Slums), is where the inspectors come from; taken, it can be turned into an office that makes paperwork and trains Reps only, and its upgrades make both more efficient and raise the caps.
   - **Winning.** 80% of the key buildings (the narrow way), or 30% of them with 60% of the district's people as your followers (the wide way).
   - **Removed**: landmarks, murals and the Vandalist; awareness, heat and police roadblocks; City Hall's inspector and bulldozer; fragility, complaints and condemnation; seats and debt; street meetings; needs and traits per person; the skull and dollar marks; the facade and preserve decrees; the upgrades for preaching and force; wear from the hand's orders.
   - **Only Reps, the Fixer and the Secretary are lifted by the hand.** Other people are the crowd in the street.
   - **Later**: the list of miracles and their stock; the special coins; names for the Slums' key buildings; a facade editor in which the player decorates a building's front and that changes its attraction or how frightening it is (Eilam's side note).
   - **Rounds**: A, the economy (followers as numbers, slots, shop, paperwork, the Rep cap, building cards, the god's attention, the removals). B, the danger (exposure, inspectors the hand can move, losing a Rep, turning back, security). C, the goal (key buildings that become offices, the Fixer, the two ways to win). Each round is a build to play.
8. **How people come over (Eilam, after playing 0.12; built in 0.13.0; the meter of item 7 now carries it).**
   - **Not in the street.** Converting passers-by felt pointless. The street is to get another job later; for now a street meeting only rests worn-out members.
   - **At a door the player chose**: the residents of a building, by canvassers set down there.
   - **Or by themselves, slowly, and only inside a block**: buildings of yours bring their neighbours round by how free and inviting they are. One block never works on another, so growth is orderly and the player decides where to cross.
   - **The first building, the Office, is the most capable**: it gets the game going by itself (it works on its block four times as hard) and the Secretary canvasses in person.
   - **No abandoned or empty buildings** anywhere in the game: a building is won by winning its residents, nothing else.
9. **Paperwork and miracles (Eilam, 2026-11-12; not built yet).**
   - **Paperwork replaces belief** as the resource. Branches make it; it buys everything official: stamping your own rules on a building, objecting to a notice, bail, training.
   - **A miracle cannot move the bureaucracy.** It works on people and the physical world only: it never takes a building, fills the bar, cancels a notice or frees anyone. It gathers a crowd, lifts spirits, distracts officers and inspectors.
   - **Miracles do not cost paperwork.** They come from a small stock (about three) that refills slowly.
   - **City Hall answers every miracle with a form**: a dry notice and a fine ("unlicensed precipitation"). That is the price and the joke.
   - Open: the list of miracles and powers that fit this. The Programmer's candidates: Block Party (keeps), Rain of Frogs (a distraction), a smell of fresh bread that brings residents to their doors, a yawn that sends officers to sleep for a minute, a sunbeam on one canvasser, pigeons over a camera, every phone ringing at once.
10. Open for the Designer: what the Vandalist, street art and "colour is freedom" become when the god is not a street artist; how each style wins the Slums (the Programmer's suggestion: the district's independence sets how much of it you need, a real majority when it is high, the core and a small tight area when it is low).

---

8. **Rooms: the vertical plan of a building (Eilam, 2026-11-14). Built in steps; step 1 is in 0.17.0.**
   - Every building of yours is a grid of bays and floors that the player can plan with rooms. Rooms come as shapes (tetris-like, they can be turned) that must be fitted in; the game is both the price (money and paperwork) and the fitting, and to fit more the building must grow (floors).
   - It must work when ignored: a building fills itself with plain flats, and the player touches only the buildings they care to. Later: dictate one building's plan to similar buildings.
   - In a special building (an office): offices that make paperwork, **paperwork stores** (paperwork can't be kept without end, only as far as the stores go), training rooms and so on. Money has a ceiling too. The dilemma moves from balancing money to a system of resources with ceilings that the player makes efficient, to afford dear things later or to keep a reserve.
   - In a house: an elevator adds comfort and takes the place of flats; luxury two-floor flats house fewer and are needed in rich districts, where the demand for comfort is higher.
   - What draws the buildings next to yours is how impressive the building is: some kinds of room next to each other raise the impression; the same goes for security, raised by the right combination of rooms. (Not built: step 3.)
   - Rooms are to have models of their own, so planning is also decorating (the Artist; not built: coloured blocks for now).
   - Pausing is the player's own (Space): the editor never stops time by itself.
   - The map may shrink a good deal to suit this (not done yet).
   - This replaces the upgrade tracks of item 7 (attraction, security, shop, desks, training are rooms now) and the "open a shop" decree (a shop is a room).

9. **The building planner, in depth (Eilam's document, 2026-11-14). The target for item 8; step 1 (0.17.0) built only the grid, ten rooms and the ceilings.**
   - **The screen.** Double click a building of yours: the camera zooms to its front and everything behind blurs. The blocks show inside the building itself, furnished, in simple isometric 3D, like playing with a realistic doll's house. Beside it a menu of the blocks you own. (Built so far: a flat screen of coloured blocks opened from the wheel.)
   - **Block types by colour**: blue homes, red fear/security, yellow shops, purple offices. The strength of the colour is the block's level; some residents demand a certain level.
   - **Where blocks go.** An office building takes utility, office, storage and training blocks; the main Office also takes homes and shops.
   - **Basic and advanced.** Basic blocks give the basics (residents, income, paperwork). Advanced blocks also buff other blocks, earn more, or hold more demanding followers (later stages).
   - **Neighbours.** Some blocks don't like to be next to others (an advanced home next to a basic home or a utility); some can only go next to a certain block and boost it at a price in upkeep (a storage room next to a shop, an archive next to an office).
   - **Utility blocks.** Every building comes with a **staircase** block that can't be placed or moved: an obstacle to plan round, needed for access to every floor, upgradable (it affects impressiveness, outcome and speed). Advanced homes want an **elevator** in place of the stairs, on the floors they are on; an advanced shop needs an energy block; very advanced residents want a boiler room, a gym, a laundry.
   - **Upkeep.** Utility blocks cost upkeep in money, paperwork or both. If it can't be paid the block closes until the income is balanced again; the blocks that depend on it earn less, or their residents lose faith for want of comfort and in the end leave, which sets back the win.
   - **Attractiveness** comes from decoration and from blocks having the utilities they want in the building (not necessarily next to them). It shortens the conversion of buildings inside your influence, most of all with demanding people.
   - **Fear/security** is how well the building stands against outside forces that would turn or remove your people. Fear blocks lower attractiveness next to blocks that dislike them, but past a certain amount residents can't leave: a luxury building can be held without meeting its needs, by fear, so the player can go for the win instead of looking after residents. Fear that can't be kept up (upkeep) stops working.
   - **Floors.** Adding a floor adds a row, for money and paperwork at a rising price. A bigger, wider building has more blocks but takes longer to convert, which is riskier.
   - **The outside decoration editor**, switched to from the planner: a slot under every window where a decoration snaps in by drag (flowers, a camera, an air conditioner...). Small, cheap, capped bonuses to attractiveness or to protection.
   - **Shapes by tier**: basic (1, 2 wide, 3 wide, 2 high); advanced (L of 3, S, T, 3 high, L of 4); luxury (a plus, a C, 2 by 3, 4 high, a fat L, a long S). The more advanced the block, the harder the shape: space becomes a difficulty curve next to price and upkeep.
   - **Key points** (about nine a district, each with a block area round it): breaking into one takes special talents, trained in a special training room; then actions can be done there, for money and paperwork, and they raise attention. The upkeep of a wide majority hinders the talents and the other way round, so the player takes fewer of one or the other. A key point taken becomes a new office that makes the paperwork needed for special upkeep and special moves, to take more of them. (This is round C of item 7.)

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
- **Win and lose.** Win: the district's bar is full (section 0, item 4). Lose: once you have had 8 believers, none for 3 minutes.

What the game needs from the Designer, in order:

1. **The hand's verbs in the loop.** Today the loop runs by itself and the hand mostly opens wheels. Suggestions from the Programmer, cheapest first: setting a missionary down at a building starts the sky sign there (no wheel); knocking on a door brings its residents out to be talked to; a miracle near a preacher is the main way to speed a street up, shown on screen. Today a miracle only adds hidden "proof".
2. **The two styles as rules** (section 0): what counts as control and what as freedom among today's actions (the skull and dollar marks, decrees, posts, lifting people with the hand against preaching, upgrades for comfort, the block bonus), what moves independence, and how each style wins.
3. **The first ten minutes**, step by step: what the player does, sees and wins.
4. **Fewer hidden meters.** Awareness, heat, exposure, suspicion, fear, comfort and four needs all work unseen; the player only feels the game slow down. Each one kept needs a sign in the world.
5. **Money has no use yet** in the Slums (the bot ends an hour with $24,000): the spending list in section 7 is not built.
6. **Numbers** for the block bonus, residents per building (now 1 to 3), awareness and fragility (changed in 0.10.0, provisional).

## 13. The system in three layers (the Programmer's outline, 2026-11-12, at Eilam's request)

Eilam: sort the system into its base, then the branches that let a player balance by their own style, in a form that carries over to the other stages by raising the difficulty through the kind of residents, the kind of buildings and the balance. This is that outline; the Designer corrects it.

### Layer 1: the base (the same in every stage; a stage never changes these)

1. You start in a base at the edge and grow outward; a building can only be taken if it borders one of yours.
2. A building is yours when most of the people living in it are with you.
3. A block whose buildings are all yours is safe and pays a bonus.
4. The district has one bar with two sources, a wide following and key places; when it is full the district is yours.
5. Believers have four needs; how well they are met sets what they give, whether they stay, and how much the following counts.
6. The city pushes back on what it sees: the district's awareness, the police at a building, City Hall.
7. The hand has two verbs: stamp (your rules) and tear (no rules). Not built yet.

### Layer 2: the branches (what the player balances by style)

Every branch has a wide side and a focused side, a price, and the thing that pushes back. A player leans on one side or mixes.

| Branch | Wide side (sweeping people along) | Focused side (taking things over) | What pushes back |
| --- | --- | --- | --- |
| People | missionaries, sermons | the special agent and its act on key places | awareness against a crowd; arrest and cameras against the agent |
| Buildings | welfare: upgrades for comfort, later the building editor | rules of your own: decrees, uses, posts | complaints and condemnation; City Hall's building code |
| Money | free spaces, comfort, upkeep of many | the agent's supplies, fines and bail, buying | it runs out: a wide area costs upkeep, focused acts cost per try |
| Belief | staffed sermon houses, miracles that help preachers | miracles that rescue the agent or clear the police | exposure when miracles are seen |
| The bar | share of buildings, times welfare | the core and marked landmarks | lost buildings; marks scrubbed |

A branch is balanced when its wide side alone and its focused side alone are both possible and both hard.

### Layer 3: the stage profile (what changes from stage to stage; numbers only)

A stage is the base and the branches with one profile of numbers. Difficulty rises by turning these, not by adding rules.

| Knob | The Slums today | How later stages turn it |
| --- | --- | --- |
| Who lives there | homeless and blue collar: curious, sociable, poor, quick to believe | more skeptical and anxious people, who resist and leave more easily, and want more of each need |
| What they give | much belief, little money | more money, less belief |
| Residents per building | 1 to 3 (one or two conversions take a building) | bigger buildings with more people, so a building takes longer |
| Kinds of building | walk-ups, small shops and sheds; few public buildings | more workplaces and public buildings, which need the agent or another way in |
| Blocks | 5 to 12 buildings, about 50 blocks | larger blocks, harder to complete |
| Key places | the core and five landmarks; core 20% of the bar, a mark 8% | more of them needed, guarded better, worth less each |
| The following alone | 60% of the buildings | a larger share |
| The agent | the Vandalist: marks landmarks; 10% arrest chance, 4 minutes, $100 | a different agent per district, with a costlier and riskier act |
| Awareness | rises 0.08 a minute at most, fades 0.08; makes converting harder down to x0.4 | rises faster, fades slower |
| Police | step in at 30 heat; one roadblock per 4 minutes | lower threshold, more often |
| City Hall | complaints and a notice that closes a building for 5 minutes | harsher tools: inspector, demolition |
| Welfare | counts x0.85 to x1.15 on the following | counts for more, so neglect costs more |

### What this asks of the code (for when the freeze ends)

Today only four of these knobs follow the district: who lives there, the district's wealth, the map's building mix, and how hard the police are. The rest (awareness, the agent, key places, the bar, residents per building, City Hall's tools) are single numbers for the whole game, spread over eight data files. Before a second stage is built they move into one profile per stage, so a new stage is a new data file and the Balance Tester can run the bot on each.
