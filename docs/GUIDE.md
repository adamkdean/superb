# Superb guide

Everything Superb puts on the bar, what each item tells you, and how to set it up. For install steps, see the [README](../README.md).

## Using the bar

| Do this | To |
|---|---|
| Click **Superb** at the left end of the bar | Open the menu: position, theme, items, notifications |
| Right-click an empty part of the bar | Open the same menu |
| Right-click an item | Open that item's own options |
| <kbd>Shift</kbd> + drag an item | Move it to the left, centre or right of the bar. A marker shows where it lands |
| <kbd>Shift</kbd> + right-click the hunter pet | Open the pet's options (its plain right-click casts Mend Pet) |

**Reset item positions** in the menu puts every item back where it started.

## Items

| Item | On the bar | In the tooltip | Click |
|---|---|---|---|
| Clock | Date and time, local or realm | Local time, realm time, session length | Left: calendar |
| Gold | Your gold | This session's change, each of your characters on the realm, total | |
| Bag value | What your bags are worth | Vendor value, junk, auction value, most valuable items | |
| Bag space | Free slots | Free slots per bag | Left: open bags |
| Durability | Your most worn item, orange under 50%, red under 25% | Every damaged item | |
| Performance | Frame rate and latency | Home and world latency, network, addon memory | |
| Location | Zone and coordinates, first of the right-hand items | Zone, area, coordinates | Left: world map |
| Level and XP | Level, XP and rested XP | XP, rested XP, time on this level, quest share, recent levels | |
| XP per hour | Rate and time to the next level | Last 15 minutes, session, all time, recent sessions | |
| Next milestone | Time to your next milestone level | Every milestone with XP and time needed | |
| Activity | Active, idle and AFK time | The split in time and percent | |
| XP line | A thin XP line along the bar's edge, blue while rested and purple when not, with rested XP shaded | | |
| Hunter pet | Portrait, name, level, mood, health and food | Family, mood and damage, loyalty, diet, food, pet XP, training points | Left: Feed Pet. Right: Mend Pet |

Every item, and every section of each tooltip, can be turned off.

## Levelling

- **Active time** is any movement, turning, casting, combat, click or XP gain in the last 60 seconds. You can set the window from 30 seconds to 5 minutes. **AFK** comes from the game's AFK flag. Everything else counts as **idle**.
- **XP per hour** counts active time only, so a break does not drag your rate down. The "all time" rate shows what the breaks cost.
- **Sessions survive `/reload`**, and breaks of up to 30 minutes (you can set 5 minutes to 8 hours). Superb keeps your last 20 sessions.
- **Milestones** default to levels 10, 20, 25, 30, 40, 50 and 60, and you can change them. For levels you have not reached yet, the XP is an estimate until Superb has seen them, and the tooltip says so.
- Each character keeps a history of every level: time, active time, XP from quests and deaths.
- **Announce level-ups:** right-click **Level and XP** to tell your guild or your group when you level up, for example `(Superb) DING! {star} Level 12! Level 11 took 1h 23m (48m active).` Chat shows `{star}` as the star icon. Each character chooses its own channels, and both are on at first. Guild and group messages go only when you are in one. If Superb started tracking partway through the level, the message leaves out the time.
- **Show XP line** in the same right-click menu turns the XP line on and off. It is the same switch as **XP line** under **Modules**.
- Type `/played` once in a session to add played time to the tooltip. Superb never asks the game for it, so your chat stays clean.

## Hunter pet

- Hunters only. The item sits at the left of the bar.
- **Feed Pet** uses the lowest level food in your bags that is within 10 levels of your pet. You can switch it to the highest level food instead. Superb asks the game which items your pet eats, so any food works.
- Each click can be set to Feed Pet, Mend Pet or nothing.
- **Warnings:** pet unhappy, food running low (under 3, 5, 10 or 20), loyalty up, pet died.

## Notifications

Small cards drop from the bar for new mail, full bags, repairs, level-up summaries and the four pet warnings. Turn each kind on or off under **Notifications** in the menu. **Show a test notification** shows you one in the current theme.

Each card has a type, and each type has its own short, soft chime:

| Type | Sounds like | Cards |
|---|---|---|
| Info | One soft pop | New mail, test cards |
| Good | Two notes going up | Level-up summary, pet loyalty up |
| Warning | The same note twice | Bags full, repair soon, pet unhappy, pet food low |
| Bad | Two low notes going down | Item broken, pet died |

When several cards arrive together, the chime plays once, unless a later card is more serious. Chimes play on the game's master volume. Untick **Play sounds** under **Notifications** to turn them off.

## Commands

| Command | Does |
|---|---|
| `/superb top` | Puts the bar at the top of the screen |
| `/superb bottom` | Puts the bar at the bottom |
| `/superb theme <name>` | Sets a theme: `defaultLight`, `defaultDark`, `minimal`, `tooltip`, `vanilla` |
| `/superb toast` | Shows a test notification in the current theme |
| `/superb toast <type>` | Shows a test notification of one type, with its chime: `info`, `good`, `warning` or `bad` |
| `/superb toast all` | Shows a test notification of every kind that is on (at most 3 at once) |
| `/superb reset` | Back to the default position and theme |
| `/superb debug` | Prints the bar's position, for bug reports |

## Good to know

- **Combat.** The game does not let addons move the interface in combat. If you change the bar's position in combat, the change waits until combat ends. The hunter pet item keeps its size and place in combat for the same reason.
- **Pet health in combat.** The game hides it from addons, so the bar leaves the number out in combat and shows it again when the game allows.
- **Bag value** uses auction prices from the AuctionDB addon if you have it, and vendor prices if you do not.
- **Mend Pet** is cast by its English name, so the right-click works on English clients only for now.

## Saved data

Settings, item positions and the gold of each character you play go in `SuperbDB`. Levelling history and sessions go in `SuperbLevellingDB`, one per character. Nothing leaves your computer.
