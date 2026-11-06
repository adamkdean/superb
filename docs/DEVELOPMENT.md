# Developing Superb

Notes for addon authors who want their own items on the bar, and for anyone working on Superb itself. Contributor rules, client facts and safety rules are in [`AGENTS.md`](../AGENTS.md).

## Adding an item from your own addon

Add `## Dependencies: Superb` to your TOC, then:

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

The full list of module fields, including `tick`, `OnRefresh` and secure items that cast spells, is at the top of the "Module API" section in [`Superb/Core.lua`](../Superb/Core.lua).

## Project layout

```text
Superb/              the addon, shipped as-is into Interface/AddOns
  Core.lua           the bar, module API, layout, menus, slash command
  Modules/           clock, gold, bags, durability, performance, location
  Modules/Levelling/ levelling items
  Modules/Hunter/    hunter pet item
tests/               Lua 5.4 tests and a small stub of the game's API
docs/                this file, the player guide and README pictures
```

## Tests

The tests run outside the game with Lua 5.4, from the repo root:

```sh
luac5.4 -p Superb/*.lua Superb/Modules/*.lua Superb/Modules/*/*.lua
for t in tests/*_test.lua; do lua "$t"; done
```

The stub is not the game. Anything it cannot copy gets tested in game before a release.
