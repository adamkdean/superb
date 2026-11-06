-- Loads the whole addon in TOC order, as the game does, for a hunter with a pet: every module registers, and
-- every item, tooltip and menu works together without an error. Not a game test.
-- Run from the repo root: lua tests/all_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

local toc = M.tocFiles("Superb")
check.eq("toc lists every file", table.concat(toc, ","), table.concat(M.ALL_FILES, ","))

S.class = "HUNTER"
S.pet = { name = "Temporary", level = 10, family = "Tallstrider", happiness = 3, damage = 125, rate = 0,
  loyalty = "Unruly", hp = 268, hpMax = 283, dead = false, xp = 100, xpNeed = 400, diet = { "Fruit" }, eats = {} }
M.load("Superb", toc)
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")
M.tick(5)

local ids = {}
for _, def in ipairs(Superb.modules) do ids[#ids + 1] = def.id end
table.sort(ids)
check.eq("modules", table.concat(ids, ","), "bags,bagvalue,clock,durability,gold,hunter.pet,levelling.activity,"
  .. "levelling.milestone,levelling.rate,levelling.xp,levelling.xpline,location,notifications,performance,superb")
check.ok("one saved table per character", type(SuperbLevellingDB) == "table")

for _, def in ipairs(Superb.modules) do
  local w = def.widget
  if def.Tooltip and w:IsShown() then
    w.scripts.OnEnter(w)
    check.ok("tooltip " .. def.id, #GameTooltip.lines > 0)
    w.scripts.OnLeave(w)
  end
  if w.secure then
    M.shift = true
    w.scripts.PostClick(w, "RightButton", false)
    M.shift = false
  else
    w.scripts.OnClick(w, "RightButton")
  end
  check.ok("menu " .. def.id, M.find(M.menu, "Theme") ~= nil)
end

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
