-- Superb, levelling module: levelling items for the Superb bar. Level and XP, XP per hour and time to level, the next
-- milestone, and active, idle and AFK time. The maths is in Stats.lua; this file reads the game and saves
-- a per-character history of each level.
local ADDON, ns = ...
local S, F, Stats = Superb, Superb.Format, ns.Stats

local DEFAULTS = { levels = {}, xpMax = {}, idleAfter = 60, sessions = {}, resumeAfter = Stats.RESUME_GAP, announce = {} }
local MILESTONE_CHOICES = { 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 }
local IDLE_CHOICES = { 30, 60, 120, 300 }
local RESUME_CHOICES = { 300, 1800, 7200, 28800 }
local ANNOUNCE_CHOICES = { { key = "guild", label = "Guild" }, { key = "party", label = "Party or raid" } }

-- SavedVariablesPerCharacter load after this file runs, so DB is bound to SuperbLevellingDB on ADDON_LOADED.
local DB = { levels = {}, xpMax = {}, idleAfter = 60, sessions = {}, resumeAfter = Stats.RESUME_GAP, announce = {} }
local session = Stats.NewSession(GetTime())
local xpState
local played          -- { total, level, levelAt, at }: the last TIME_PLAYED_MSG
local lastAFK = false
local IDS = { "levelling.xp", "levelling.rate", "levelling.milestone", "levelling.activity" }

S:RegisterNotification("levelup", "Level-up summary", "good")

local function levelRecord(level)
  local r = DB.levels[level]
  if not r then
    r = { active = 0, idle = 0, afk = 0, xp = 0, questXP = 0, deaths = 0, started = GetServerTime() }
    DB.levels[level] = r
  end
  return r
end

local function isAFK()
  local v = UnitIsAFK("player")
  if issecretvalue and issecretvalue(v) then return lastAFK end
  lastAFK = v and true or false
  return lastAFK
end

local function atCap() return UnitLevel("player") >= GetMaxPlayerLevel() end
local function levelling() return not atCap() and not IsXPUserDisabled() end

local function milestones()
  local list = {}
  if DB.milestones then
    for m in pairs(DB.milestones) do list[#list + 1] = m end
  else
    for _, m in ipairs(Stats.DEFAULT_MILESTONES) do list[#list + 1] = m end
  end
  return list
end

local function rates(now)
  local rxp, ractive = Stats.Rolling(session, now)
  local rolling = Stats.Rate(rxp, ractive)
  local sessionRate = Stats.Rate(session.xp, session.active)
  local wall = Stats.Rate(session.xp, Stats.Online(session))
  return rolling or sessionRate, rolling, sessionRate, wall
end

local function refresh()
  for _, id in ipairs(IDS) do S:Refresh(id) end
end

local function newSession()
  local s = Stats.NewSession(GetTime(), UnitLevel("player"))
  s.startedAt = GetServerTime()
  return s
end

local function resetSession()
  Stats.Archive(DB.sessions, Stats.Summary(session, GetServerTime(), UnitLevel("player")))
  session = newSession()
  refresh()
end

-- At login: continue the saved session after a reload or a short break, else file it and start a new one.
local function loadSession()
  local saved = DB.session
  DB.session = nil
  if saved and saved.savedAt and GetServerTime() - saved.savedAt <= (DB.resumeAfter or Stats.RESUME_GAP) then
    session = Stats.Thaw(saved, GetTime())
    session.resumed = true
    return
  end
  if saved and saved.savedAt then Stats.Archive(DB.sessions, Stats.Summary(saved, saved.savedAt, saved.levelTo)) end
  session = newSession()
end

local function startedText(serverTime)
  local t = date("*t", serverTime)
  return F.Day(t.wday, t.day, t.month) .. " " .. F.Clock(t.hour, t.min, true)
end

local function groupChat()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
end

-- Announces a level-up in the chats the player turned on. No Say: outdoors the server drops an addon's SAY
-- unless a key press or click sent it, with no error (checked in game, 2026-11-07). A channel is on unless
-- the player turned it off (false).
local function announce(level, r)
  local guild, party = DB.announce.guild ~= false, DB.announce.party ~= false
  if not (guild or party) or C_ChatInfo.InChatMessagingLockdown() then return end
  local text = ("(Superb) DING! {star} Level %d!"):format(level)
  if not r.partial then
    text = text .. (" Level %d took %s (%s active)."):format(level - 1, F.Duration(r.active + r.idle + r.afk), F.Duration(r.active))
  end
  if guild and IsInGuild() then C_ChatInfo.SendChatMessage(text, "GUILD") end
  local group = party and groupChat()
  if group then C_ChatInfo.SendChatMessage(text, group) end
end

local function white(tip, left, right) tip:AddDoubleLine(left, right, nil, nil, nil, 1, 1, 1) end
local function hint(tip, text) tip:AddLine(" ") tip:AddLine(text, 0.6, 0.6, 0.6, true) end

-- Events ----------------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

local function on(event, fn, unit)
  local ok = unit and pcall(frame.RegisterUnitEvent, frame, event, unit) or (not unit and pcall(frame.RegisterEvent, frame, event))
  if ok then handlers[event] = fn else print("Superb: event not available: " .. event) end
end

frame:SetScript("OnEvent", function(_, event, ...)
  local fn = handlers[event]
  if fn then fn(...) end
end)

local function signal() Stats.Signal(session, GetTime()) end

local function onXP()
  local now = GetTime()
  local level, xp, mx = UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
  local pendingBefore = xpState.pending
  local gained = Stats.ObserveXP(xpState, level, xp, mx)
  if gained > 0 then
    Stats.AddXP(session, now, gained)
    -- XP wrapped before UnitLevel changed: the part past the wrap belongs to the next level.
    local intoNext = xpState.pending > pendingBefore and math.min(xp, gained) or 0
    local r = levelRecord(level)
    r.xp = r.xp + gained - intoNext
    if intoNext > 0 then
      local n = levelRecord(level + 1)
      n.xp = n.xp + intoNext
    end
  end
  if mx and mx > 0 then DB.xpMax[level] = mx end
  Stats.Signal(session, now)
  refresh()
end

local function startTracking()
  xpState = Stats.NewXP(UnitLevel("player"), UnitXP("player"), UnitXPMax("player"))
  local mx = UnitXPMax("player")
  if mx and mx > 0 then DB.xpMax[UnitLevel("player")] = mx end
  -- A level first seen at login was started before Superb tracked it, so its time is incomplete.
  if not DB.levels[UnitLevel("player")] then levelRecord(UnitLevel("player")).partial = true end

  on("PLAYER_XP_UPDATE", function(unit) if unit == nil or unit == "player" then onXP() end end)
  on("PLAYER_LEVEL_UP", function(level)
    local r = DB.levels[level - 1]
    if r then
      r.finished = GetServerTime()
      local text = ("Level %d took %s (%s active)."):format(level - 1, F.Duration(r.active + r.idle + r.afk), F.Duration(r.active))
      if r.xp > 0 then text = text .. (" %d%% of the XP came from quests."):format(F.Percent(math.min(r.questXP, r.xp), r.xp)) end
      if r.deaths > 0 then text = text .. (" %d %s."):format(r.deaths, r.deaths == 1 and "death" or "deaths") end
      S:Notify("levelup", ("Level %d"):format(level), text)
      announce(level, r)
    end
    levelRecord(level)
    signal()
  end)
  on("QUEST_TURNED_IN", function(_, xpReward)
    xpReward = tonumber(xpReward) or 0
    session.questXP = session.questXP + xpReward
    local r = levelRecord(UnitLevel("player"))
    r.questXP = r.questXP + xpReward
    signal()
  end)
  on("PLAYER_DEAD", function()
    session.deaths = session.deaths + 1
    local r = levelRecord(UnitLevel("player"))
    r.deaths = r.deaths + 1
  end)
  on("PLAYER_LOGOUT", function()
    local f = Stats.Freeze(session, GetTime(), UnitLevel("player"))
    f.savedAt = GetServerTime()
    DB.session = f
  end)
  on("TIME_PLAYED_MSG", function(total, thisLevel)
    played = { total = total, level = thisLevel, levelAt = UnitLevel("player"), at = GetTime() }
  end)
  for _, event in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_STARTED_TURNING", "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED" }) do
    on(event, signal)
  end
  on("UNIT_SPELLCAST_START", signal, "player")
  on("UNIT_SPELLCAST_SUCCEEDED", signal, "player")

  C_Timer.NewTicker(1, function()
    local now = GetTime()
    if IsPlayerMoving() or UnitAffectingCombat("player") then Stats.Signal(session, now) end
    local a, i, k = Stats.Advance(session, now, isAFK())
    local r = levelRecord(UnitLevel("player"))
    r.active, r.idle, r.afk = r.active + a, r.idle + i, r.afk + k
    refresh()
  end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    SuperbLevellingDB = SuperbLevellingDB or {}
    for k, v in pairs(DEFAULTS) do
      if SuperbLevellingDB[k] == nil then SuperbLevellingDB[k] = type(v) == "table" and {} or v end
    end
    DB = SuperbLevellingDB
    Stats.ACTIVE_WINDOW = DB.idleAfter or 60
  elseif event == "PLAYER_LOGIN" then
    loadSession()
    startTracking()
    refresh() -- Superb drew these items before the saved session was loaded
    self:UnregisterAllEvents()
  end
end)

-- Bar items -------------------------------------------------------------------------------------------------
-- No `tick = true`: the ticker above refreshes these items after it has counted the second.

local function sessionMenu(root)
  root:CreateButton("Start a new session", resetSession)
end

S:RegisterModule({
  id = "levelling.xp", name = "Level and XP", side = "left", order = 10,

  Text = function()
    local level = UnitLevel("player")
    if atCap() then return ("Lv %d · max"):format(level) end
    if IsXPUserDisabled() then return ("Lv %d · XP off"):format(level) end
    local xp, mx = UnitXP("player"), UnitXPMax("player")
    local s = ("Lv %d · %d%%"):format(level, F.Percent(xp, mx))
    local rested = GetXPExhaustion()
    if rested and rested > 0 then s = s .. (" · %d%% rested"):format(F.Percent(rested, mx)) end
    return s
  end,

  Tooltip = function(_, tip)
    local level = UnitLevel("player")
    local xp, mx = UnitXP("player"), UnitXPMax("player")
    tip:AddLine(("Level %d"):format(level), 1, 1, 1)
    if levelling() then
      white(tip, "XP", ("%s / %s (%d%%)"):format(F.Thousands(xp), F.Thousands(mx), F.Percent(xp, mx)))
      white(tip, "To level", F.Thousands(mx - xp))
      local rested = GetXPExhaustion()
      white(tip, "Rested", rested and ("%s (%d%% of a level)"):format(F.Thousands(rested), F.Percent(rested, mx)) or "none")
      if IsResting() then tip:AddLine("Resting: rested XP is building.", 0.5, 0.8, 1) end
    end
    local r = levelRecord(level)
    tip:AddLine(" ")
    tip:AddLine("This level", 1, 1, 1)
    white(tip, "Tracked time", F.Duration(r.active + r.idle + r.afk))
    white(tip, "  active", F.Duration(r.active))
    if played and played.levelAt == level then
      white(tip, "Played (from /played)", F.Duration(played.level + GetTime() - played.at))
    end
    if r.xp > 0 then
      local quest = math.min(r.questXP, r.xp)
      white(tip, "XP from quests", ("%s (%d%%)"):format(F.Thousands(quest), F.Percent(quest, r.xp)))
    end
    if r.deaths > 0 then white(tip, "Deaths", tostring(r.deaths)) end
    if played then white(tip, "Total played", F.Duration(played.total + GetTime() - played.at)) end

    local shown = 0
    for l = level - 1, math.max(1, level - 5), -1 do
      local past = DB.levels[l]
      if past and past.finished then
        if shown == 0 then tip:AddLine(" ") tip:AddLine("Recent levels (tracked time, active)", 1, 1, 1) end
        white(tip, ("Level %d"):format(l), ("%s, %s"):format(F.Duration(past.active + past.idle + past.afk), F.Duration(past.active)))
        shown = shown + 1
        if shown == 3 then break end
      end
    end
    if not played then hint(tip, "Type /played once to add played time.") end
    hint(tip, "Right-click: announce level-ups in chat.")
  end,

  Menu = function(_, root)
    root:CreateTitle("Level and XP")
    local chats = root:CreateButton("Announce level-ups")
    local function isOn(key) return DB.announce[key] ~= false end
    local function toggle(key) DB.announce[key] = DB.announce[key] == false end
    for _, c in ipairs(ANNOUNCE_CHOICES) do chats:CreateCheckbox(c.label, isOn, toggle, c.key) end
    -- The same switch as XP line in the Modules menu (XPLine.lua registers it after this file).
    for _, def in ipairs(S.modules) do
      if def.id == "levelling.xpline" then
        root:CreateCheckbox("Show XP line", function() return S:IsEnabled(def) end,
          function() S:SetEnabled(def, not S:IsEnabled(def)) end)
      end
    end
  end,
})

S:RegisterModule({
  id = "levelling.rate", name = "XP per hour", side = "left", order = 20,

  Text = function()
    if not levelling() then return nil end
    local rate = rates(GetTime())
    if not rate then return "XP/h: measuring" end
    local ttl = Stats.TimeFor(UnitXPMax("player") - UnitXP("player"), rate)
    return ("%s xp/h · %s to %d"):format(F.Short(rate), F.Duration(ttl), UnitLevel("player") + 1)
  end,

  Tooltip = function(_, tip)
    local now = GetTime()
    local best, rolling, sessionRate, wall = rates(now)
    local need = UnitXPMax("player") - UnitXP("player")
    local function rateLine(label, rate)
      white(tip, label, rate and (F.Short(rate) .. " xp/h") or "measuring")
    end
    tip:AddLine("XP per hour", 1, 1, 1)
    rateLine(("Last %d minutes, active"):format(Stats.ROLLING_MINUTES), rolling)
    rateLine("This session, active", sessionRate)
    rateLine("This session, all time", wall)
    tip:AddLine(" ")
    tip:AddLine(("Time to level %d"):format(UnitLevel("player") + 1), 1, 1, 1)
    white(tip, "Active play", F.Duration(Stats.TimeFor(need, best)))
    white(tip, "At your session pace", F.Duration(Stats.TimeFor(need, wall)))
    tip:AddLine(" ")
    white(tip, "Session XP", F.Thousands(session.xp))
    if session.xp > 0 then
      local quest = math.min(session.questXP, session.xp)
      white(tip, "  from quests", ("%s (%d%%)"):format(F.Thousands(quest), F.Percent(quest, session.xp)))
      white(tip, "  from kills and other", F.Thousands(session.xp - quest))
    end
    if session.deaths > 0 then white(tip, "Deaths", tostring(session.deaths)) end
    if #DB.sessions > 0 then
      tip:AddLine(" ")
      tip:AddLine("Recent sessions (online, XP per active hour, levels)", 1, 1, 1)
      for i = 1, math.min(5, #DB.sessions) do
        local p = DB.sessions[i]
        local rate = Stats.Rate(p.xp or 0, p.active)
        local levels = p.levelFrom and p.levelTo and p.levelTo ~= p.levelFrom and ("%d to %d"):format(p.levelFrom, p.levelTo)
          or p.levelFrom and ("%d"):format(p.levelFrom) or "?"
        white(tip, p.startedAt and startedText(p.startedAt) or "?",
          ("%s, %s, %s"):format(F.Duration(p.online), rate and F.Short(rate) or "-", levels))
      end
    end
    hint(tip, ("Rates count active time only, except \"all time\". A rate shows after %d minutes of activity."):format(Stats.MIN_SAMPLE / 60))
  end,

  Menu = function(_, root)
    root:CreateTitle("XP per hour")
    sessionMenu(root)
  end,
})

S:RegisterModule({
  id = "levelling.milestone", name = "Next milestone", side = "left", order = 30,

  Text = function()
    if not levelling() then return nil end
    local level = UnitLevel("player")
    -- The next level is already on the XP per hour item, so the bar shows the first milestone after it.
    local target
    for _, m in ipairs(Stats.Upcoming(level, milestones(), GetMaxPlayerLevel())) do
      if m > level + 1 then target = m break end
    end
    if not target then return nil end
    local need, estimate = Stats.XPToReach(level, UnitXP("player"), target, DB.xpMax)
    if not need then return nil end
    local t = Stats.TimeFor(need, (rates(GetTime())))
    local mark = estimate and "~" or ""
    if t then return ("Lv %d in %s%s"):format(target, mark, F.Duration(t)) end
    return ("Lv %d: %s%s xp"):format(target, mark, F.Short(need))
  end,

  Tooltip = function(_, tip)
    local level = UnitLevel("player")
    local rate = rates(GetTime())
    tip:AddLine("Milestones", 1, 1, 1)
    local anyEstimate = false
    for _, target in ipairs(Stats.Upcoming(level, milestones(), GetMaxPlayerLevel())) do
      local need, estimate = Stats.XPToReach(level, UnitXP("player"), target, DB.xpMax)
      if need then
        anyEstimate = anyEstimate or estimate
        local mark = estimate and "~" or ""
        local t = Stats.TimeFor(need, rate)
        white(tip, ("Level %d"):format(target), ("%s%s xp, %s"):format(mark, F.Short(need), t and (mark .. F.Duration(t)) or "time: measuring"))
      end
    end
    if anyEstimate then
      hint(tip, "~ The XP for levels not reached yet is an estimate. Superb records the real values as you level.")
    end
    hint(tip, "Times are active play at your current rate. Right-click: choose milestones.")
  end,

  Menu = function(_, root)
    root:CreateTitle("Milestones")
    local function isOn(m)
      if DB.milestones then return DB.milestones[m] == true end
      for _, d in ipairs(Stats.DEFAULT_MILESTONES) do if d == m then return true end end
      return false
    end
    local function toggle(m)
      if not DB.milestones then
        DB.milestones = {}
        for _, d in ipairs(Stats.DEFAULT_MILESTONES) do DB.milestones[d] = true end
      end
      DB.milestones[m] = (not DB.milestones[m]) or nil
      S:Refresh("levelling.milestone")
    end
    for _, m in ipairs(MILESTONE_CHOICES) do root:CreateCheckbox(("Level %d"):format(m), isOn, toggle, m) end
  end,
})

S:RegisterModule({
  id = "levelling.activity", name = "Active and idle time", side = "left", order = 40,

  Text = function()
    local s = ("Active %s · Idle %s"):format(F.Duration(session.active), F.Duration(session.idle))
    if session.afk >= 60 then s = s .. " · AFK " .. F.Duration(session.afk) end
    return s
  end,

  Tooltip = function(_, tip)
    local now = GetTime()
    local state = Stats.State(session, now, isAFK())
    local total = session.active + session.idle + session.afk
    tip:AddLine("This session", 1, 1, 1)
    white(tip, "Now", state == "active" and "active" or state == "afk" and "AFK" or "idle")
    white(tip, "Active", ("%s (%d%%)"):format(F.Duration(session.active), F.Percent(session.active, total)))
    white(tip, "Idle", ("%s (%d%%)"):format(F.Duration(session.idle), F.Percent(session.idle, total)))
    white(tip, "AFK", ("%s (%d%%)"):format(F.Duration(session.afk), F.Percent(session.afk, total)))
    white(tip, "Session", F.Duration(total))
    if session.startedAt then white(tip, "Started", startedText(session.startedAt)) end
    if session.resumed then tip:AddLine("Continued after a reload or a short break.", 0.5, 0.8, 1) end
    hint(tip, ("Idle starts %d seconds after you last moved, turned, cast, fought or clicked. Right-click: options."):format(Stats.ACTIVE_WINDOW))
  end,

  Menu = function(_, root)
    root:CreateTitle("Active and idle time")
    local idle = root:CreateButton("Idle after")
    local function isIdle(v) return Stats.ACTIVE_WINDOW == v end
    local function setIdle(v) DB.idleAfter = v Stats.ACTIVE_WINDOW = v S:Refresh("levelling.activity") end
    for _, v in ipairs(IDLE_CHOICES) do idle:CreateRadio(F.Duration(v), isIdle, setIdle, v) end
    local keep = root:CreateButton("Keep the session after a break of")
    local function isKeep(v) return (DB.resumeAfter or Stats.RESUME_GAP) == v end
    local function setKeep(v) DB.resumeAfter = v end
    for _, v in ipairs(RESUME_CHOICES) do keep:CreateRadio(F.Duration(v), isKeep, setKeep, v) end
    sessionMenu(root)
  end,
})
