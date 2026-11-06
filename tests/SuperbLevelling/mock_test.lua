-- Mock test for addons/SuperbLevelling on top of Superb: load order, saved data, XP flow, level-ups, activity,
-- milestones, tooltips and menus. Not a game test. Run from the repo root: lua tests/SuperbLevelling/mock_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

check.eq("toc files", table.concat(M.tocFiles("SuperbLevelling"), ","), table.concat(M.LEVELLING_FILES, ","))

M.load("Superb", M.SUPERB_FILES)
local ns = M.load("SuperbLevelling", M.LEVELLING_FILES)
local Superb, Stats = _G.Superb, ns.Stats

-- Saved data from an earlier session: level 22 took 3000 XP, custom milestones, 30 s idle.
SuperbDB = nil
SuperbLevellingDB = { levels = { [22] = { active = 3000, idle = 600, afk = 0, xp = 3000, questXP = 1000, deaths = 1,
  started = 1, finished = 2 } }, xpMax = { [22] = 9000 }, milestones = { [25] = true, [30] = true }, idleAfter = 30 }
M.fire("ADDON_LOADED", "Superb")
M.fire("ADDON_LOADED", "SuperbLevelling")
check.eq("idle setting applied", Stats.ACTIVE_WINDOW, 30)
M.fire("PLAYER_LOGIN")
check.eq("saved levels kept", SuperbLevellingDB.levels[22].xp, 3000)
check.eq("current level xp recorded", SuperbLevellingDB.xpMax[23], 10000)
check.ok("current level record", SuperbLevellingDB.levels[23] ~= nil)

local function widget(id)
  for _, def in ipairs(Superb.modules) do if def.id == id then return def.widget end end
end
local xpW, rateW, msW, actW = widget("levelling.xp"), widget("levelling.rate"), widget("levelling.milestone"), widget("levelling.activity")

check.eq("xp text", xpW.text, "Lv 23 · 40% · 15% rested")
check.eq("rate measuring", rateW.text, "XP/h: measuring")
check.ok("milestone before a rate shows xp", msW.text:find("^Lv 25: ~") ~= nil)

-- 10 minutes of moving, 500 XP every minute: 3000 XP/h... at 5000 XP in 600 s active -> 30k/h.
S.moving = true
for _ = 1, 10 do
  M.tick(60)
  S.xp = S.xp + 500
  M.fire("PLAYER_XP_UPDATE", "player")
end
check.eq("rate shown", rateW.text, "30k xp/h · 2m to 24")
check.ok("activity text", actW.text:find("^Active 10m") ~= nil)
check.eq("record active", SuperbLevellingDB.levels[23].active, 600)
check.eq("record xp", SuperbLevellingDB.levels[23].xp, 5000)

-- Stop moving: idle after 30 s.
S.moving = false
M.tick(90)
check.eq("idle counted", SuperbLevellingDB.levels[23].idle, 60)
check.ok("activity shows idle", actW.text:find("Idle 1m", 1, true) ~= nil)

-- AFK flag (and a secret AFK value in chat lockdown) counts as AFK, not idle, without an error.
S.afk = true
M.tick(30)
S.afk = "SECRET"
local checksBefore = M.secretChecks
M.tick(30)
check.ok("secret AFK checked before use", M.secretChecks > checksBefore)
check.eq("afk counted, secret keeps last value", SuperbLevellingDB.levels[23].afk, 60)
check.ok("afk shown on bar", actW.text:find("AFK 1m", 1, true) ~= nil)
S.afk = false

-- Quest XP and a level-up where XP wraps before the level changes.
M.fire("QUEST_TURNED_IN", 123, 800, 100)
S.xp = 9900
M.fire("PLAYER_XP_UPDATE", "player")
S.xp, S.xpMax = 200, 11000
M.fire("PLAYER_XP_UPDATE", "player")
M.fire("PLAYER_LEVEL_UP", 24)
S.level = 24
M.fire("PLAYER_XP_UPDATE", "player")
check.eq("level 23 xp", SuperbLevellingDB.levels[23].xp, 5900 + 100)
check.eq("level 24 xp", SuperbLevellingDB.levels[24].xp, 200)
check.ok("level 23 finished", SuperbLevellingDB.levels[23].finished ~= nil)
check.eq("level 24 max recorded", SuperbLevellingDB.xpMax[24], 11000)
check.eq("quest xp recorded", SuperbLevellingDB.levels[23].questXP, 800)
check.eq("xp text after level", xpW.text:match("^Lv 24"), "Lv 24")

-- Milestone: level 25 is the next level, so the bar shows 30.
check.ok("milestone skips next level", msW.text:find("^Lv 30") ~= nil)

-- Deaths and /played.
M.fire("PLAYER_DEAD")
check.eq("death recorded", SuperbLevellingDB.levels[24].deaths, 1)
M.fire("TIME_PLAYED_MSG", 86400, 120)

-- Tooltips render with every line formatted.
for _, w in ipairs({ xpW, rateW, msW, actW }) do
  w.scripts.OnEnter(w)
  check.ok("tooltip " .. w.def.id, #GameTooltip.lines > 2)
  for _, l in ipairs(GameTooltip.lines) do check.ok("no nil in " .. w.def.id .. ": " .. l, not l:find("nil", 1, true)) end
  w.scripts.OnLeave(w)
end
xpW.scripts.OnEnter(xpW)
local joined = table.concat(GameTooltip.lines, "\n")
check.ok("played this level", joined:find("Played (from /played)", 1, true) ~= nil) -- captured at level 24, so shown
xpW.scripts.OnLeave(xpW)

-- Menus.
msW.scripts.OnClick(msW, "RightButton")
M.find(M.menu, "Level 40").select()
check.eq("milestone added", SuperbLevellingDB.milestones[40], true)
M.find(M.menu, "Level 30").select()
check.eq("milestone removed", SuperbLevellingDB.milestones[30], nil)
actW.scripts.OnClick(actW, "RightButton")
M.find(M.menu, "2m").select()
check.eq("idle window saved", SuperbLevellingDB.idleAfter, 120)
check.eq("idle window applied", Stats.ACTIVE_WINDOW, 120)
M.find(M.menu, "Reset session").click()
check.eq("session reset", actW.text, "Active 0s · Idle 0s")

-- At the level cap the rate and milestone items hide.
S.level, S.maxLevel = 60, 60
M.tick()
check.eq("cap xp text", xpW.text, "Lv 60 · max")
check.eq("cap hides rate", rateW:IsShown(), false)
check.eq("cap hides milestone", msW:IsShown(), false)

-- XP turned off.
S.level = 30
S.xpDisabled = true
M.tick()
check.eq("xp off", xpW.text, "Lv 30 · XP off")

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
