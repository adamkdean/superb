-- Mock test for the hunter module: the secure pet item, combat locks, clicks, menus and warnings.
-- Not a game test. Run from the repo root: lua tests/hunter_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state


S.class = "HUNTER"
S.petHealthSecret = true -- as on Forever, even out of combat
S.pet = { name = "Temporary", level = 10, family = "Tallstrider", happiness = 3, damage = 125, rate = 1,
  loyalty = "Unruly", hp = 268, hpMax = 283, dead = false, xp = 1200, xpNeed = 4000,
  diet = { "Cheese", "Fungus", "Fruit" }, eats = { [20] = true, [21] = true } }
S.sellPrice[20], S.sellPrice[21] = 1, 1
S.itemLevel = { [20] = 5, [21] = 12 }
S.bags[1].items[1] = { itemID = 20, stackCount = 4, quality = 1, hyperlink = "[Old Cheese]", isBound = false, hasNoValue = false, iconFileID = 111 }
S.bags[1].items[2] = { itemID = 21, stackCount = 2, quality = 1, hyperlink = "[Skycheddar]", isBound = false, hasNoValue = false, iconFileID = 222 }

M.load("Superb", M.HUNTER_FILES, M.load("Superb", M.CORE_FILES))
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")

local function find(id)
  for _, def in ipairs(Superb.modules) do if def.id == id then return def.widget, def end end
end
local w, def = find("hunter.pet")
check.ok("pet item for a hunter", w ~= nil)
check.eq("secure template", w.template, "SecureActionButtonTemplate")
-- Name, level with pet XP, mood. Food shows only when low (6 here, warning under 5). No health: the unit frames show it.
check.eq("text", M.plain(w.text), "Temporary | 10 (30%) | |cff4de64dHappy|r")
check.eq("no health on the bar", w.hp, nil)
check.eq("portrait", w.icon.portrait, "pet")
check.eq("portrait level with the text", w.icon.points.LEFT.y, 1)
check.eq("no health line", w.line, nil)
check.eq("in the centre, first", w.points.LEFT.relPoint, "CENTER")

-- Clicks: feed with the lowest food that works. For a level 10 pet, the level 5 cheese is within 10 levels.
check.eq("left is feed", w.attributes.type1, "macro")
check.eq("feed macro", w.attributes.macrotext1, "/cast Feed Pet\n/use 1 1")
check.eq("right is mend", w.attributes.type2, "spell")
check.eq("mend spell", w.attributes.spell2, "Mend Pet")
check.eq("shift-right is free for the menu", w.attributes["shift-type2"], "")
check.eq("shift-left is free for moving", w.attributes["shift-type1"], "")
M.shift = true
w.scripts.PostClick(w, "RightButton", true)
check.eq("no menu on the down half", M.menu, nil)
w.scripts.PostClick(w, "RightButton", false)
check.ok("menu on shift-right", M.find(M.menu, "Bar shows") ~= nil)
M.shift = false

-- Tooltip as the screenshot, plus XP, training, loyalty trend and all food.
w.scripts.OnEnter(w)
local tipText = table.concat(GameTooltip.lines, "\n")
for _, want in ipairs({ "Temporary = Tallstrider", "Mood = Happy (125% damage)", "Loyalty = Unruly", "Loyalty is = rising",
  "Diet = Cheese, Fungus, Fruit", "Food = [Old Cheese] x4", "in bags = [Skycheddar] x2", "Pet XP = 1,200 / 4,000 (30%)",
  "Training points = 40 free of 120", "Left-click = Feed Pet", "Right-click = Mend Pet", "Shift+right-click = Options" }) do
  check.ok("tooltip: " .. want, tipText:find(want, 1, true) ~= nil)
end
w.scripts.OnLeave(w)

-- Menu settings.
check.eq("no health option", M.find(M.menu, "Health"), nil)
M.find(M.menu, "Pet XP, after the level").select()
check.eq("xp hidden", M.plain(w.text), "Temporary | 10 | |cff4de64dHappy|r")
M.find(M.menu, "Name").select()
check.eq("level alone", M.plain(w.text), "Lv 10 | |cff4de64dHappy|r")
M.find(M.menu, "Name").select()
M.find(M.menu, "Pet XP, after the level").select()
M.find(M.menu, "Highest level").select()
check.eq("highest food", w.attributes.macrotext1, "/cast Feed Pet\n/use 1 2")
local leftMenu = M.find(M.menu, "Left-click")
for _, e in ipairs(leftMenu.children) do if e.label == "Mend Pet" then e.select() end end
check.eq("left now mends", w.attributes.type1, "spell")
M.find(M.menu, "Loyalty trend").select()
w.scripts.OnEnter(w)
check.eq("trend off", table.concat(GameTooltip.lines, "\n"):find("Loyalty is", 1, true), nil)
w.scripts.OnLeave(w)
check.eq("no health line option", M.find(M.menu, "Health line"), nil)

-- Combat: health turns secret, nothing on the secure item moves or changes attributes, catch-up afterwards.
S.lockdown = true
M.blocked = 0
M.fire("UNIT_HEALTH", "pet")
check.eq("secret health not in the label", w.text:find("SECRET", 1, true), nil)
S.bags[1].items[2] = nil
M.fire("BAG_UPDATE_DELAYED")
check.eq("no blocked calls in combat", M.blocked, 0)
check.eq("attributes wait for combat to end", w.attributes.macrotext1, "/cast Feed Pet\n/use 1 2")
S.pet = nil
M.fire("UNIT_PET", "player")
check.eq("no pet in combat: kept but blank", w:IsShown(), true)
check.eq("blank text", w.text, "")
check.eq("still no blocked calls", M.blocked, 0)
M.shift = true
w.scripts.OnDragStart(w)
check.eq("no drag of a secure item in combat", Superb:Bar().marker.shown, false)
M.shift = false
S.lockdown = false
M.fire("PLAYER_REGEN_ENABLED")
check.eq("hidden after combat", w:IsShown(), false)

-- Warnings.
S.pet = { name = "Temporary", level = 10, family = "Tallstrider", happiness = 3, damage = 125, rate = 1,
  loyalty = "Unruly", hp = 268, hpMax = 283, dead = false, xp = 1200, xpNeed = 4000,
  diet = { "Cheese" }, eats = { [20] = true, [21] = true } }
S.bags[1].items[1].stackCount = 6 -- above the warning limit of 5
M.fire("UNIT_PET", "player")
check.eq("shown again", w:IsShown(), true)
local function newest()
  local best
  for _, f in ipairs(M.frames) do if f.strata == "DIALOG" and f.shown and (not best or f.born > best.born) then best = f end end
  return best
end
M.fire("UNIT_HAPPINESS", "pet")
S.pet.happiness = 2
M.time = M.time + 1
M.fire("UNIT_HAPPINESS", "pet")
check.eq("unhappy warning", newest() and newest().title.text, "Temporary is content")
S.pet.loyalty = "Submissive"
M.time = M.time + 1
M.fire("PET_UI_UPDATE")
check.eq("loyalty warning", newest().title.text, "Loyalty up")
S.bags[1].items[1] = { itemID = 20, stackCount = 2, quality = 1, hyperlink = "[Old Cheese]", isBound = false, hasNoValue = false, iconFileID = 111 }
M.time = M.time + 1
M.fire("BAG_UPDATE_DELAYED")
check.eq("low food warning", newest().title.text, "Pet food low")
check.eq("low food on the bar", M.plain(w.text), "Temporary | 10 (30%) | |cffffd100Content|r | |cffff991aLow food|r")
check.eq("low food is a warning", M.sounds[#M.sounds].path, "Interface\\AddOns\\Superb\\Sounds\\warning.ogg")
S.pet.dead = true
M.time = M.time + 1
M.fire("UNIT_HEALTH", "pet")
check.eq("death warning", newest().title.text, "Pet died")
check.eq("death is bad", M.sounds[#M.sounds].path, "Interface\\AddOns\\Superb\\Sounds\\bad.ogg")

-- Not a hunter: no pet item.
M.restart(0, {})
S.class = "WARRIOR"
M.load("Superb", M.HUNTER_FILES, M.load("Superb", M.CORE_FILES))
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")
local found = false
for _, d in ipairs(_G.Superb.modules) do if d.id == "hunter.pet" then found = true end end
check.eq("no pet item for other classes", found, false)

-- Logging in during combat: the secure button waits for combat to end.
M.restart(0, {})
S.class, S.lockdown = "HUNTER", true
M.load("Superb", M.HUNTER_FILES, M.load("Superb", M.CORE_FILES))
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")
local d2
for _, d in ipairs(_G.Superb.modules) do if d.id == "hunter.pet" then d2 = d end end
check.eq("not created in combat", d2 and d2.widget, nil)
S.lockdown = false
M.fire("PLAYER_REGEN_ENABLED")
check.ok("created after combat", d2.widget ~= nil)

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
