# Godministration: Game Design Document

The repo's copy of the Designer's page (https://claude.ai/artifact/3SbaznH5KKjxk2jop61iBf), which is the source: owned by the Game Designer thread, with Eilam as Creative Director. Synced from the page's v38 on 2026-11-15. The last section, "The rules as built", is the Programmer's and says what the game does today (Pre-Alpha 0.22.2); where the two differ in a number, the build is the newer one.

Working title (formerly Spin Cycle). PC, Godot 4, toy-like 3D with tilt-shift. The god's hand is a white cloth glove and is the whole interface.

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

Two dials decide how you grow. **Attractiveness** is a requirement, not a bonus. Every ordinary building has a conversion threshold, and a Rep can only convert it once your attractiveness in its area reaches that threshold. The player sees the attractiveness level and the threshold. Every building you convert raises the threshold for the rest, so each step is a little harder than the last. Attractiveness comes from rooms that serve the residents (good homes, the utilities they want, even when not adjacent), and it also lets your residents work at full output. The first buildings need none, and the meter appears at about the third building, so the opening teaches it.

**Fear** is power. Fear rooms (the Guard Room first) help the player cope with the consequences of the Fixer's actions and make him more efficient. Outside decorations help protect against the problems the city sends, and the player pays for that instead of for attractiveness. Space is the price: the bays given to fear rooms are not homes, so they cost residents, and the player chooses between rooms that add power and rooms that add attractiveness. Fear that is not kept up, because upkeep is unpaid, stops working.

Opened key buildings need no attractiveness. The Fixer's way in is the control way and skips the threshold; the freedom way has to climb it.

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

The player plants the Fixer in a building, the way a Rep is set down at a door. A wheel menu then lets the player choose the Fixer's actions. Every action costs exposure and paperwork and gives progress on the conversion side, the key building's bar. Above a certain exposure the Fixer cannot act at all, so the player has to let things calm down or deal with the consequences.

This is a small game of balance. The player can work with small actions that raise little but must be done more often, with short breaks to let exposure fade, or with intensive actions that leave consequences to deal with. Divine powers (faith) can ease the situation or help cope with the consequences. Bury the File at the Office, paid in paperwork, is the other way to calm things down.

Actions on the wheel range from quiet (small progress, little exposure) to loud (big progress, a lot of exposure), so the control and freedom choice happens again at small scale. Once the bar is full the key building is open, and a Rep takes it like any other building. A key building you have taken becomes a new office: it makes much-needed paperwork, trains special talents, brings special upkeeps and special moves for taking more key buildings, and sends no more inspectors.

Each key building has its own set of actions with their own jokes: at the landlord's office the Fixer forges a lease, at the post office he loses a form. A loud action sends an inspector out from another key building, and if there is no paperwork for him the Fixer is sent back and the bar loses 30%. A quiet action costs 20 paperwork and $20, adds 3% exposure and fills 15% of the bar; a loud one costs 60 paperwork and $60, adds 12% and fills 45%. Each action takes 30 seconds, and the 70% exposure gate applies. A key building the Fixer leaves slowly loses its bar, so the player cannot park paperwork in quiet actions far away and stop taking buildings.

## 6. Divine powers

Faith: the slowest resource, and the one that asks the most of the people in a building.

Miracles are paid for in **faith**, a third resource beside paperwork and money. Faith comes only from a **Shrine**, a room with a demanding shape that must sit in a building with enough followers living in it, has an upkeep, and produces more slowly than anything else. So the god's powers are tied to the buildings and people the player has planned, and there is no separate stock to wait for.

The Shrine sits in the **first building the player takes**, which makes faith the learning curve of the opening. A building with an altar can hold no shop and no office, so the player needs a separate building for those.

Divine powers help the player cheat a little. They act on hostile forces, chiefly inspectors, and on the physical world. They never move the bureaucracy: a power never takes a building, fills the bar or cancels a notice. City Hall answers every use with a form and a $150 fine, which gives money that sits at its ceiling a use.

The hand and the powers divide the work. The hand carries an inspector away for seconds, and it should feel like Sisyphus: each throw makes him get up sooner, so a player who only uses the hand is always busy. A power buys minutes: it is what the player reaches for to give themselves some time. The first five:

- **A yawn** sends the inspectors in range to sleep for a minute.
- **Every phone rings at once** and the inspectors of a block stop to answer for 45 seconds.
- **A smell of fresh bread** makes a block's followers work a fifth harder for two minutes.
- **A rain of frogs** turns inspectors on foot back for a minute.
- **A block party** doubles a block's money for a minute and a half.

## 7. The city, in seven stages

One city, seven districts, each a stage, each harder than the last. A later stage is harder by its numbers (residents, buildings, reactions), never by new rules.

1. **Slums**: The cult's home. Cheap to win, poor in everything but time.
2. **Workers**: Factory and shift workers with just enough to lose.
3. **Students**: A university quarter. Curious, broke and hard to keep.
4. **Gentrification**: Old tenants and new money share one street.
5. **Tourism and nightlife**: Crowds that never sleep and never stay.
6. **Financial**: Towers of money and sceptics, guarded by police.
7. **Old civic district**: City Hall. Win it and the city is yours.

Pacing is slow on purpose: minutes and hours, never seconds, and nothing pauses by itself (Space is the player's own pause). For now the work is the Slums alone, and the first target is ten good opening minutes, not a full stage.

## 8. The faces in the street

Eight kinds of resident give each district its look. They are faces, not mechanics: they have no needs and no traits of their own.

### Who lives where

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

## 10. The first ten minutes

One new thing at a time, never two. The existing next-step line guides it.

1. **Minute 0 to 1: the minute**: The Secretary reads a short minute: the god applied to be recognised and was refused, a form was missing. One line says what to do: take the first building. The first time only, and skippable.
2. **Minute 1 to 3: the first building**: The first Rep is trained free, and only one. Set at the neighbour's door, the bar fills, and the hand makes it twice as fast. The hand's first verb is setting down. The building you win holds the Shrine.
3. **Minute 3 to 5: the planner**: A double click on the Office opens the planner and offers one desk room. Skipping it changes nothing, since an empty place is a plain flat. The second building is taken by minute five, and the third shows the attractiveness meter for the first time, with its threshold.
4. **Minute 5 to 7: the inspector**: The first inspector demands paperwork. The hand lifts and throws him, and he comes back. The hand's second verb is throwing, and it never solves anything for good. This is where the player learns what exposure is.
5. **Minute 7 to 10: the key building**: One closed key building shows in the block. The player trains the Fixer for 80 paperwork and uses the wheel, one quiet and one loud action, with exposure nearing the gate. The ten minutes end without a win and with a clear goal: one key building of nine.

By minute ten the player has taken three to five buildings, thrown at least one inspector, trained a Rep and the Fixer, seen the planner once and knows what comes next. Divine powers and the Shrine are not part of the ten minutes; faith is the slowest resource, and the first building only makes room for it.

## 11. Starting numbers

Every number is provisional and lives in the game's data files, so it can change without touching code. The bot with no hand holds about 42% of the bar and one key building of nine after an hour.

30 paperwork to train a Rep; 80 paperwork to train the Fixer; 40 paperwork and 40 seconds per Fixer action; inspectors also go for buildings from 35% exposure; 150 paperwork and $1,200 are the ceilings with no Archive or Vault; no time limits on a stage.

Paperwork is the short resource: Reps, the Fixer, inspectors and Bury the File all draw on it, while money is plentiful unless Vaults and rooms are bought. The first district is the shortest and teaches the game; later districts grow toward three to four hours.

## 12. Parked for later districts

These tables were part of the old design. The current game does not use them, but later districts may bring back traits and needs. The tables of traits, assets and believer needs per resident kind are on the Designer's page.

## 13. Left out

Decided against, and gone from the game: landmarks, murals and the Vandalist; awareness, heat, police and arrests; complaints, condemnation and the bulldozer; seats and debt; needs and traits per person; street conversion; abandoned buildings; the upgrade wheel; a good and evil meter; three worlds; the end-of-world backstory; the creature; lifting trees; plague and bedbugs; conversion by miracle; a rival cult.

## 14. The rules as built (the Programmer's)

What Pre-Alpha 0.22.2 does. Numbers live in `data/*.tres`.

- **Map.** One district, the Slums: 97 buildings in nine large blocks (8 to 13 buildings) plus the core. Every block but the Office's own has one key building (nine in all). Buildings are taken one at a time, only next to one you hold. A block whose ordinary buildings are all yours is complete: followers come to it faster, its buildings cost half the upkeep, and inspectors don't audit it.
- **The opening.** The Secretary's minute shows on the first run only (Close the minutes). One Rep waits by the Office, free. The mission card follows the first ten minutes: take the first building, plan the Office, throw the inspector, train the Fixer, open a key building, then "Key buildings: 1 of 9". The first inspector comes after 5 minutes.
- **Followers are a number per building**, one pool. A building has room by its rooms; taken, it starts half full and fills by itself. No building is ever empty.
- **People work where they live.** Roles fill themselves: clerks at desks (paperwork), sellers in shops (money; each further seller in a shop brings less and is paid the same, so only those worth their pay are taken on). A building puts to work no more than it houses. A follower with no role is only counted.
- **Reps.** Trained at the Office from one follower for 30 paperwork. Two may be out at once, one more per Training Room; a Manager no longer counts. Only Reps work on buildings; the Secretary stays at the Office.
- **Taking a building.** "Send a Rep" from the wheel, or set a Rep down at its door. The bar fills by the building's size and the Reps at the door, twice as fast under the hand (the god's attention; training too). Inside a block the neighbours of your buildings fill slowly by themselves and then only need a Rep. A lost building keeps 60% of its bar.
- **Attractiveness** (the gate on ordinary buildings). One number per district: the Office 10, every other building of yours 1, each Laundry Room (the Slums' utility) 5. The first two ordinary buildings are free; the m-th needs 2 x (m - 2). Short of it, Send a Rep refuses with the reason and what to do ("attractiveness 14 of 18: fit a Laundry Room ($210)", or take a loan when it can't be afforded), and a full bar waits at the door. The meter shows at the bottom left from the third building. Key buildings skip it; a lost building lowers the threshold.
- **Rooms (the vertical plan).** A double click on a building of yours opens its rooms (the first time on the Office only the Desk Room is offered). A building is a grid of bays and floors. An empty place is a plain flat for one follower, so planning can be ignored. Rooms are shapes fitted in for money and sometimes paperwork, and can be turned. Every floor has one stairs place that nothing fits over; the stairs climb two floors and then change column. Some rooms must touch another (an Archive a Desk Room; a Vault and a Stock Room a shop), and a room leaned on can't be taken out. More floors (a decree, paperwork and money) add rows. The Slums offer the basic homes only (Family Flat, Row Flat); the puzzle is in the offices. Fourteen kinds in `data/rooms.tres`.
- **Ceilings.** Paperwork and money stop at what the Archives and Vaults hold (150 and $600 with none).
- **Upkeep.** Every building of yours costs $4 a minute (half in a complete block), scaled by the money in hand: nothing at $0, all of it from $250, so a Committee short of money can always save up for a Laundry Room. Some rooms cost money a minute in full (Guard Room, Stock Room, the Laundry Room). When that can't be paid the dearest room closes until there is money again.
- **A loan** at the Office: paperwork for money now, paid back from the takings or at once by the money miracle's banknotes.
- **Exposure and inspectors.** Reps at work, buildings taken and the Fixer's actions raise exposure; it fades. Inspectors leave the nearest key building for a Rep's door, and past 35% exposure also for a building of yours. One who arrives demands paperwork: with none, the Rep is sent home or the building is lost. The hand can lift and throw him; he gets up and walks again, and gives up after two and a half minutes. More exposure, more of them at once. Guard Rooms make audits cheaper. "Bury the File" at the Office spends paperwork to lower exposure, dearer each time.
- **Key buildings and the Fixer.** A Rep can't take a key building until the Fixer (trained at the Office, 80 paperwork, one at a time) has opened it. Set him down at any key building, or choose Send the Fixer on its wheel. At the door, its wheel offers that building's own three actions with their jokes (`data/fixer.tres`): two quiet (20 paperwork, $20, +3% exposure, 15% of the bar) and one loud (60 paperwork, $60, +12%, 45%), 30 seconds each, faster under the hand. A loud one sends an inspector to his door from another key building: with no paperwork for him, the Fixer goes back to the Office and the bar loses 30%. From 70% exposure he starts nothing. While he is elsewhere a bar falls back 2% a minute. A Guard Room in any building of yours covers for him: 20% less exposure from his actions, 15% of the bar lost instead of 30%. A full bar opens the building; a Rep takes it like any other, and yours, it is an office (desks, archive, vault, training room) that sends no more inspectors.
- **Winning the district.** 80% of the key buildings (control), or 30% of them and 60% of the district's people (freedom). The district's people are your followers plus the residents of every building not yours; followers you make room for count in the total too, so real growth means more buildings.
- **Pause** is the player's own (Space); the hand, the wheels and the room editor go on working. Nothing pauses by itself.
- **Names on screen**: Member, Rep (a Manager once in a building), Clerk, the Secretary, the Fixer, the Committee.
- **Pace.** The bot (`tests/pace_sim`, gate and hand, no loans) wins the Slums in 78 to 86 minutes.

Not built yet from the page: faith and the Shrine (four old miracles still cost paperwork), the five divine powers, special talents beyond the Fixer, fear rooms beyond the Guard Room's two effects, and everything in section 9.
