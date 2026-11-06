-- Superb Levelling: activity, XP rate and milestone maths. Pure Lua: no game API, so
-- tests/SuperbLevelling/stats_test.lua runs it outside the game. Times are seconds (GetTime() in game).
local _, ns = ...
local Stats = {}
ns.Stats = Stats

Stats.ACTIVE_WINDOW = 60      -- seconds after the last activity signal that still count as active
Stats.ROLLING_MINUTES = 15    -- rolling rate window
Stats.MIN_SAMPLE = 120        -- active seconds needed before a rate is shown
Stats.DEFAULT_MILESTONES = { 10, 20, 25, 30, 40, 50, 60 }

local floor, max, min = math.floor, math.max, math.min

-- Session -----------------------------------------------------------------------------------------------------

function Stats.NewSession(now)
  return { started = now, last = now, lastSignal = now, activeFrom = now, prevEnd = now,
           active = 0, idle = 0, afk = 0, xp = 0, questXP = 0, deaths = 0, buckets = {} }
end

-- The active window runs from activeFrom to lastSignal + ACTIVE_WINDOW. A signal after a gap starts a new
-- window and keeps the end of the old one (prevEnd), so time between two Advance calls is split correctly.
function Stats.Signal(s, now)
  if now <= s.lastSignal then return end
  if now > s.lastSignal + Stats.ACTIVE_WINDOW then
    s.prevEnd = s.lastSignal + Stats.ACTIVE_WINDOW
    s.activeFrom = now
  end
  s.lastSignal = now
end

function Stats.State(s, now, afk)
  if afk then return "afk" end
  if now - s.lastSignal <= Stats.ACTIVE_WINDOW then return "active" end
  return "idle"
end

local function bucket(s, now)
  local key = floor(now / 60)
  local b = s.buckets[key]
  if not b then b = { xp = 0, active = 0 } s.buckets[key] = b end
  return b
end

local function overlap(a1, a2, b1, b2) return max(0, min(a2, b2) - max(a1, b1)) end

-- Adds the time since the last call to active, idle or AFK, split at the window edges even inside one
-- interval. Returns the three increments.
function Stats.Advance(s, now, afk)
  local dt = now - s.last
  if dt <= 0 then return 0, 0, 0 end
  local from = s.last
  s.last = now
  local a, i, k = 0, 0, 0
  if afk then
    k = dt
  else
    a = overlap(from, now, s.activeFrom, s.lastSignal + Stats.ACTIVE_WINDOW) + overlap(from, now, -math.huge, s.prevEnd)
    a = min(dt, a)
    i = dt - a
  end
  s.active, s.idle, s.afk = s.active + a, s.idle + i, s.afk + k
  if a > 0 then
    local b = bucket(s, now)
    b.active = b.active + a
  end
  return a, i, k
end

function Stats.AddXP(s, now, amount)
  if amount <= 0 then return end
  s.xp = s.xp + amount
  local b = bucket(s, now)
  b.xp = b.xp + amount
end

-- XP and active seconds in the last ROLLING_MINUTES whole or partial minutes. Drops older buckets.
function Stats.Rolling(s, now)
  local oldest = floor(now / 60) - Stats.ROLLING_MINUTES + 1
  local xp, active = 0, 0
  for key, b in pairs(s.buckets) do
    if key < oldest then
      s.buckets[key] = nil
    else
      xp, active = xp + b.xp, active + b.active
    end
  end
  return xp, active
end

-- XP per hour, or nil while there is too little time to judge.
function Stats.Rate(xp, seconds)
  if not seconds or seconds < Stats.MIN_SAMPLE then return nil end
  return xp * 3600 / seconds
end

-- Seconds to gain `need` XP at `ratePerHour`, or nil.
function Stats.TimeFor(need, ratePerHour)
  if not ratePerHour or ratePerHour <= 0 then return nil end
  return max(0, need) * 3600 / ratePerHour
end

-- XP gains --------------------------------------------------------------------------------------------------

function Stats.NewXP(level, xp, maxXP)
  return { level = level, xp = xp, max = maxXP, pending = 0 }
end

-- Returns the XP gained since the last observation. Handles a level-up seen in either order: XP wrapping
-- before UnitLevel changes (counted once, then the later level change is not counted again), or both at once.
-- More than one level in one step uses the old level's XP for the levels between (an estimate).
function Stats.ObserveXP(st, level, xp, maxXP)
  local delta = 0
  if level == st.level then
    if xp >= st.xp then
      delta = xp - st.xp
    else
      delta = (st.max - st.xp) + xp
      st.pending = st.pending + 1
    end
  elseif level > st.level then
    local ups = level - st.level
    local credited = min(ups, st.pending)
    st.pending = st.pending - credited
    local rest = ups - credited
    if rest == 0 then
      delta = max(0, xp - st.xp)
    else
      delta = (st.max - st.xp) + xp + (rest - 1) * st.max
    end
  else
    st.pending = 0
  end
  st.level, st.xp = level, xp
  if maxXP and maxXP > 0 then st.max = maxXP end
  return delta
end

-- Milestones ------------------------------------------------------------------------------------------------

-- Milestones above `level`, up to `cap`, sorted, the cap itself included.
function Stats.Upcoming(level, milestones, cap)
  local seen, list = {}, {}
  for _, m in ipairs(milestones) do
    if m > level and m <= cap and not seen[m] then seen[m] = true list[#list + 1] = m end
  end
  if cap > level and not seen[cap] then list[#list + 1] = cap end
  table.sort(list)
  return list
end

-- XP to finish `level` (the XP bar for it). Uses the recorded value, else scales the nearest recorded level
-- below by (level / known) ^ 1.5. The second result is true when the value is an estimate.
function Stats.LevelXP(level, known)
  if known[level] then return known[level], false end
  local base
  for l = level - 1, 1, -1 do
    if known[l] then base = l break end
  end
  if not base then return nil, true end
  return floor(known[base] * (level / base) ^ 1.5 + 0.5), true
end

-- XP from now (`level`, `xp` into it) to reaching `target`. Second result: true when any level is an estimate.
function Stats.XPToReach(level, xp, target, known)
  if target <= level then return 0, false end
  local total, estimate = 0, false
  for l = level, target - 1 do
    local need, est = Stats.LevelXP(l, known)
    if not need then return nil, true end
    total = total + need
    estimate = estimate or est
  end
  return total - xp, estimate
end
