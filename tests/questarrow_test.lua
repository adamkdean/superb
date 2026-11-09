-- Mock test for quest arrows: a bobbing arrow on the nameplate of each unit an active quest needs.
-- Not a game test. Run from the repo root: lua tests/questarrow_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

S.cvars.nameplateShowEnemies = false -- off at first, to test the hint

M.load("Superb", M.QUEST_FILES, M.load("Superb", M.CORE_FILES))
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")

local def
for _, d in ipairs(Superb.modules) do if d.id == "questarrow" then def = d end end
check.ok("module registered", def ~= nil)
check.eq("named for the Modules menu", def.name, "Quest arrows")
check.eq("no bar text", def.widget:IsShown(), false)

-- With enemy nameplates off, one hint in chat, once per account.
local function hints()
  local n = 0
  for _, line in ipairs(M.printed) do if line:find("nameplates", 1, true) then n = n + 1 end end
  return n
end
check.eq("hint when nameplates are off", hints(), 1)
check.eq("hint remembered", SuperbDB.modules.questarrow.hinted, true)
Superb:SetEnabled(def, false)
Superb:SetEnabled(def, true)
check.eq("hint not repeated", hints(), 1)
S.cvars.nameplateShowEnemies = true

-- Nameplates appear: only the quest unit gets an arrow.
local plate1, plate2 = CreateFrame("Frame"), CreateFrame("Frame")
S.nameplates = { nameplate1 = plate1, nameplate2 = plate2 }
S.questUnits = { nameplate1 = true }
local function arrowsOn(plate)
  local list = {}
  for _, f in ipairs(M.frames) do if f.parent == plate then list[#list + 1] = f end end
  return list
end
local function arrowOn(plate) return arrowsOn(plate)[1] end
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
local a1 = arrowOn(plate1)
check.ok("arrow on the quest unit", a1 ~= nil and a1.shown)
check.eq("no arrow on the other unit", arrowOn(plate2), nil)

-- The arrow: Blizzard's tutorial pointer at its size, above the nameplate, bobbing.
check.eq("size", a1.width .. "x" .. a1.height, "64x64")
check.eq("above the nameplate", a1.points.BOTTOM.rel, plate1)
check.eq("anchored to its top", a1.points.BOTTOM.relPoint, "TOP")
local atlases = {}
for _, t in ipairs(M.textures) do if t.parent == a1 then atlases[#atlases + 1] = t.atlas end end
check.eq("arrow and glow art", table.concat(atlases, ","), "NPE_ArrowDown,NPE_ArrowDownGlow")
check.eq("bobs", a1.bob.playing, true)
check.eq("up and down", a1.bob.looping, "BOUNCE")
check.eq("a few pixels", a1.bob.anims[1].offset[2], -6)

-- Quest progress: QUEST_LOG_UPDATE checks every nameplate again.
S.questUnits = { nameplate2 = true }
M.fire("QUEST_LOG_UPDATE")
check.eq("done unit loses its arrow", a1.shown, false)
check.eq("its bob stops", a1.bob.playing, false)
local a2 = arrowOn(plate2)
check.ok("newly needed unit gets one", a2 ~= nil and a2.shown)

-- A nameplate goes away, and the game reuses its frame for a unit no quest needs.
M.fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
check.eq("arrow goes with the nameplate", a2.shown, false)
M.fire("QUEST_LOG_UPDATE") -- nameplate2 is still a quest unit, but has no nameplate now
check.eq("a removed unit stays without one", a2.shown, false)
S.nameplates.nameplate3 = plate2
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check.eq("reused frame, no arrow", a2.shown, false)
check.eq("one arrow per nameplate frame", #arrowsOn(plate2), 1)

-- A forbidden nameplate (no frame for addons) is skipped.
S.questUnits.nameplate4 = true
M.fire("NAME_PLATE_UNIT_ADDED", "nameplate4")

-- Turned off under Modules: every arrow hides; on again: they come back.
S.questUnits = { nameplate1 = true }
M.fire("QUEST_LOG_UPDATE")
check.eq("arrow back", a1.shown, true)
Superb:SetEnabled(def, false)
check.eq("off hides arrows", a1.shown, false)
M.fire("QUEST_LOG_UPDATE")
check.eq("stays hidden while off", a1.shown, false)
Superb:SetEnabled(def, true)
check.eq("on shows them again", a1.shown, true)

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
