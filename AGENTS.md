# AGENTS.md

Rules for anyone, human or coding agent, who changes Superb. Read it before changing code.

## What this repo is

Superb is one World of Warcraft addon for **WoW: Forever**: a menu bar along the top or bottom of the screen, with modules.

- Superb is **one addon**. A new feature is a module inside `Superb/Modules/`, never a second addon.
- The default branch is `master`.

## Layout

```
Superb/                    the addon, shipped as-is into Interface/AddOns
  Superb.toc               ## Interface: 16001 first; lists every file in load order
  Format.lua               pure text helpers (Superb.Format)
  Arrange.lua              pure drop-zone logic for moving items (Superb.Arrange)
  Themes.lua               bar themes
  Core.lua                 bar, module API, layout, UI offset, menus, slash command
  Notify.lua               notifications API and the mail notification
  Modules/*.lua            core items: clock, gold, bags, durability, performance, location
  Modules/Levelling/       levelling items (Stats.lua is pure)
  Modules/Hunter/          hunter pet item (Pet.lua is pure)
  Sounds/                  notification chimes (OGG Vorbis, 44.1 kHz, levelled to match)
tests/                     Lua 5.4 tests, run from the repo root
  lib/check.lua            assertion helper
  lib/wowmock.lua          game stub
  *_test.lua               one file per area; all_test.lua loads the whole addon in TOC order
docs/
  GUIDE.md                 the player guide: every item, setting and command
  DEVELOPMENT.md           module API example, layout, tests
  readme/                  README pictures
  art/                     logo and emblem masters
.pkgmeta                   what the release zip holds (BigWigs packager)
.github/workflows/
  ci.yml                   every push: Lua 5.1 syntax, tests, a dry-run zip
  release.yml              a v* tag: CI, then the zip to GitHub, CurseForge and Wago
```

Saved variables: `SuperbDB` (account: settings, positions, gold per character) and `SuperbLevellingDB` (per character: levels, sessions).

## The client

| Fact | Value |
|---|---|
| Game | World of Warcraft: Forever |
| TOC `## Interface` | `16001` |
| Engine and API | Mainline (retail 12.x, Midnight) with Classic game rules: hunter pet happiness, loyalty and training points exist (`C_PetInfo`) |

Consequences:

- Midnight addon restrictions apply. Unit health and some unit values are **secret** in combat. Never compare, concatenate, format or truth-test a value that may be secret; check `issecretvalue(v)` first. Widgets (status bars, font strings) accept secret values.
- Use the modern APIs (`C_Item`, `C_Container`, `C_Spell`, `C_PetInfo`). Classic globals are absent or unreliable unless Blizzard's own Forever code calls them (for example `GetInventoryItemDurability`, `GetPetExperience`, `HasNewMail`).
- Registering an event the client lacks throws. Wrap registration in `pcall`.
- `ReloadUI()` is protected. Players type `/reload`.

## Evidence rules

- **Never guess an API name.** Every function, event, field, texture or frame name must be one seen in a file. Sources, strongest first:
  1. The Blizzard UI source for the exact build: `git clone --depth 1 --branch forever https://github.com/Gethe/wow-ui-source.git` into a directory outside this repo. API docs are in `Interface/AddOns/Blizzard_APIDocumentationGenerated/`; Forever overrides are in `Camelot/` folders.
  2. Names compiled into the game client (`strings` on the client binary). A string proves a name exists, not that it works.
  3. Other addons that already run on Forever.
- Mark anything not seen in a file as uncertain in a comment, and say how to check it in game.

## Rules that keep Superb safe

- Superb moves UIParent by the bar height. The bar hangs on `WorldFrame`, not on UIParent's edge. Never change UIParent's anchors in combat; Core defers to `PLAYER_REGEN_ENABLED` and repairs the offset every second.
- Saved variables load after the files run. Bind them on `ADDON_LOADED`, never at file load.
- An item that casts spells is a secure module (`secure = true`, attributes in `Setup`). Never move, resize, show, hide or set attributes on it in combat; Core queues those. Shift+left on it is `ATTRIBUTE_NOOP` (moving), Shift+right opens its menu.
- No automation: no casting loops, no movement, no world clicks. A spell is cast only from the player's own click on a secure button.
- The only sounds are the notification chimes in `Sounds/`, one per type (info, good, warning, bad), and **Play sounds** turns them all off. Give every new notification kind the type that matches its news. Never add any other sound.
- Never read or change another addon's files or saved variables. Read another addon's data only through its global API, in one place, with a version check (see the AuctionDB adapter in `Modules/Bags.lua`).

## Testing

```
luac5.4 -p Superb/*.lua Superb/Modules/*.lua Superb/Modules/*/*.lua
for t in tests/*_test.lua; do lua "$t"; done
```

- A test stubs only the API it needs and exits non-zero on failure. Write the failing test first for a bug.
- `wowmock.lua` raises an error when an addon changes a secure frame in combat. It cannot copy the game's error for a truth test on a secret value, so a test that feeds a secret checks `M.secretChecks`.
- A mock test is not a game test. Anything the stub cannot copy is checked in game before a release; give exact steps (slash commands, what to look for, `/superb debug`).
- Plant a bug in a scratch copy to prove a new test can fail.

## Releases

- The [BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip from `.pkgmeta`: one `Superb/` folder with the addon, `LICENSE` and a changelog made from the commits since the last tag. It replaces `@project-version@` in the TOC with the tag.
- Every push to `master` runs CI and keeps the zip as a workflow artifact. Test a release candidate from that zip, not from the repo.
- To release, tag `master` and push the tag: `git tag -a v0.2.0 -m v0.2.0 && git push origin v0.2.0`. A tag with `alpha` or `beta` in it makes an alpha or beta file.
- An upload runs only when its project ID is in the TOC (`## X-Curse-Project-ID`, `## X-Wago-ID`) and its token is a repo secret (`CF_API_TOKEN`, `WAGO_API_TOKEN`). The GitHub release needs no setup.
- Never tag a build that has not been tested in game.

## Commits and docs

- Conventional, atomic commits with a one-line subject.
- Docs are matter-of-fact: no em dashes, no first person.
- The README sells Superb to players: logo, badges, a short pitch, the feature grid and install. Details go in `docs/GUIDE.md` (players) and `docs/DEVELOPMENT.md` (addon authors and contributors). Every claim in any of them must match the code.
- README pictures live in `docs/readme/` and stay small (JPEG or WebP). Full-size art masters live in `docs/art/`.
