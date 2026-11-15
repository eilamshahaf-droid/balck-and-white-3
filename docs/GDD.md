# Godministration: Game Design Document

The repo's copy of the Designer's page (https://claude.ai/artifact/3SbaznH5KKjxk2jop61iBf), which is the source: owned by the Game Designer thread, with Eilam as Creative Director. Synced from the page's v29 on 2026-11-15. The last section, "The rules as built", is the Programmer's and says what the game does today.

Working title (formerly Spin Cycle). PC, Godot 4, toy-like 3D with tilt-shift. The god's hand is a white cloth glove and is the whole interface. Updated 2026-11-15, Pre-Alpha 0.20.

A comedy about a god nobody asked for, up against a city run by paperwork. Win a district one building at a time, either by taking its offices over or by winning its people over.

---

## 1. The pitch

You play a god nobody asked for, in a city run by paperwork. The god once applied to City Hall to be recognised as a god, and was refused: a form was missing. Since then the god's tiny Committee has one aim, to out-file the bureaucracy in one district after another. The Secretary narrates everything in deadpan meeting minutes.

It is a comedy, and it is meant to feel considered, not like a fast takeover of everything. The player has time to put into each building and the people in it. There is no good or evil, and there is no cult taking over: the god stands for resistance to bureaucracy.

**The hand is the whole interface.** It lifts only Reps, the Fixer, inspectors and street props. It never converts anyone and never builds anything itself.

## 2. Two ways to resist

Every district can be won in two ways, and the way you play shows in the ending.

### Control
You take the offices over yourself. It is fast and focused, with little spreading out, an allegory for the few who dictate the rule. In the end you are the new City Hall, and the game laughs at you. In play: the Fixer opens key buildings, Reps are sent from door to door, and fear rooms hold residents in place.

### Freedom
People follow you because they choose to. It needs a real majority and it is slower, and the time goes into the buildings and the people: Managers who stay, homes people like, shops that earn. In the end nobody needs a permit for anything.

### What the two ways are made of
Both ways are paid for from the same pocket, upkeep, so they pull against each other. Winning the people means running homes and utilities, and the upkeep of those utilities eats the paperwork and money that the key buildings' special talents need. Chasing key buildings leaves little for the people. A player who focuses on the majority can use fewer talents and takes fewer key buildings, and the other way round.

Each building has two dials. **Attractiveness** comes from decoration and from utilities that the residents want, and the utility need not be next to them. It shortens the time buildings inside your influence take to come round, and helps most with demanding people. **Fear** (security) comes from fear rooms. It makes a building resilient against outside forces that would convert or scatter your people, and past a certain amount it leaves residents unable to leave. Fear can hurt attractiveness when it sits next to blocks that dislike it, such as advanced homes. And fear that cannot be kept up, because of unbalanced upkeep, stops working, and the effect carries on.

That is how a demanding luxury building can be taken over without meeting its needs: plan enough fear to keep its people at bay, and spend the time on the win condition. The control way leans on fear. The freedom way leans on attractiveness and welfare, and takes a real majority.

### The opposition
**City Hall** answers work with inspectors who demand paperwork, and answers every miracle with a form and a fine. **Residents** who cling to what is familiar are slow to come round. The game laughs at the system, never at the people stuck in it. There is no rival cult and no police.

## 3. The first district: the Slums

One district of 97 buildings in nine large blocks, plus the core. The only stage for now.

The player starts with the main **Office** at the edge of the Slums. Buildings are taken one at a time and only next to one you hold. A block of eight to thirteen buildings has one **key building**, nine in all, except the Office's own block. When all the ordinary buildings of a block are yours the block is complete: followers come to it faster and inspectors do not audit it.

### People
Followers are a number per building, in one pool. A building has room by its rooms, starts half full when taken and fills by itself, and no building is ever empty. People work where they live. **Clerks** at desks make **paperwork**; **sellers** in shops make **money**, and each further seller in a shop brings less and is paid the same, so only those worth their pay are taken on. A follower with no role is only counted.

### Reps
A **Rep** is trained at the Office from one follower for 30 paperwork. Only Reps work on buildings, two at a time, one more per Training Room. A Rep at a door fills the building's bar and stays on as its **Manager**, so every building costs a Rep. The bar fills by the building's size and the Reps at the door, twice as fast under the hand. Inside a complete or half-won block, the neighbours of your buildings fill slowly by themselves and then only need a Rep.

### Winning
The district is won with 80% of its key buildings (control), or 30% of them together with 60% of the district's people (freedom). The district's people are your followers plus the residents of every building not yours, so real growth means more buildings.

## 4. Rooms: the vertical plan

Each building of yours is a grid you can plan, like a dollhouse.

A building is a grid of bays and floors. An empty place is a plain flat for one follower, so planning can be ignored. Rooms are shapes fitted in for money and sometimes paperwork, and can be turned. Every floor has one stairs place that nothing fits over; the stairs climb two floors and then change column. Some rooms must touch another (an Archive a Desk Room; a Vault and a Stock Room a shop), and a room leaned on cannot be taken out. More floors, by decree, add rows. There are fourteen kinds of room.

Paperwork and money stop at what the Archives and Vaults hold, 150 and $1,200 with none. Some rooms cost money a minute: the Guard Room, the Stock Room, the Laundry Room, the Slums' utility. When it cannot be paid, the dearest room closes until there is money again. The Slums offer only basic homes (Family Flat, Row Flat), so the puzzle is in the offices. A **loan** at the Office turns paperwork into money now, paid back from the takings.

## 5. Exposure, inspectors and the Fixer

The one brake on the player, and the one way into a key building.

Reps at work, buildings taken and the Fixer's actions raise **exposure**, which fades. Inspectors leave the nearest key building for a Rep's door, and above 35% exposure also for a building of yours. When one arrives he demands paperwork: with none, the Rep is sent home or the building is lost. The hand can lift and throw an inspector; he gets up and walks again, and gives up after two and a half minutes. More exposure means more of them at once. Guard Rooms make audits cheaper, and **Bury the File** at the Office spends paperwork to lower exposure, a little dearer each time.

### Key buildings and special talents
A key building demands that you manage special talents. You break into it, and then you can perform actions with it. The actions need money and paperwork and raise attention to you. Training these talents needs a special Training Room. The Fixer is the first talent, trained at the Office for 80 paperwork, one at a time.

Opening a key building takes three actions at its door, each 40 paperwork, 40 seconds and +7 exposure, and 12 paperwork a minute while the Fixer stands there. Once open, a Rep takes it like any other building. A key building you have taken becomes a new office: it makes much-needed paperwork, trains special talents, brings special upkeeps and special moves for taking more key buildings, and sends no more inspectors.

Each key building has its own three actions with their own jokes: at the landlord's office the Fixer forges a lease, at the post office he loses a form. At every door he chooses a quiet way (slower, +3 exposure per action) or a loud way (fast, +12). Inspectors do not chase him: his exposure and his paperwork cost already punish him.

## 6. Divine powers

Faith: the slowest resource, and the one that asks the most of the people in a building.

Miracles are paid for in **faith**, a third resource beside paperwork and money. Faith comes only from a **Shrine**, a room with a demanding shape that must sit in a building with enough followers living in it, has an upkeep, and produces more slowly than anything else. So the god's powers are tied to the buildings and people the player has planned, and there is no separate stock to wait for.

Divine powers help the player cheat a little. They act on hostile forces, chiefly inspectors, and on the physical world. They never move the bureaucracy: a power never takes a building, fills the bar or cancels a notice. City Hall answers every use with a form and a $150 fine, which gives money that sits at its ceiling a use.

The hand and the powers divide the work. The hand carries an inspector away for seconds, and it should feel like Sisyphus: each throw makes him get up sooner, so a player who only uses the hand is always busy. A power buys minutes: it is what the player reaches for to give themselves some time. The first five:

- **A yawn** sends the inspectors in range to sleep for a minute.
- **Every phone rings at once** and the inspectors of a block stop to answer for 45 seconds.
- **A smell of fresh bread** makes a block's followers work a fifth harder for two minutes.
- **A rain of frogs** turns inspectors on foot back for a minute.
- **A block party** doubles a block's money for a minute and a half.

## 7. The city, in seven stages

One city, seven districts, each a stage, each harder than the last. A later stage is harder by its numbers (residents, buildings, reactions), never by new rules.

1. **Slums**: the cult's home. Cheap to win, poor in everything but time.
2. **Workers**: factory and shift workers with just enough to lose.
3. **Students**: a university quarter. Curious, broke and hard to keep.
4. **Gentrification**: old tenants and new money share one street.
5. **Tourism and nightlife**: crowds that never sleep and never stay.
6. **Financial**: towers of money and sceptics, guarded by police.
7. **Old civic district**: City Hall. Win it and the city is yours.

Pacing is slow on purpose: minutes and hours, never seconds, and nothing pauses by itself (Space is the player's own pause). For now the work is the Slums alone, and the first target is ten good opening minutes, not a full stage.

## 8. The faces in the street

Eight kinds of resident give each district its look. They are faces, not mechanics: they have no needs and no traits of their own.

| | Slums | Workers | Students | Gentrification | Nightlife | Financial | Old civic |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Homeless | X | | | | | | |
| Blue collar | X | X | | | | | |
| Student | | | X | X | | | |
| Bohemian | | | | X | X | | |
| Pink collar | | | | | X | X | |
| Clubber | | | | | X | | |
| Pensioner | | | | | | X | X |
| White collar | | | | | | X | X |

The Slums hold only homeless and blue collar people. Each later district brings new people and drops others.

## 9. Decided, not yet built

- **The planner as a doll's house.** Double click a building of yours: the camera goes to its front, the background blurs, and the furnished rooms show in a simple isometric view. Room colours by kind: blue homes, red fear, yellow shops, purple offices; the strength of the colour is the level.
- **The block system.** Shapes get harder as blocks get more advanced: basic blocks are 1, 2 or 3 in a row; advanced are L, S, T and 4 in a row; luxury are plus, C, 2 by 3, 3 by 2 with a tail and 4 high. Basic blocks house simple people and give basic income. Advanced ones must sit near some blocks or away from others (an advanced home dislikes a basic home or a utility; a storage room belongs by a shop, an archive by an office), so price, upkeep, space and fit form the difficulty curve. Advanced homes want a level, and an elevator on their floors in place of the stairs; an advanced shop wants an energy block; the most advanced residents want a boiler, a gym and a laundry in the building.
- **Wider buildings.** A bigger, wider building has more blocks but takes longer to convert, which is riskier and trickier. Adding a floor adds a row and costs more money and paperwork each time.
- **The utility rule.** Utility blocks cost money, paperwork or both a minute. When you cannot keep up, the utility is shut and the blocks that depend on it take a hit to income, or their residents lose faith because comfort is unmet, and eventually leave. A shut utility opens again when the income is balanced.
- **Upkeep in full**: utilities that also cost paperwork; dependents who earn less or leave when a utility is closed.
- **Outside decoration**: switchable inside the planner view. Click and drag locks an item under each window (flowers, camera, air conditioner), for tiny, capped bonuses that cost a little money. They help attractiveness or protect the building from hostile forces.
- **Dictating one plan** to similar buildings.
- **Stamp and tear**: the hand's two verbs, your own rules in place of City Hall's, or no rules.
- **Missions** that give special coins, optional bonuses that push the player's style: operations (the Fixer opens a set of buildings without being noticed) and dilemmas (an extreme believer to restrain, channel or fling away with a dry remark).

## 10. Starting numbers

Every number is provisional and lives in the game's data files, so it can change without touching code. 30 paperwork to train a Rep; 80 to train the Fixer; 40 paperwork and 40 seconds per Fixer action; inspectors also go for buildings from 35% exposure; 150 paperwork and $1,200 are the ceilings with no Archive or Vault; no time limits on a stage.

Paperwork is the short resource: Reps, the Fixer, inspectors and Bury the File all draw on it, while money is plentiful unless Vaults and rooms are bought. The first district is the shortest and teaches the game; later districts grow toward three to four hours.

## 11. Parked for later districts

The old tables of traits, assets and believer needs per resident kind are parked on the Designer's page. The current game does not use them; later districts may bring them back.

## 12. Left out

Landmarks, murals and the Vandalist; awareness, heat, police and arrests; complaints, condemnation and the bulldozer; seats and debt; needs and traits per person; street conversion; abandoned buildings; the upgrade wheel; a good and evil meter; three worlds; the end-of-world backstory; the creature; lifting trees; plague and bedbugs; conversion by miracle; a rival cult.

## 13. The rules as built (the Programmer's)

- **Map.** One district, the Slums: 97 buildings in nine large blocks (8 to 13 buildings) plus the core. Every block but the Office's own has one key building (nine in all). Buildings are taken one at a time, only next to one you hold. A block whose ordinary buildings are all yours is complete: followers come to it faster and inspectors don't audit it.
- **Followers are a number per building**, one pool. A building has room by its rooms; taken, it starts half full and fills by itself. No building is ever empty.
- **People work where they live.** Roles fill themselves: clerks at desks (paperwork), sellers in shops (money; each further seller in a shop brings less and is paid the same, so only those worth their pay are taken on). A building puts to work no more than it houses. A follower with no role is only counted.
- **Reps.** Trained at the Office from one follower for 30 paperwork. Two may be out at once, one more per Training Room; a Manager no longer counts. Only Reps work on buildings; the Secretary stays at the Office.
- **Taking a building.** "Send a Rep" from the wheel, or set a Rep down at its door. The bar fills by the building's size and the Reps at the door, twice as fast under the hand (the god's attention; training too). Inside a block the neighbours of your buildings fill slowly by themselves and then only need a Rep. A lost building keeps 60% of its bar.
- **Rooms (the vertical plan).** A building is a grid of bays and floors. An empty place is a plain flat for one follower, so planning can be ignored. Rooms are shapes fitted in for money and sometimes paperwork, and can be turned. Every floor has one stairs place that nothing fits over; the stairs climb two floors and then change column. Some rooms must touch another (an Archive a Desk Room; a Vault and a Stock Room a shop), and a room leaned on can't be taken out. More floors (a decree, paperwork and money) add rows. The Slums offer the basic homes only (Family Flat, Row Flat); the puzzle is in the offices. Fourteen kinds in `data/rooms.tres`.
- **Ceilings.** Paperwork and money stop at what the Archives and Vaults hold (150 and $1,200 with none).
- **Upkeep.** Some rooms cost money a minute (Guard Room, Stock Room, the Laundry Room, the Slums' utility). When it can't be paid the dearest closes until there is money again.
- **A loan** at the Office: paperwork for money now, paid back from the takings or at once by the money miracle's banknotes.
- **Exposure and inspectors.** Reps at work, buildings taken and the Fixer's actions raise exposure; it fades. Inspectors leave the nearest key building for a Rep's door, and past 35% exposure also for a building of yours. One who arrives demands paperwork: with none, the Rep is sent home or the building is lost. The hand can lift and throw him; he gets up and walks again, and gives up after two and a half minutes. More exposure, more of them at once. Guard Rooms make audits cheaper. "Bury the File" at the Office spends paperwork to lower exposure, dearer each time.
- **Key buildings and the Fixer.** A Rep can't take a key building until the Fixer (trained at the Office, 80 paperwork, one at a time) has opened it: three actions at its door, each 40 paperwork, 40 seconds and +7 exposure, and 12 paperwork a minute while he stands there. Open, a Rep takes it like any other; yours, it is an office (desks, archive, vault, training room) and sends no more inspectors.
- **Winning the district.** 80% of the key buildings (control), or 30% of them and 60% of the district's people (freedom). The district's people are your followers plus the residents of every building not yours; followers you make room for count in the total too, so real growth means more buildings.
- **Pause** is the player's own (Space); the hand, the wheels and the room editor go on working. Nothing pauses by itself.
- **Names on screen**: Member, Rep (a Manager once in a building), Clerk, the Secretary, the Fixer, the Committee.


Not built yet from the page: faith and the Shrine (four old miracles still cost paperwork), the five divine powers, the Fixer's quiet and loud ways, special talents beyond the Fixer, and everything in section 9.
