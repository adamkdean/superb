-- Pure tests for addons/SuperbLevelling/Stats.lua. Run from the repo root: lua tests/SuperbLevelling/stats_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local ns = {}
loadfile("addons/SuperbLevelling/Stats.lua")("SuperbLevelling", ns)
local Stats = ns.Stats

-- Activity: active for 60 s after a signal, split inside one interval, AFK separate.
local s = Stats.NewSession(0)
check.eq("state at start", Stats.State(s, 0, false), "active")
local a, i, k = Stats.Advance(s, 50, false)
check.eq("active part", a, 50) check.eq("idle part", i, 0)
a, i = Stats.Advance(s, 100, false)
check.eq("split active", a, 10) check.eq("split idle", i, 40)
check.eq("state idle", Stats.State(s, 100, false), "idle")
check.eq("state afk", Stats.State(s, 100, true), "afk")
a, i, k = Stats.Advance(s, 130, true)
check.eq("afk part", k, 30) check.eq("afk not idle", i, 0)
Stats.Signal(s, 130)
Stats.Signal(s, 120) -- an older signal never moves the window back
check.eq("signal kept latest", s.lastSignal, 130)
a = Stats.Advance(s, 131, false)
check.eq("active again", a, 1)
check.eq("no time, no change", select(1, Stats.Advance(s, 131, false)), 0)
check.eq("totals", s.active + s.idle + s.afk, 131)

-- A long interval holding the end of one window, a gap and a new window.
local g = Stats.NewSession(0)
Stats.Signal(g, 200)  -- old window ended at 60
a, i = Stats.Advance(g, 230, false)
check.eq("long interval active", a, 60 + 30)
check.eq("long interval idle", i, 140)

-- Rates: nil before the minimum sample, rolling window drops old minutes.
check.eq("rate too early", Stats.Rate(1000, 60), nil)
check.near("rate per hour", Stats.Rate(1000, 1800), 2000)
check.near("time for", Stats.TimeFor(2000, 4000), 1800)
check.eq("time for no rate", Stats.TimeFor(2000, nil), nil)
check.eq("time for zero need", Stats.TimeFor(-5, 100), 0)

local r = Stats.NewSession(0)
Stats.AddXP(r, 30, 500)            -- minute 0
Stats.Advance(r, 59, false)
Stats.AddXP(r, 20 * 60 + 5, 300)   -- minute 20
Stats.Signal(r, 20 * 60)
Stats.Advance(r, 20 * 60 + 50, false)
local rxp, ract = Stats.Rolling(r, 20 * 60 + 50)
check.eq("rolling drops minute 0 xp", rxp, 300)
-- Active time is filed under the minute in which the interval ends, so the 1 s left of the old window
-- lands in minute 20. In game the interval is 1 s, so the error is at most 1 s per minute.
check.eq("rolling active", ract, 51)
check.eq("gap before the signal is idle", r.idle, 20 * 60 - 60)
check.eq("old window counted once", r.active, 59 + 1 + 50)
check.eq("old bucket pruned", r.buckets[0], nil)
check.eq("session xp keeps all", r.xp, 800)
Stats.AddXP(r, 1300, 0)
check.eq("zero xp ignored", r.xp, 800)

-- XP gains across level-ups.
local st = Stats.NewXP(10, 900, 1000)
check.eq("plain gain", Stats.ObserveXP(st, 10, 950, 1000), 50)
check.eq("level and xp together", Stats.ObserveXP(st, 11, 100, 1200), 150)
check.eq("wrap before level shows", Stats.ObserveXP(st, 11, 50, 1200), 1150)
check.eq("pending after wrap", st.pending, 1)
check.eq("late level change not counted twice", Stats.ObserveXP(st, 12, 50, 1400), 0)
check.eq("pending cleared", st.pending, 0)
check.eq("level up with more xp than before", Stats.ObserveXP(st, 13, 1300, 1600), 1350 + 1300)
check.eq("two levels in one step", Stats.ObserveXP(st, 15, 100, 2000), (1600 - 1300) + 100 + 1600)
check.eq("max of zero is ignored", Stats.ObserveXP(st, 15, 150, 0), 50)
check.eq("max kept", st.max, 2000)
check.eq("level down resets", Stats.ObserveXP(st, 14, 10, 1800), 0)

-- Milestones.
local up = Stats.Upcoming(23, Stats.DEFAULT_MILESTONES, 60)
check.eq("upcoming first", up[1], 25)
check.eq("upcoming count", #up, 5)
local capped = Stats.Upcoming(23, { 25, 70 }, 60)
check.eq("over cap dropped, cap added", #capped, 2)
check.eq("cap last", capped[2], 60)
check.eq("none at cap", #Stats.Upcoming(60, Stats.DEFAULT_MILESTONES, 60), 0)
check.eq("duplicates removed", #Stats.Upcoming(1, { 10, 10 }, 10), 1)

local known = { [20] = 10000, [21] = 11000 }
check.eq("known level", select(1, Stats.LevelXP(21, known)), 11000)
check.eq("known not estimate", select(2, Stats.LevelXP(21, known)), false)
local est, isEst = Stats.LevelXP(24, known)
check.eq("estimate flag", isEst, true)
check.eq("estimate from nearest below", est, math.floor(11000 * (24 / 21) ^ 1.5 + 0.5))
check.eq("no base", Stats.LevelXP(5, known), nil)

local need, e = Stats.XPToReach(20, 4000, 22, known)
check.eq("to reach exact", need, 10000 + 11000 - 4000)
check.eq("to reach exact flag", e, false)
need, e = Stats.XPToReach(21, 0, 23, known)
check.eq("to reach estimate flag", e, true)
check.eq("to reach estimate", need, 11000 + math.floor(11000 * (22 / 21) ^ 1.5 + 0.5))
check.eq("already there", Stats.XPToReach(25, 10, 25, known), 0)
check.eq("unknown base", Stats.XPToReach(5, 0, 10, known), nil)

-- Saving across reloads: counters, activity window and rolling buckets survive, offline time is not counted.
local live = Stats.NewSession(5000, 23)
live.startedAt = 1800000000
Stats.AddXP(live, 5030, 600)
Stats.Advance(live, 5050, false)
Stats.Signal(live, 5100)
Stats.Advance(live, 5120, false)
local frozen = Stats.Freeze(live, 5120, 24)
check.eq("frozen level", frozen.levelTo, 24)
check.eq("frozen age", frozen.ageSignal, 20)
-- A client restart: GetTime() starts again near zero.
local back = Stats.Thaw(frozen, 300)
check.eq("thaw active", back.active, live.active)
check.eq("thaw xp", back.xp, 600)
check.eq("thaw level from", back.levelFrom, 23)
check.eq("thaw started at", back.startedAt, 1800000000)
check.eq("thaw signal age kept", 300 - back.lastSignal, 20)
check.eq("thaw state still active", Stats.State(back, 300, false), "active")
local bxp, bact = Stats.Rolling(back, 300)
local lxp, lact = Stats.Rolling(live, 5120)
check.eq("thaw rolling xp", bxp, lxp)
check.eq("thaw rolling active", bact, lact)
check.eq("no offline time counted", select(1, Stats.Advance(back, 300, false)), 0)
check.eq("online", Stats.Online(back), 120)

local sum = Stats.Summary(back, 1800000500, 24)
check.eq("summary online", sum.online, 120)
check.eq("summary levels", sum.levelFrom .. ">" .. sum.levelTo, "23>24")
local history = {}
check.eq("short session not kept", Stats.Archive(history, { online = 30 }), false)
for n = 1, Stats.MAX_HISTORY + 3 do Stats.Archive(history, { online = 60 + n }) end
check.eq("history capped", #history, Stats.MAX_HISTORY)
check.eq("newest first", history[1].online, 60 + Stats.MAX_HISTORY + 3)

check.done()
