-- Mock test for the warlock module: the secure demon item, combat locks, clicks, menu and the death warning.
-- Not a game test. Run from the repo root: lua tests/warlock_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

S.class = "WARLOCK"
S.petHealthSecret = true -- as on Forever, even out of combat
S.pet = { name = "Zur'Dak", level = 8, family = "Imp", hp = 120, hpMax = 150, mana = 90, manaMax = 180, dead = false }

M.load("Superb", M.WARLOCK_FILES, M.load("Superb", M.CORE_FILES))
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")

local function find(id)
  for _, def in ipairs(Superb.modules) do if def.id == id then return def.widget, def end end
end
local w = find("warlock.demon")
check.ok("demon item for a warlock", w ~= nil)
check.eq("no hunter pet item", find("hunter.pet"), nil)
check.eq("secure template", w.template, "SecureActionButtonTemplate")
check.eq("text", M.plain(w.text), "Zur'Dak 8")
-- Health: the game draws the secret value; Superb only reserves room for the widest it can be.
check.eq("health drawn by the game, as a percent", M.plain(w.hp.text), " | SECRET%")
check.eq("health shown", w.hp.shown, true)
check.eq("room for full health", w.rightInset, #(Superb:Separator(w.label) .. "100%") * 7)
check.eq("item width includes it", w.width, #w.label.text * 7 + 2 * Superb:Theme().pad + w.leftInset + w.rightInset)
check.eq("portrait", w.icon.portrait, "pet")
check.eq("in the centre, first", w.points.LEFT.relPoint, "CENTER")

-- Clicks: Health Funnel on the left, nothing on the right, Shift+right for the menu.
check.eq("left is a spell", w.attributes.type1, "spell")
check.eq("left casts Health Funnel", w.attributes.spell1, "Health Funnel")
check.eq("right does nothing", w.attributes.type2, "")
check.eq("shift-right is free for the menu", w.attributes["shift-type2"], "")
check.eq("shift-left is free for moving", w.attributes["shift-type1"], "")
M.shift = true
w.scripts.PostClick(w, "RightButton", false)
check.ok("menu on shift-right", M.find(M.menu, "Bar shows") ~= nil)
M.shift = false

-- Tooltip.
w.scripts.OnEnter(w)
local tipText = table.concat(GameTooltip.lines, "\n")
for _, want in ipairs({ "Zur'Dak = Imp", "Max health = 150", "Mana = 90 / 180 (50%)",
  "Left-click = Health Funnel", "Right-click = Nothing", "Shift+right-click = Options" }) do
  check.ok("tooltip: " .. want, tipText:find(want, 1, true) ~= nil)
end
w.scripts.OnLeave(w)

-- Menu settings.
M.find(M.menu, "Health").select()
check.eq("health hidden", w.hp.shown, false)
check.eq("no room kept for it", w.rightInset, 0)
M.find(M.menu, "Level").select()
check.eq("level hidden", M.plain(w.text), "Zur'Dak")
M.find(M.menu, "Health").select()
M.find(M.menu, "Level").select()
local rightMenu = M.find(M.menu, "Right-click")
for _, e in ipairs(rightMenu.children) do if e.label == "Health Funnel" then e.select() end end
check.eq("right now funnels", w.attributes.type2, "spell")
check.eq("right funnel spell", w.attributes.spell2, "Health Funnel")

-- Combat: health turns secret, nothing on the secure item changes, catch-up afterwards.
S.lockdown = true
M.blocked = 0
S.pet.hp = 90
M.fire("UNIT_HEALTH", "pet")
check.eq("secret health not in the label", w.text:find("/", 1, true), nil)
check.eq("health still drawn in combat", M.plain(w.hp.text), " | SECRET%")
check.eq("room unchanged in combat", w.rightInset, #(Superb:Separator(w.label) .. "100%") * 7)
S.pet = nil
M.fire("UNIT_PET", "player")
check.eq("no demon in combat: kept but blank", w:IsShown(), true)
check.eq("blank text", w.text, "")
check.eq("no blocked calls in combat", M.blocked, 0)
S.lockdown = false
M.fire("PLAYER_REGEN_ENABLED")
check.eq("hidden after combat", w:IsShown(), false)
check.eq("health hidden with no demon", w.hp.shown, false)

-- A new demon with plain health (as on other clients), then its death.
S.petHealthSecret = false
S.pet = { name = "Gorzuk", level = 10, family = "Voidwalker", hp = 280, hpMax = 300, mana = 50, manaMax = 50, dead = false }
M.fire("UNIT_PET", "player")
check.eq("shown again", w:IsShown(), true)
check.eq("new demon text", M.plain(w.text), "Gorzuk 10")
check.eq("plain health drawn, rounded", M.plain(w.hp.text), " | 93%")
w.scripts.OnEnter(w)
check.ok("tooltip: plain health", table.concat(GameTooltip.lines, "\n"):find("Health = 280 / 300 (93%)", 1, true) ~= nil)
w.scripts.OnLeave(w)
local function newest()
  local best
  for _, f in ipairs(M.frames) do if f.strata == "DIALOG" and f.shown and (not best or f.born > best.born) then best = f end end
  return best
end
M.fire("UNIT_HEALTH", "pet")
check.eq("no warning while alive", newest(), nil)
S.pet.dead = true
M.time = M.time + 1
M.fire("UNIT_HEALTH", "pet")
check.eq("death warning", newest() and newest().title.text, "Demon died")
check.eq("death text", newest().body.text, "Gorzuk died. Summon it again before the next pull.")
check.eq("death is bad", M.sounds[#M.sounds].path, "Interface\\AddOns\\Superb\\Sounds\\bad.ogg")
local cards = 0
for _, f in ipairs(M.frames) do if f.strata == "DIALOG" and f.shown then cards = cards + 1 end end
M.time = M.time + 1
M.fire("UNIT_HEALTH", "pet")
local after = 0
for _, f in ipairs(M.frames) do if f.strata == "DIALOG" and f.shown then after = after + 1 end end
check.eq("one warning per death", after, cards)

-- Not a warlock: no demon item.
M.restart(0, {})
S.class = "HUNTER"
M.load("Superb", M.WARLOCK_FILES, M.load("Superb", M.CORE_FILES))
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")
local found = false
for _, d in ipairs(_G.Superb.modules) do if d.id == "warlock.demon" then found = true end end
check.eq("no demon item for other classes", found, false)

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
