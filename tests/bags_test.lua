-- Mock test for special bags: one item per kind of bag (ammo, soul, herb), shown only while one is equipped.
-- Not a game test. Run from the repo root: lua tests/bags_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

local function item(id, count, icon, link)
  return { itemID = id, stackCount = count, iconFileID = icon, hyperlink = link, quality = 1, isBound = false, hasNoValue = false }
end
-- Bag families: any value but 0 is a special bag. The bag item's class and subclass say which kind.
S.itemInstant = {
  [50] = { subType = "Quiver", icon = 5000, classID = 11, subClassID = 2 },
  [60] = { subType = "Soul Bag", icon = 6000, classID = 1, subClassID = 1 },
  [70] = { subType = "Herb Bag", icon = 7000, classID = 1, subClassID = 2 },
}
S.bags[2] = { slots = 16, family = 1, bagItem = 50, items = { item(40, 200, 4000, "[Rough Arrow]"), item(40, 150, 4000, "[Rough Arrow]") } }
S.bags[3] = { slots = 20, family = 4, bagItem = 60, items = { item(41, 1, 4100, "[Soul Shard]"), item(41, 1, 4100, "[Soul Shard]"), item(41, 1, 4100, "[Soul Shard]") } }
S.bags[4] = { slots = 24, family = 32, bagItem = 70, items = { item(42, 2, 4200, "[Silverleaf]"), item(43, 20, 4300, "[Peacebloom]"), item(43, 20, 4300, "[Peacebloom]") } }
S.ammo = { icon = 4000, count = 400 } -- the equipped arrows, counted in every bag (the game's number)
for _, id in ipairs({ 40, 41, 42, 43 }) do S.sellPrice[id] = 1 end

M.load("Superb", M.CORE_FILES)
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")

local function find(id)
  for _, def in ipairs(Superb.modules) do if def.id == id then return def.widget, def end end
end
local function icon(id) return ("|T%d:16:16:0:0:64:64:5:59:5:59|t"):format(id) end
local function tip(w)
  w.scripts.OnEnter(w)
  local text = table.concat(GameTooltip.lines, "\n")
  w.scripts.OnLeave(w)
  return text
end

-- The items appear a frame after login, once the bags are read.
check.eq("not yet registered", find("bags.ammo"), nil)
M.runTimers()
local ammo, ammoDef = find("bags.ammo")
local soul, soulDef = find("bags.container1")
local herb = find("bags.container2")
check.ok("ammo item", ammo ~= nil)
check.eq("named by the game's bag type", soulDef.name, "Soul Bag")
check.eq("ammo name", ammoDef.name, "Ammo")
check.eq("next to bag space", ammoDef.order, 41)

-- Bar text: ammo is a count with the ammo's icon; other bags are used/total slots with the commonest item's icon.
check.eq("ammo count", ammo.text, icon(4000) .. " 400")
check.eq("soul shards", soul.text, icon(4100) .. " 3/20")
check.eq("herb bag, icon of the commonest herb", herb.text, icon(4300) .. " 3/24")
check.eq("bag space still general bags only", find("bags").text:match("(%d+) free$"), "7")

-- Tooltips.
check.ok("ammo tooltip: equipped ammo and count", tip(ammo):find("[Item0] = 400", 1, true) ~= nil)
check.ok("ammo tooltip: quiver slots", tip(ammo):find("Bag2 = 2 / 16 used", 1, true) ~= nil)
check.ok("herb tooltip: contents, most first", tip(herb):find("[Peacebloom] = 40\n[Silverleaf] = 2", 1, true) ~= nil)
check.ok("herb tooltip: bag slots", tip(herb):find("Bag4 = 3 / 24 used", 1, true) ~= nil)

-- Ammo changes: a new ammo type in the slot refreshes at once; shooting refreshes with the bags.
S.ammo.count = 1200
M.fire("PLAYER_EQUIPMENT_CHANGED")
check.eq("ammo slot change", ammo.text, icon(4000) .. " 1,200")
S.ammo.count = 1199
M.fire("BAG_UPDATE_DELAYED")
M.runTimers()
check.eq("ammo used", ammo.text, icon(4000) .. " 1,199")

-- No ammo in the slot: zero, with the quiver's own icon.
S.ammo = nil
M.fire("PLAYER_EQUIPMENT_CHANGED")
check.eq("no ammo", ammo.text, icon(5000) .. " 0")
check.ok("no ammo tooltip", tip(ammo):find("No ammo in the ammo slot.", 1, true) ~= nil)

-- An empty bag shows the bag's own icon.
S.bags[3].items = {}
M.fire("BAG_UPDATE_DELAYED")
M.runTimers()
check.eq("empty soul bag", soul.text, icon(6000) .. " 0/20")

-- Take the quiver off: its item goes. Put it back: it returns, without a second item.
local quiver = S.bags[2]
S.bags[2] = nil
M.fire("BAG_UPDATE_DELAYED")
M.runTimers()
check.eq("quiver gone", ammo:IsShown(), false)
S.bags[2] = quiver
M.fire("BAG_UPDATE_DELAYED")
M.runTimers()
check.eq("quiver back", ammo:IsShown(), true)
local n = 0
for _, def in ipairs(Superb.modules) do if def.id == "bags.ammo" then n = n + 1 end end
check.eq("registered once", n, 1)

-- Each can be turned off like any item.
Superb:SetEnabled(soulDef, false)
check.eq("soul item off", soul:IsShown(), false)

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
