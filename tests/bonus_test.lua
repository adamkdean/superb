-- Mock test for the XP bonus item: the total, the time left, combat, the tooltip, the warning and click to eat.
-- Not a game test. Run from the repo root: lua tests/bonus_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

local WELL_FED, BAG, TENT_LOCK, FIRE_NEAR, FIRE_SIT, CAMP = 1248421, 429959, 1229451, 1283391, 1289723, 1229741
-- The texts are the ones seen in game for the buff and the food.
local FOOD_TIP = "Use: Restores 58 health over 18 sec.  Must remain seated while eating. If you spend at least 10 sec "
  .. "eating, you will become well fed and gain 1 Intellect for 15 min. Additionally, experience gained from kills is "
  .. "increased by 5%. (1 Sec Cooldown)"
local BUFF_TIP = "Your Intellect is increased by 1. Experience gained from kills increased by 5%."

local ns = M.load("Superb", M.CORE_FILES)
M.load("Superb", M.LEVELLING_FILES, ns)
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")

local w, def
for _, d in ipairs(Superb.modules) do if d.id == "levelling.bonus" then w, def = d.widget, d end end
local function text() return M.plain(w.text) end
local function tip()
  w.scripts.OnEnter(w)
  local t = table.concat(GameTooltip.lines, "\n")
  w.scripts.OnLeave(w)
  return t
end
local function has(line) return tip():find(line, 1, true) ~= nil end
local function newest()
  local best
  for _, f in ipairs(M.frames) do if f.strata == "DIALOG" and f.shown and (not best or f.born > best.born) then best = f end end
  return best
end

check.ok("item registered", w ~= nil)
-- Last on the left: after every other item with text there (the XP line draws no text).
local last
for _, d in ipairs(Superb.modules) do
  if Superb:Side(d) == "left" and d.id ~= "levelling.xpline" and (not last or d.order > last.order) then last = d end
end
check.eq("last on the left", last.id, "levelling.bonus")

-- Rested alone: kills give double XP, and nothing counts down.
check.eq("rested only", text(), "+100% XP")
check.ok("tooltip rested", has("Rested = +100% (15% of a level left)"))
check.ok("tooltip no buffs", has("Food and buffs = None"))
check.ok("tooltip no campfire", has("Campfire = None nearby"))
check.ok("no tent line without the lockout", not has("Camp Tent"))

-- No bonus at all: the item stays, so the missing bonus shows.
S.rested = 0
M.tick()
check.eq("no bonus", text(), "+0% XP")
S.rested = nil
M.tick()
check.eq("no rested value", text(), "+0% XP")

-- A buff with no XP in its text is not a bonus.
S.auras[19834] = { name = "Blessing of Might", applications = 0, expirationTime = M.time + 300,
  tip = "Attack power increased by 85." }
M.tick()
check.eq("other buffs do not count", text(), "+0% XP")

-- Well Fed from XP food: the percent comes from the buff's text.
S.auras[WELL_FED] = { name = "Well Fed", applications = 0, expirationTime = M.time + 930, tip = BUFF_TIP }
M.tick()
check.eq("food", text(), "+5% XP | 15m")
check.ok("tooltip food", has("Well Fed = +5% (15m)"))
check.ok("no None line with a buff on", not has("Food and buffs"))

-- A second buff with XP in its text adds on. The bar counts down to the first bonus to end.
S.auras[BAG] = { name = "Well-Rested", applications = 2, expirationTime = M.time + 3630,
  tip = "Experience gained increased by 2%." }
S.rested = 1500
M.tick()
check.eq("all three", text(), "+107% XP | 15m")
check.ok("tooltip bag", has("Well-Rested = +2% (1h 00m)"))
check.ok("tooltip total", has("XP bonus = +107%"))
-- A new stack changes the text, so the percent is read again.
S.auras[BAG].applications, S.auras[BAG].tip = 3, "Experience gained increased by 3%."
M.tick()

-- Combat: the game hides aura data, so the item keeps what it read and counts down.
S.lockdown = true
M.tick(60)
check.eq("kept in combat", text(), "+108% XP | 14m")
check.eq("no warning in combat", newest(), nil)

-- A bonus that runs out in combat drops at its end time, with a warning.
M.tick(900)
check.eq("food ran out in combat", text(), "+103% XP | 44m")
check.eq("warning", newest() and newest().title.text, "XP bonus ended")
check.eq("warning text", newest().body.text, "Your Well Fed XP bonus ended.")
S.auras[WELL_FED] = nil
S.lockdown = false
M.tick()

-- Aura data restricted out of combat: asked about, never used.
local before = M.secretChecks
S.aurasSecret = true
M.tick()
check.ok("secret aura checked", M.secretChecks > before)
check.eq("kept while secret", text(), "+103% XP | 44m")
S.aurasSecret = false

-- A bonus lost out of combat (death, or clicked off) goes at once.
S.auras[BAG] = nil
M.time = M.time + 10
M.tick()
check.eq("bag gone", text(), "+100% XP")
check.eq("bag warning", newest().body.text, "Your Well-Rested XP bonus ended.")

-- Campfire, in the tooltip only: near, sitting, then the camp's benefits. The tent locks for an hour.
S.auras[FIRE_NEAR] = { name = "Campfire Nearby", applications = 0, expirationTime = 0 }
M.tick()
check.ok("campfire near", has("Campfire = Nearby. Sit by it for a minute"))
S.auras[FIRE_SIT] = { name = "Welcoming Campfire", applications = 0, expirationTime = M.time + 43 }
M.tick()
check.ok("campfire sitting", has("Campfire = Camp benefits in 42s"))
S.auras[FIRE_SIT] = nil
S.auras[CAMP] = { name = "Camp Benefits", applications = 0, expirationTime = 0 }
S.auras[TENT_LOCK] = { name = "Boosted Rest", applications = 0, expirationTime = M.time + 1801, harmful = true }
M.tick()
check.ok("camp benefits", has("Campfire = Camp benefits active"))
check.ok("tent lockout", has("Camp Tent = Ready in 30m"))
check.eq("campfire stays off the bar", text(), "+100% XP")

-- Click to eat: no XP food in the bags, so the left click does nothing.
check.eq("no food: no action", w.attributes.type1, "")
check.ok("tooltip says so", has("Left-click = No XP food in your bags"))
-- Food whose text gives the XP bonus is eaten by its bag and slot. Plain food and other XP items are passed over.
S.bags[0].items[4] = { itemID = 10, stackCount = 5, hyperlink = "[Tough Jerky]", tip = "Use: Restores 61 health over 18 sec.  Must remain seated while eating." }
S.bags[1].items[1] = { itemID = 11, stackCount = 1, hyperlink = "[Pendant]", tip = "Use: Experience from Undead kills increased by 10%." }
S.bags[1].items[2] = { itemID = 12, stackCount = 3, hyperlink = "[Roasted Boar Meat]", tip = FOOD_TIP }
M.fire("BAG_UPDATE_DELAYED")
check.eq("left click is a macro", w.attributes.type1, "macro")
check.eq("eats the XP food", w.attributes.macrotext1, "/use 1 2")
check.ok("tooltip names it", has("Left-click = Eat [Roasted Boar Meat]"))
-- In combat the click keeps its action; the change waits.
S.lockdown = true
S.bags[1].items[2] = nil
M.fire("BAG_UPDATE_DELAYED")
check.eq("attributes wait for combat to end", w.attributes.macrotext1, "/use 1 2")
S.lockdown = false
M.fire("PLAYER_REGEN_ENABLED")
check.eq("food gone: no action", w.attributes.type1, "")

-- Nothing to show at the level cap or with XP turned off.
S.xpDisabled = true
M.tick()
check.eq("hidden with XP off", w:IsShown(), false)
S.xpDisabled = false
S.level = 60
M.tick()
check.eq("hidden at the cap", w:IsShown(), false)

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
