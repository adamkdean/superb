-- Mock test for the professions item: icon and rank per profession, the tooltip, the menu and skill-ups.
-- Not a game test. Run from the repo root: lua tests/professions_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

-- Slot 2 (the second primary) is empty: GetProfessions leaves gaps for professions not learnt.
S.professions = {
  [1] = { name = "Herbalism", icon = 111, rank = 150, max = 225, skillLine = 182 },
  [3] = { name = "Cooking", icon = 333, rank = 75, max = 150, skillLine = 185 },
}

M.load("Superb", M.CORE_FILES)
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")

local w, def
for _, d in ipairs(Superb.modules) do if d.id == "professions" then w, def = d.widget, d end end
local function icon(id) return ("|T%d:16:16:0:0:64:64:5:59:5:59|t"):format(id) end
local function tip()
  w.scripts.OnEnter(w)
  local text = table.concat(GameTooltip.lines, "\n")
  w.scripts.OnLeave(w)
  return text
end

check.eq("icon and rank for each, past the gap", w.text, icon(111) .. " 150  " .. icon(333) .. " 75")
check.eq("on the left", Superb:Side(def), "left")
check.ok("tooltip title", tip():find("Professions", 1, true) ~= nil)
check.ok("tooltip rank and cap", tip():find("Herbalism = 150 / 225", 1, true) ~= nil)
check.ok("tooltip secondary", tip():find("Cooking = 75 / 150", 1, true) ~= nil)

-- A skill-up refreshes the item.
S.professions[1].rank = 151
M.fire("SKILL_LINES_CHANGED")
check.eq("skill-up shown", w.text, icon(111) .. " 151  " .. icon(333) .. " 75")

-- The menu picks which show; the choice is saved by skill line, and the tooltip still lists them all.
w.scripts.OnClick(w, "RightButton")
check.eq("menu title", M.menu.children[1].label, "Professions")
check.eq("cooking ticked", M.find(M.menu, "Cooking").selected, true)
M.find(M.menu, "Cooking").select()
check.eq("cooking off the bar", w.text, icon(111) .. " 151")
check.eq("saved by skill line", Superb:ModuleDB("professions").hidden[185], true)
check.ok("tooltip keeps it", tip():find("Cooking = 75 / 150", 1, true) ~= nil)
w.scripts.OnClick(w, "RightButton")
check.eq("cooking unticked", M.find(M.menu, "Cooking").selected, false)

-- With every profession unticked, the item stays on the bar by name, so its menu can bring them back.
M.find(M.menu, "Herbalism").select()
check.eq("all unticked: name only", w.text, "Professions")
w.scripts.OnClick(w, "RightButton")
M.find(M.menu, "Cooking").select()
check.eq("ticked again", w.text, icon(333) .. " 75")
check.eq("unsaved when ticked again", Superb:ModuleDB("professions").hidden[185], nil)

-- Secondary skills only: both primary slots are empty.
S.professions = { [3] = { name = "Cooking", icon = 333, rank = 75, max = 150, skillLine = 185 } }
M.fire("SKILL_LINES_CHANGED")
check.eq("secondary only", w.text, icon(333) .. " 75")

-- No professions: no item.
S.professions = {}
M.fire("SKILL_LINES_CHANGED")
check.eq("hidden with none", w:IsShown(), false)

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
