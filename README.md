# Superb

A clean menu bar for **World of Warcraft: Forever**, in the style of the macOS menu bar. Superb puts the things you check all day along one thin strip at the top or bottom of the screen, and moves the rest of the interface out of its way.

Clock, gold, bags, durability, latency and location are always one glance away. Levelling characters get XP per hour, time to level and an honest split of active and idle time. Hunters get their pet's mood, health and food, with one click to feed.

> **Status: pre-release.** Superb is in testing and has not been published yet.

## Features

- **A real menu bar.** The bar sits at the top or bottom of the screen and the whole interface moves down (or up) to make room, so nothing hides behind it.
- **Five themes.** Default Light, Default Dark, Minimal, Tooltip and Vanilla, from a modern translucent look to the classic gold-on-dark style.
- **Arrange it your way.** Shift+drag any item between the left, centre and right of the bar. Superb remembers where everything goes.
- **Turn anything off.** Every item, tooltip section and notification can be switched off.
- **Quiet notifications.** Short, silent cards drop from the bar for new mail, full bags, worn armour, level-ups and your pet.
- **Light.** No libraries, no options window to learn: everything is in the bar's right-click menu.

## Items

| Item | On the bar | In the tooltip | Click |
|---|---|---|---|
| Clock | Date and time, local or realm | Local time, realm time, session length | Left: calendar |
| Gold | Your gold | This session's change, each of your characters on the realm, total | |
| Bag value | What your bags are worth | Vendor value, junk, auction value, most valuable items | |
| Bag space | Free slots | Free slots per bag | Left: open bags |
| Durability | Your most worn item, orange under 50%, red under 25% | Every damaged item | |
| Performance | Frame rate and latency | Home and world latency, network, addon memory | |
| Location | Zone and coordinates, in the centre | Zone, area, coordinates | Left: world map |
| Level and XP | Level, XP and rested XP | XP, rested XP, time on this level, quest share, recent levels | |
| XP per hour | Rate and time to the next level | Last 15 minutes, session, all time, recent sessions | |
| Next milestone | Time to your next milestone level | Every milestone with XP and time needed | |
| Activity | Active, idle and AFK time | The split in time and percent | |
| XP line | A thin XP line along the bar's edge, with rested XP shaded | | |
| Hunter pet | Portrait, name, level, mood, health and food, with a health line | Family, mood and damage, loyalty, diet, food, pet XP, training points | Left: Feed Pet. Right: Mend Pet |

Right-click any item for its own options. The hunter pet uses Shift+right-click instead, because its right-click casts Mend Pet.

### Levelling

- **Active time** is any movement, turning, casting, combat, click or XP gain in the last 60 seconds (30 seconds to 5 minutes). **AFK** comes from the game's AFK flag. Everything else is **idle**.
- **XP per hour** counts active time only, so a break does not ruin your rate. The "all time" rate shows what breaks cost you.
- **Sessions survive `/reload`** and breaks of up to 30 minutes (5 minutes to 8 hours). The last 20 sessions are kept.
- **Milestones** default to levels 10, 20, 25, 30, 40, 50 and 60, and can be changed. XP for levels you have not reached yet is an estimate, marked `~`, until Superb has seen them.
- Each character keeps a history of every level: time, active time, XP from quests and deaths.
- Type `/played` once in a session to add played time to the tooltip. Superb never asks the game for it, so your chat stays clean.

### Hunter pet

- Shown for hunters only, at the left of the bar.
- **Feed Pet** picks the lowest level food in your bags within 10 levels of your pet, or the highest level food if you prefer. Superb asks the game which items your pet eats, so it works with every food.
- **Clicks** can each be set to Feed Pet, Mend Pet or nothing.
- **Warnings:** pet unhappy, food running low (under 3, 5, 10 or 20), loyalty up, pet died.

### Notifications

New mail, bags full, repair needed, level-up summaries and the four pet warnings. Each kind can be turned off under **Notifications** in the Superb menu, and **Show a test notification** previews the current theme.

## Install

1. Download Superb and unzip it.
2. Copy the `Superb` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
3. Start the game, or type `/reload` if it is running, and make sure Superb is on in the AddOns list.

Superb is built for WoW: Forever (interface 16001).

## Use

- **Menu:** click "Superb" at the left end of the bar, or right-click any empty part of it. Position, theme, items, notifications and "Reset item positions" are all there.
- **Move an item:** hold Shift and drag it. A marker shows where it will land.
- **Item options:** right-click the item (Shift+right-click for the hunter pet).

| Command | Does |
|---|---|
| `/superb top` | Puts the bar at the top of the screen |
| `/superb bottom` | Puts the bar at the bottom |
| `/superb theme <name>` | Sets a theme: `defaultLight`, `defaultDark`, `minimal`, `tooltip`, `vanilla` |
| `/superb reset` | Back to the default position and theme |
| `/superb debug` | Prints the bar's position, for bug reports |

## Good to know

- **Combat.** The game does not let addons move the interface in combat, so a position change made in combat applies when combat ends. The hunter pet item keeps its size and place in combat for the same reason.
- **Pet health in combat** is hidden from addons as a number. The health line still shows it, and the number shows whenever the game allows it.
- **Bag value** uses auction prices from the AuctionDB addon when it is installed, and vendor prices otherwise.
- **Mend Pet** is cast by its English name, so the right-click works on English clients for now.

## Settings and saved data

Settings, item positions and the gold of each character you play are saved in `SuperbDB`. Levelling history and sessions are saved per character in `SuperbLevellingDB`. Nothing leaves your computer.

## For addon authors

Other addons can put their own items on the bar. Add `## Dependencies: Superb` to your TOC, then:

```lua
Superb:RegisterModule({
  id = "myaddon.hello",          -- unique
  name = "Hello",                -- shown in the Modules menu
  side = "right",                -- "left", "centre" or "right"
  order = 60,                    -- lower is nearer the edge
  events = { "PLAYER_MONEY" },   -- the item refreshes after each event
  Text = function(widget) return "Hello" end,  -- nil hides the item
  Tooltip = function(widget, tooltip) tooltip:AddLine("Hello from my addon") end,
  OnClick = function(widget, button) print("Clicked with " .. button) end,
  Menu = function(widget, root) root:CreateTitle("Hello") end,
})

Superb:RegisterNotification("myaddon.done", "Hello finished")  -- players can turn it off
Superb:Notify("myaddon.done", "Hello", "Something happened.")
```

The full list of module fields, including `tick`, `OnRefresh` and secure items that cast spells, is at the top of the "Module API" section in [`Superb/Core.lua`](Superb/Core.lua).

## Development

The tests run outside the game with Lua 5.4, against a small stub of the game's API:

```
luac5.4 -p Superb/*.lua Superb/Modules/*.lua Superb/Modules/*/*.lua
for t in tests/*_test.lua; do lua "$t"; done
```

The stub is not the game: anything it cannot copy is tested in game before a release. Agent rules for this repo are in [`AGENTS.md`](AGENTS.md).

## Licence

[MIT](LICENSE). Copyright 2026 Adam K Dean.
