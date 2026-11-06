-- Mock test for addons/Superb: load order, saved data, moving the UI, themes, modules, tooltips and menus.
-- Not a game test. Run from the repo root: lua tests/Superb/mock_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()
local S = M.state

-- The TOC and the test load the same files.
check.eq("toc files", table.concat(M.tocFiles("Superb"), ","), table.concat(M.SUPERB_FILES, ","))

-- AuctionDB stand-in: lowest price 300 for item 3 only.
AuctionDB = {
  PlayerHouse = function() return "Alliance" end,
  LastPrice = function(_, id, house) if id == 3 and house == "Alliance" then return { 1, 300, 350, 4 } end end,
}

M.load("Superb", M.SUPERB_FILES)
local Superb = _G.Superb

-- SavedVariables arrive after the files run, then ADDON_LOADED.
SuperbDB = { position = "bottom", theme = "vanilla", modules = { clock = { source = "realm" } } }
M.fire("ADDON_LOADED", "Superb")
check.eq("saved position kept", Superb:Position(), "bottom")
check.eq("saved theme kept", Superb:Theme().name, "Vanilla")
check.ok("defaults filled", type(SuperbDB.chars) == "table")

M.fire("PLAYER_LOGIN")
local bar = Superb:Bar()
check.ok("bar created", bar ~= nil)
local h = Superb.Themes.vanilla.height
check.eq("bottom: UIParent bottom raised", UIParent.points.BOTTOMRIGHT.y, h)
check.eq("bottom: UIParent top unchanged", UIParent.points.TOPLEFT.y, 0)
check.eq("bottom: bar under UIParent", bar.points.TOPLEFT.rel, UIParent)
check.eq("bottom: bar anchor", bar.points.TOPLEFT.relPoint, "BOTTOMLEFT")
check.eq("bar height", bar.height, h)

-- Blizzard's own top offset (notch) is kept when the bar is at the top.
Superb:SetPosition("top")
check.eq("top: UIParent top lowered", UIParent.points.TOPLEFT.y, -h)
check.eq("top: UIParent bottom reset", UIParent.points.BOTTOMRIGHT.y, 0)
check.eq("top: bar above UIParent", bar.points.BOTTOMLEFT.relPoint, "TOPLEFT")
S.topOffset = 10
UpdateUIParentPosition()
check.eq("notch offset added", UIParent.points.TOPLEFT.y, -(10 + h))
S.topOffset = 0
UpdateUIParentPosition()
check.eq("notch offset removed", UIParent.points.TOPLEFT.y, -h)

-- No anchor changes in combat; applied when combat ends.
S.lockdown = true
Superb:SetPosition("bottom")
check.eq("combat: not moved", UIParent.points.TOPLEFT.y, -h)
S.lockdown = false
M.fire("PLAYER_REGEN_ENABLED")
check.eq("after combat: moved", UIParent.points.BOTTOMRIGHT.y, h)
check.eq("position saved", SuperbDB.position, "bottom")

-- Theme change resizes the bar and the offset.
check.ok("theme set", Superb:SetTheme("defaultDark"))
check.eq("theme saved", SuperbDB.theme, "defaultDark")
check.eq("new height", bar.height, Superb.Themes.defaultDark.height)
check.eq("offset follows height", UIParent.points.BOTTOMRIGHT.y, Superb.Themes.defaultDark.height)
check.eq("bad theme refused", Superb:SetTheme("nope"), false)
check.eq("order is not a theme", Superb:SetTheme("order"), false)
for _, key in ipairs(Superb.Themes.order) do check.ok("theme " .. key, Superb:SetTheme(key)) end
Superb:SetTheme("defaultDark")

local function widget(id)
  for _, def in ipairs(Superb.modules) do if def.id == id then return def.widget, def end end
end

-- Module texts.
check.eq("superb item", widget("superb").text, "Superb")
check.eq("clock realm", widget("clock").text, "Thu 6 Nov  13:05")
check.eq("gold", widget("gold").text, "COIN123456")
check.eq("bags", widget("bags").text, "Bags 7 free")
-- Vendor 2x100 + 5000 + 5x20 = 5300. Best: junk 200, sword 5000 (bound), cloth max(100, 1500) = 6700.
check.eq("bag value best", widget("bagvalue").text, "COIN6700")
check.ok("gold saved per character", SuperbDB.chars.Testrealm.Hero.money == 123456)

-- Layout: right side runs from the edge inwards by order.
local clock, gold = widget("clock"), widget("gold")
check.eq("clock at right edge", clock.points.RIGHT.rel, bar)
check.eq("gold left of clock", gold.points.RIGHT.rel, clock)
check.eq("superb at left edge", widget("superb").points.LEFT.rel, bar)

-- Disable a module: it hides and the next one takes its place.
Superb:SetEnabled(select(2, widget("gold")), false)
check.eq("gold hidden", gold:IsShown(), false)
check.eq("bag value now next to clock", widget("bagvalue").points.RIGHT.rel, clock)
check.eq("disabled saved", SuperbDB.modules.gold.enabled, false)
Superb:SetEnabled(select(2, widget("gold")), true)
check.eq("gold back", gold:IsShown(), true)

-- Bag changes are batched: one refresh after the timer.
S.bags[1].items[1] = { itemID = 1, stackCount = 1, quality = 0, hyperlink = "[Junk]", isBound = false, hasNoValue = false }
M.fire("BAG_UPDATE_DELAYED")
check.eq("bags not yet refreshed", widget("bags").text, "Bags 7 free")
M.runTimers()
check.eq("bags refreshed", widget("bags").text, "Bags 6 free")
check.eq("one timer for both", #M.timers, 0)

-- Missing item info: requested, then refreshed when it arrives.
S.bags[1].items[2] = { itemID = 9, stackCount = 1, quality = 1, hyperlink = "[New]", isBound = false, hasNoValue = false }
M.fire("BAG_UPDATE_DELAYED")
M.runTimers()
check.eq("item data requested", M.requested, 9)
S.sellPrice[9] = 1000
M.fire("GET_ITEM_INFO_RECEIVED", 9)
M.runTimers()
check.eq("value after item info", widget("bagvalue").text, "COIN7800")

-- Money event.
S.money = 200000
M.fire("PLAYER_MONEY")
check.eq("gold updated", gold.text, "COIN200000")

-- Every tooltip renders and anchors on the bar's side.
for _, def in ipairs(Superb.modules) do
  if def.Tooltip then
    def.widget.scripts.OnEnter(def.widget)
    check.ok("tooltip " .. def.id, #GameTooltip.lines > 0 and GameTooltip.shown)
    check.eq("tooltip above a bottom bar " .. def.id, GameTooltip.point[1]:match("^BOTTOM") ~= nil, true)
    def.widget.scripts.OnLeave(def.widget)
    check.eq("tooltip hidden " .. def.id, GameTooltip.shown, false)
  end
end

-- The open tooltip refreshes each second.
clock.scripts.OnEnter(clock)
S.gameMinute = 6
M.tick()
check.eq("clock ticks", clock.text, "Thu 6 Nov  13:06")
local found = false
for _, l in ipairs(GameTooltip.lines) do if l:find("13:06", 1, true) then found = true end end
check.ok("tooltip refreshed", found)
clock.scripts.OnLeave(clock)

-- Right-click menus: module options first, then Superb's own.
clock.scripts.OnClick(clock, "RightButton")
check.eq("clock menu title", M.menu.children[1].label, "Clock")
M.find(M.menu, "Local time").select()
check.eq("clock source saved", SuperbDB.modules.clock.source, "local")
M.find(M.menu, "24-hour clock").select()
check.eq("12-hour saved", SuperbDB.modules.clock.use12, true)
check.ok("12-hour text", clock.text:find("PM", 1, true) ~= nil)
M.find(M.menu, "Show date").select()
check.eq("date hidden", SuperbDB.modules.clock.showDate, false)
check.ok("superb menu follows", M.find(M.menu, "Theme") ~= nil)
M.find(M.menu, "Top").select()
check.eq("menu sets position", SuperbDB.position, "top")
M.find(M.menu, "Tooltip").select()
check.eq("menu sets theme", SuperbDB.theme, "tooltip")

local superb = widget("superb")
superb.scripts.OnClick(superb, "LeftButton")
check.ok("left click on Superb opens menu", M.find(M.menu, "Modules") ~= nil)
check.ok("modules listed", M.find(M.menu, "Bag value") ~= nil)

local bv = widget("bagvalue")
bv.scripts.OnClick(bv, "RightButton")
M.find(M.menu, "Vendor price").select()
check.eq("vendor value", bv.text, "COIN" .. (5300 + 100 + 1000))

-- A module registered after login appears at once; a module error is reported once, not thrown.
Superb:RegisterModule({ id = "late", side = "left", order = 99, Text = function() return "late" end })
check.eq("late module shown", widget("late").text, "late")
Superb:RegisterModule({ id = "broken", Text = function() error("boom") end, tick = true })
M.tick(3)
check.eq("broken shows ?", widget("broken").text, "?")
check.eq("error reported once", #M.errors, 1)
local okDup = pcall(Superb.RegisterModule, Superb, { id = "late", Text = function() end })
check.eq("duplicate id refused", okDup, false)

-- Slash command.
SlashCmdList.SUPERB("bottom")
check.eq("slash bottom", SuperbDB.position, "bottom")
SlashCmdList.SUPERB("theme DEFAULTLIGHT")
check.eq("slash theme", SuperbDB.theme, "defaultLight")
SlashCmdList.SUPERB("theme nope")
check.ok("slash lists themes", M.printed[#M.printed]:find("defaultLight", 1, true) ~= nil)
SlashCmdList.SUPERB("reset")
check.eq("reset position", SuperbDB.position, "top")
check.eq("reset theme", SuperbDB.theme, "defaultDark")

-- New items -------------------------------------------------------------------------------------------------
check.eq("performance", widget("performance").text, "60 fps · 45 ms")
M.time = M.time + 11 -- past the memory cache from the tooltip loop above
local mem = M.memoryUpdates or 0
local perf = widget("performance")
perf.scripts.OnEnter(perf)
M.tick(3)
check.eq("memory read once per 10 s", (M.memoryUpdates or 0) - mem, 1)
perf.scripts.OnLeave(perf)

local loc = widget("location")
check.eq("location text", loc.text, "Goldshire  42, 66")
check.eq("location in the centre", loc.points.LEFT.relPoint, "CENTER")
check.eq("location centred", loc.points.LEFT.x, -loc.width / 2)
S.mapPos = nil
M.tick()
check.eq("no coordinates in instances", loc.text, "Goldshire")
S.mapPos = { 0.5, 0.25 }
loc.scripts.OnClick(loc, "RightButton")
M.find(M.menu, "One decimal place").select()
check.eq("one decimal", loc.text, "Goldshire  50.0, 25.0")
M.find(M.menu, "Show coordinates").select()
check.eq("coordinates off", loc.text, "Goldshire")
loc.scripts.OnClick(loc, "LeftButton")
check.eq("map opens", M.mapToggled, 1)
S.lockdown = true
loc.scripts.OnClick(loc, "LeftButton")
check.eq("no map in combat", M.mapToggled, 1)
S.lockdown = false

local dur = widget("durability")
S.durability[5] = { 27, 60 }
M.fire("UPDATE_INVENTORY_DURABILITY")
check.eq("durability lowest, orange", dur.text, "Armour |cffff991a45%|r")

-- Notifications.
local function toasts()
  local list = {}
  for _, f in ipairs(M.frames) do if f.strata == "DIALOG" and f.shown then list[#list + 1] = f end end
  table.sort(list, function(a, b) return a.born > b.born end) -- newest first
  return list
end
check.eq("no toasts yet", #toasts(), 0)
S.durability[5] = { 12, 60 }
M.fire("UPDATE_INVENTORY_DURABILITY")
check.eq("repair toast", #toasts(), 1)
check.eq("repair title", toasts()[1].title.text, "Repair soon")
check.eq("durability red", dur.text, "Armour |cffff404020%|r")
check.eq("toast under a top bar", toasts()[1].points.TOPRIGHT.rel, bar)
M.time = M.time + 0.1
S.durability[5] = { 0, 60 }
M.fire("UPDATE_INVENTORY_DURABILITY")
check.eq("broken toast", toasts()[1].title.text, "Item broken")
check.eq("toasts stack", #toasts(), 2)

M.time = M.time + 0.1
S.newMail = true
M.fire("UPDATE_PENDING_MAIL")
check.eq("mail toast", toasts()[1].body.text, "From Alice")
M.fire("UPDATE_PENDING_MAIL")
check.eq("mail once", #toasts(), 3)

for slot = 3, 6 do S.bags[1].items[slot] = { itemID = 3, stackCount = 1, quality = 1, hyperlink = "[Cloth]", isBound = false, hasNoValue = false } end
for slot = 4, 4 do S.bags[0].items[slot] = { itemID = 3, stackCount = 1, quality = 1, hyperlink = "[Cloth]", isBound = false, hasNoValue = false } end
M.time = M.time + 0.1
M.fire("BAG_UPDATE_DELAYED")
M.runTimers()
check.eq("bags full text", widget("bags").text, "Bags 0 free")
check.eq("at most three toasts", #toasts(), 3)
check.eq("bags full toast newest", toasts()[1].title.text, "Bags full")

M.tick(8)
for _, t in ipairs(toasts()) do t.scripts.OnUpdate(t) end
check.eq("toasts fade out", #toasts(), 0)

-- Turn a kind off, then notifications off.
local superbW = widget("superb")
superbW.scripts.OnClick(superbW, "LeftButton")
M.find(M.menu, "New mail").select()
check.eq("mail kind off", SuperbDB.modules.notifications.mail, false)
check.eq("mail kind refused", Superb:Notify("mail", "x", "y"), false)
M.find(M.menu, "Show a test notification").click()
check.eq("test toast", #toasts(), 1)
Superb:SetEnabled(select(2, widget("notifications")), false)
check.eq("all off", Superb:Notify("test", "x", "y"), false)
Superb:SetEnabled(select(2, widget("notifications")), true)

-- Toasts rise from a bottom bar.
Superb:SetPosition("bottom")
M.time = M.time + 0.1
Superb:Notify("test", "Bottom", "x")
check.eq("toast above a bottom bar", toasts()[1].points.BOTTOMRIGHT.rel, bar)
Superb:SetPosition("top")

check.done()
