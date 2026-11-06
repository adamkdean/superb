<div align="center">

<img src="docs/readme/logo.webp" alt="Superb" width="560">

**A heads-up display for World of Warcraft: Forever, in one bar.**<br>
Your gold, bags, XP rate, gear and pet, live along the edge of your screen while you play.

![Status: pre-release](https://img.shields.io/badge/status-pre--release-c9a227?style=flat-square) ![WoW: Forever](https://img.shields.io/badge/WoW-Forever-1f4e8c?style=flat-square) ![Interface 16001](https://img.shields.io/badge/interface-16001-555555?style=flat-square) ![Lua](https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white) ![Libraries: none](https://img.shields.io/badge/libraries-none-4a7a32?style=flat-square) ![Licence: MIT](https://img.shields.io/badge/licence-MIT-6b6b6b?style=flat-square)

</div>

Superb is a bar that runs along the top or bottom of your screen and keeps the numbers you care about up to date: what you're carrying, how fast you're levelling, how worn your gear is and how your pet is doing. The rest of your interface shifts over to make room, so nothing hides behind it. Glance at it mid-fight, hover an item for the full picture, right-click it for options. There is no settings window to learn.

<table>
<tr>
<td width="112"><img src="docs/readme/glance.jpg" width="96" alt=""></td>
<td>

**The things you keep checking**<br>
The time, local or realm. Your zone and coordinates, your most worn piece of gear, your frame rate and latency. Click the clock for the calendar, or the zone for the map.

</td>
</tr>
<tr>
<td width="112"><img src="docs/readme/gold.jpg" width="96" alt=""></td>
<td>

**Gold and bags**<br>
Your gold, what you made this session, and the total across your characters on the realm. Free bag slots, and what your bags would fetch: auction prices if you run AuctionDB, vendor prices if you don't.

</td>
</tr>
<tr>
<td width="112"><img src="docs/readme/levelling.jpg" width="96" alt=""></td>
<td>

**Levelling you can trust**<br>
XP per hour only counts the time you spend playing, so a cup of tea won't drag the number down. You also get time to level, time to your next milestone and a record of every level, and your session carries over a <code>/reload</code>.

</td>
</tr>
<tr>
<td width="112"><img src="docs/readme/pet.jpg" width="96" alt=""></td>
<td>

**A happy pet**<br>
Hunters see their pet's mood, health and food on the bar. Left-click feeds it the right food from your bags, and right-click casts Mend Pet. Superb warns you when your pet turns unhappy or the food runs low.

</td>
</tr>
<tr>
<td width="112"><img src="docs/readme/themes.jpg" width="96" alt=""></td>
<td>

**Yours to arrange**<br>
Five themes, from crisp light and dark to the game's own gold on dark. Hold <kbd>Shift</kbd> and drag any item to the left, centre or right of the bar, and switch off whatever you don't use.

</td>
</tr>
<tr>
<td width="112"><img src="docs/readme/notifications.jpg" width="96" alt=""></td>
<td>

**Quiet notifications**<br>
Small cards drop from the bar for new mail, full bags, worn gear, level-ups and your pet. They never make a sound, and each one goes away after a few seconds.

</td>
</tr>
</table>

More items are on the way. Want something on your bar? [Request a feature](https://github.com/adamkdean/superb/issues/new?labels=feature). Found a bug? [Report it](https://github.com/adamkdean/superb/issues/new?labels=bug).

## Install

> Superb is still in testing and has no release yet.

At release, Superb will be on CurseForge and Wago, so WowUp or the CurseForge app can install it and keep it up to date. To install it by hand:

1. Download Superb and unzip it.
2. Put the `Superb` folder in `World of Warcraft/_forever_/Interface/AddOns/`.
3. Start the game, or type `/reload` if it is already running.

The bar appears at the top of the screen. Click **Superb** at its left end for the menu.

## More

- [The guide](docs/GUIDE.md) covers every item, setting and command.
- [Developing Superb](docs/DEVELOPMENT.md) shows addon authors how to put their own items on the bar, and how to run the tests.

## Licence

[MIT](LICENSE). Copyright 2026 Adam K Dean.
