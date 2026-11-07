-- Mock test for the levelling module: saved data, XP flow, level-ups, activity, milestones, sessions, tooltips
-- and menus. Not a game test. Run from the repo root: lua tests/levelling_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

local ns = M.load("Superb", M.CORE_FILES)
M.load("Superb", M.LEVELLING_FILES, ns)
local Superb, Stats = _G.Superb, ns.Stats

-- Saved data from an earlier session: level 22 took 3000 XP, custom milestones, 30 s idle.
SuperbDB = nil
SuperbLevellingDB = { levels = { [22] = { active = 3000, idle = 600, afk = 0, xp = 3000, questXP = 1000, deaths = 1,
  started = 1, finished = 2 } }, xpMax = { [22] = 9000 }, milestones = { [25] = true, [30] = true }, idleAfter = 30 }
M.fire("ADDON_LOADED", "Superb")
check.eq("idle setting applied", Stats.ACTIVE_WINDOW, 30)
M.fire("PLAYER_LOGIN")
check.eq("saved levels kept", SuperbLevellingDB.levels[22].xp, 3000)
check.eq("current level xp recorded", SuperbLevellingDB.xpMax[23], 10000)
check.ok("current level record", SuperbLevellingDB.levels[23] ~= nil)
check.eq("level found part-done is marked", SuperbLevellingDB.levels[23].partial, true)

local function widget(id)
  for _, def in ipairs(Superb.modules) do if def.id == id then return def.widget end end
end
local xpW, rateW, msW, actW = widget("levelling.xp"), widget("levelling.rate"), widget("levelling.milestone"), widget("levelling.activity")

check.eq("xp text", M.plain(xpW.text), "Lv 23 | 40% | 15% rested")

-- XP line: 40% filled, rested shaded to 55%, on the bottom edge of a top bar. Blue while rested, purple when not.
local fill, restedTex
for _, t in ipairs(M.textures) do
  if t.colour and t.colour[4] == 1 and (t.colour[1] == 0.62 or t.colour[1] == 0.25) then fill = t end
  if t.colour and t.colour[4] == 0.55 then restedTex = t end
end
check.ok("xp line textures", fill and restedTex)
check.eq("rested: blue fill", fill.colour[1] .. "," .. fill.colour[2], "0.25,0.55")
S.rested = 0
Superb:Refresh("levelling.xpline")
check.eq("not rested: purple fill", fill.colour[1] .. "," .. fill.colour[2], "0.62,0.36")
S.rested = 1500
Superb:Refresh("levelling.xpline")
check.eq("rested again: blue fill", fill.colour[1], 0.25)
check.eq("xp fill width", fill.width, 400)
check.eq("rested width", restedTex.width, 550)
check.eq("xp line on the inner edge", fill.points.BOTTOMLEFT ~= nil, true)
check.eq("xp line shown", fill.shown, true)
Superb:SetPosition("bottom")
check.eq("xp line moves with the bar", fill.points.TOPLEFT ~= nil, true)
Superb:SetPosition("top")
local lineDef
for _, def in ipairs(Superb.modules) do if def.id == "levelling.xpline" then lineDef = def end end
Superb:SetEnabled(lineDef, false)
check.eq("xp line off", fill.shown, false)
Superb:SetEnabled(lineDef, true)
check.eq("xp line on", fill.shown, true)
-- The Level and XP menu turns the line on and off too.
xpW.scripts.OnClick(xpW, "RightButton")
check.eq("menu: xp line ticked", M.find(M.menu, "Show XP line").selected, true)
M.find(M.menu, "Show XP line").select()
check.eq("menu: xp line off", fill.shown, false)
check.eq("menu: saved like the Modules menu", Superb:IsEnabled(lineDef), false)
xpW.scripts.OnClick(xpW, "RightButton")
check.eq("menu: xp line unticked", M.find(M.menu, "Show XP line").selected, false)
M.find(M.menu, "Show XP line").select()
check.eq("menu: xp line on again", fill.shown, true)
check.eq("rate measuring", rateW.text, "XP/h: measuring")
check.ok("milestone before a rate shows xp", msW.text:find("^Lv 25: ~") ~= nil)

-- 10 minutes of moving, 500 XP every minute: 3000 XP/h... at 5000 XP in 600 s active -> 30k/h.
S.moving = true
for _ = 1, 10 do
  M.tick(60)
  S.xp = S.xp + 500
  M.fire("PLAYER_XP_UPDATE", "player")
end
check.eq("rate shown", M.plain(rateW.text), "30k xp/h | 2m to 24")
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
local card
for _, f in ipairs(M.frames) do if f.strata == "DIALOG" and f.shown then card = f end end
check.eq("level-up card", card and card.title.text, "Level 24")
check.ok("level-up card text", card and card.body.text:find("^Level 23 took 12m %(10m active%)") ~= nil)
check.ok("level-up quest share", card and card.body.text:find("13% of the XP came from quests", 1, true) ~= nil)
check.eq("no guild or group, no announcement", #M.chat, 0)
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
M.find(M.menu, "Start a new session").click()
check.eq("session reset", M.plain(actW.text), "Active 0s | Idle 0s")
check.eq("old session filed", #SuperbLevellingDB.sessions, 1)
check.eq("filed session level", SuperbLevellingDB.sessions[1].levelFrom, 23)

-- At the level cap the rate and milestone items hide.
S.level, S.maxLevel = 60, 60
M.tick()
check.eq("cap xp text", M.plain(xpW.text), "Lv 60 | max")
check.eq("cap hides rate", rateW:IsShown(), false)
check.eq("cap hides milestone", msW:IsShown(), false)
check.eq("cap hides xp line", fill.shown, false)

-- XP turned off.
S.level = 30
S.xpDisabled = true
M.tick()
check.eq("xp off", M.plain(xpW.text), "Lv 30 | XP off")

-- Reload: the session continues with its rates, and no time is counted while the client was down.
S.level, S.xpDisabled, S.xp, S.xpMax = 30, false, 1000, 20000
M.fire("PLAYER_XP_UPDATE", "player") -- the jump from the cap test is not a gain to measure
M.find(M.menu, "Start a new session").click()
S.moving = true
for _ = 1, 5 do
  M.tick(60)
  S.xp = S.xp + 1000
  M.fire("PLAYER_XP_UPDATE", "player")
end
local beforeRate, beforeAct = rateW.text, actW.text
M.fire("PLAYER_LOGOUT")
check.ok("session saved at logout", SuperbLevellingDB.session ~= nil)

local function relaunch(gap)
  M.restart(gap, { SuperbDB = SuperbDB, SuperbLevellingDB = SuperbLevellingDB })
  ns = M.load("Superb", M.CORE_FILES)
  M.load("Superb", M.LEVELLING_FILES, ns)
  Superb = _G.Superb
  M.fire("ADDON_LOADED", "Superb")
    M.fire("PLAYER_LOGIN")
  rateW, actW = widget("levelling.rate"), widget("levelling.activity")
end

relaunch(20)
check.eq("rate kept after reload", rateW.text, beforeRate)
check.eq("activity kept after reload", actW.text, beforeAct)
check.eq("saved session cleared", SuperbLevellingDB.session, nil)
M.tick(5)
check.ok("still active after reload", actW.text:find("^Active 5m") ~= nil)
actW.scripts.OnEnter(actW)
check.ok("tooltip says continued", table.concat(GameTooltip.lines, "\n"):find("Continued after a reload", 1, true) ~= nil)
actW.scripts.OnLeave(actW)

-- A long break: the old session goes into the history and a new one starts.
local filed = #SuperbLevellingDB.sessions
M.fire("PLAYER_LOGOUT")
relaunch(3 * 3600)
check.eq("new session after a long break", M.plain(actW.text), "Active 0s | Idle 0s")
check.eq("old session filed after a break", #SuperbLevellingDB.sessions, filed + 1)
check.eq("filed session xp", SuperbLevellingDB.sessions[1].xp, 5000)
rateW.scripts.OnEnter(rateW)
check.ok("recent sessions listed", table.concat(GameTooltip.lines, "\n"):find("Recent sessions", 1, true) ~= nil)
rateW.scripts.OnLeave(rateW)

-- The break limit is a setting.
actW.scripts.OnClick(actW, "RightButton")
M.find(M.menu, "8h 00m").select()
check.eq("break limit saved", SuperbLevellingDB.resumeAfter, 28800)
M.tick(120)
M.fire("PLAYER_LOGOUT")
relaunch(3 * 3600)
check.ok("kept after 3 h with an 8 h limit", actW.text:find("^Active 2m") ~= nil)

-- Level-up announcements: on by default, turned off per character in the Level and XP menu.
xpW = widget("levelling.xp")
xpW.scripts.OnClick(xpW, "RightButton")
check.eq("guild on by default", M.find(M.menu, "Guild").selected, true)
check.eq("party on by default", M.find(M.menu, "Party or raid").selected, true)
check.eq("no Say option", M.find(M.menu, "Say"), nil)

local function levelUp(level, seconds)
  S.moving = true
  M.tick(seconds)
  M.chat = {}
  M.fire("PLAYER_LEVEL_UP", level)
  S.level = level
  local sent = {}
  for _, c in ipairs(M.chat) do sent[#sent + 1] = c.chatType end
  return table.concat(sent, ",")
end
S.guild, S.group = true, "party"
check.eq("guild and party", levelUp(31, 10), "GUILD,PARTY")
levelUp(32, 3725)
check.eq("ding text", M.chat[1].msg, "(Superb) DING! {star} Level 32! Level 31 took 1h 02m (1h 02m active).")
check.eq("same text everywhere", M.chat[2].msg, M.chat[1].msg)
S.guild, S.group = false, "instance"
check.eq("dungeon group, no guild", levelUp(33, 10), "INSTANCE_CHAT")
S.group = "raid"
check.eq("raid", levelUp(34, 10), "RAID")
S.guild, S.chatLockdown = true, true
check.eq("nothing in chat lockdown", levelUp(35, 10), "")
S.chatLockdown = false
SuperbLevellingDB.levels[35].partial = true
levelUp(36, 10)
check.eq("part-done level: no time", M.chat[1].msg, "(Superb) DING! {star} Level 36!")
S.group = nil
check.eq("alone: guild only", levelUp(37, 10), "GUILD")
S.group = "party"
M.find(M.menu, "Guild").select()
check.eq("guild off saved per character", SuperbLevellingDB.announce.guild, false)
check.eq("guild off", levelUp(38, 10), "PARTY")
M.find(M.menu, "Party or raid").select()
check.eq("all off", levelUp(39, 10), "")
M.find(M.menu, "Guild").select()
check.eq("guild on again", levelUp(40, 10), "GUILD")

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
