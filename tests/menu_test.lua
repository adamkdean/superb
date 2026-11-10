-- Mock test for Superb's own menu: rows, marks, submenus that open on a click, and closing.
-- Not a game test. Run from the repo root: lua tests/menu_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local M = require("wowmock")
M.install()

M.load("Superb", M.CORE_FILES)
local Superb = _G.Superb
M.fire("ADDON_LOADED", "Superb")
M.fire("PLAYER_LOGIN")
local Menu = Superb.Menu

local state = { sound = true, colour = "red", clicks = 0 }
local function open()
  Menu.Open(nil, function(_, root)
    root:CreateTitle("Things")
    root:CreateButton("Do it", function(n) state.clicks = state.clicks + n end, 2)
    root:CreateCheckbox("Sound", function() return state.sound end, function() state.sound = not state.sound end)
    root:CreateDivider()
    local sub = root:CreateButton("Colour")
    for _, c in ipairs({ "red", "blue" }) do
      sub:CreateRadio(c, function(v) return state.colour == v end, function(v) state.colour = v end, c)
    end
    local deep = sub:CreateButton("More")
    deep:CreateButton("Deepest", function() state.deep = true end)
    local other = root:CreateButton("Other")
    other:CreateTitle("Nothing here")
  end)
end

-- The frames: the menu is SuperbMenu, a submenu is the frame of the same kind made after it.
local function frames()
  local list = {}
  for _, f in ipairs(M.frames) do if f.rows and f.edges then list[#list + 1] = f end end
  return list
end
local function rowsOf(f)
  local t = {}
  for _, r in ipairs(f.rows) do
    if r:IsShown() then t[#t + 1] = (r.text.text or "") .. (r.arrow.text or "") end
  end
  return table.concat(t, "|")
end
local function row(f, label)
  for _, r in ipairs(f.rows) do if r:IsShown() and r.text.text == label then return r end end
end
local function click(f, label) local r = row(f, label) r.scripts.OnClick(r, "LeftButton") end

open()
local menu = frames()[1]
check.eq("one frame so far", #frames(), 1)
check.eq("shown", menu:IsShown(), true)
check.eq("rows, with an arrow on submenus", rowsOf(menu), "Things|Do it|Sound||Colour>|Other>")
check.eq("opens at the cursor, on the screen", menu.points.TOPLEFT.rel, WorldFrame)
check.eq("Escape closes it", UISpecialFrames[1], "SuperbMenu")
check.eq("a divider is a thin line", row(menu, "").height .. " " .. tostring(row(menu, "").line:IsShown()), "7 true")
check.eq("wide enough for the longest row", menu.width, 6 * 7 + 18 + 16 + 5)

-- Marks: a ticked checkbox is solid, an empty one is dim; a button has none.
check.eq("ticked", tostring(row(menu, "Sound").mark:IsShown()) .. row(menu, "Sound").mark.alpha, "true1")
check.eq("no mark on a button", row(menu, "Do it").mark:IsShown(), false)

-- Hover lights a row, but opens nothing. Titles do not light.
local colour = row(menu, "Colour")
colour.scripts.OnEnter(colour)
check.eq("hover lights the row", colour.hl:IsShown(), true)
check.eq("hover opens no submenu", #frames(), 1)
colour.scripts.OnLeave(colour)
check.eq("leaving unlights it", colour.hl:IsShown(), false)
row(menu, "Things").scripts.OnEnter(row(menu, "Things"))
check.eq("a title does not light", row(menu, "Things").hl:IsShown(), false)
click(menu, "Things")
check.eq("a title does nothing", menu:IsShown(), true)

-- A checkbox toggles and the menu stays open.
click(menu, "Sound")
check.eq("toggled", state.sound, false)
check.eq("still open", menu:IsShown(), true)
check.eq("now dim", row(menu, "Sound").mark.alpha, 0.25)

-- A click opens the submenu beside its row, and the row stays lit after the pointer leaves.
click(menu, "Colour")
local sub = frames()[2]
check.eq("submenu shown", sub and sub:IsShown(), true)
check.eq("submenu rows", rowsOf(sub), "red|blue|More>")
check.eq("beside its row", sub.points.TOPLEFT.rel, colour)
colour.scripts.OnLeave(colour)
check.eq("open row stays lit", colour.hl:IsShown(), true)
check.eq("the chosen radio is marked", tostring(row(sub, "red").mark:IsShown()) .. tostring(row(sub, "blue").mark:IsShown()), "truefalse")

-- A radio changes, the marks follow, and both menus stay open.
click(sub, "blue")
check.eq("radio set", state.colour, "blue")
check.eq("marks follow", tostring(row(sub, "red").mark:IsShown()) .. tostring(row(sub, "blue").mark:IsShown()), "falsetrue")
check.eq("both still open", tostring(menu:IsShown()) .. tostring(sub:IsShown()), "truetrue")

-- A third level, then another row of the first level: the old submenus close and the new one takes their frame.
click(sub, "More")
local deep = frames()[3]
check.eq("third level", rowsOf(deep), "Deepest")
click(menu, "Other")
check.eq("the frame is used again", #frames(), 3)
check.eq("new submenu", rowsOf(sub), "Nothing here")
check.eq("deeper level closed", deep:IsShown(), false)
check.eq("old row unlit", colour.hl:IsShown(), false)

-- A second click on the open row closes its submenu.
click(menu, "Other")
check.eq("closed by a second click", sub:IsShown(), false)
check.eq("menu stays", menu:IsShown(), true)

-- A click inside the menu keeps it; a click anywhere else closes everything.
click(menu, "Colour")
sub.mouseOver = true
M.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check.eq("a click on a submenu keeps both", tostring(menu:IsShown()) .. tostring(sub:IsShown()), "truetrue")
sub.mouseOver = false
M.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check.eq("a click outside closes both", tostring(menu:IsShown()) .. tostring(sub:IsShown()), "falsefalse")

-- A button runs with its data and closes the menu.
open()
click(menu, "Do it")
check.eq("button ran", state.clicks, 2)
check.eq("closed after a button", menu:IsShown(), false)

-- Opening again starts clean: no submenu, fresh marks.
open()
check.eq("no submenu after reopening", sub:IsShown(), false)
check.eq("mark as saved", row(menu, "Sound").mark.alpha, 0.25)

-- The bar opens this menu: a right-click on the Superb item.
local w
for _, d in ipairs(Superb.modules) do if d.id == "superb" then w = d.widget end end
w.scripts.OnClick(w, "RightButton")
check.ok("bar menu drawn", row(menu, "Theme") ~= nil and row(menu, "Theme").arrow.text == ">")
click(menu, "Theme")
check.ok("theme submenu", row(sub, "Minimal") ~= nil)
click(sub, "Minimal")
check.eq("theme set from the menu", Superb:Theme().name, "Minimal")
check.eq("menu stays open after a radio", menu:IsShown(), true)

-- The bar's menus drop from the clicked item, not from the cursor: under it on a top bar, over it on a bottom bar.
local function anchor()
  local point, v = next(menu.points)
  return point .. " to " .. v.relPoint .. " of " .. (v.rel == w and "item" or v.rel == Superb:Bar() and "bar" or "other")
    .. " " .. v.x .. "," .. v.y
end
w.scripts.OnClick(w, "RightButton")
check.eq("under the item", anchor(), "TOPLEFT to BOTTOMLEFT of item 0,0")
Superb:SetPosition("bottom")
w.scripts.OnClick(w, "RightButton")
check.eq("over the item on a bottom bar", anchor(), "BOTTOMLEFT to TOPLEFT of item 0,0")
-- A right-click on an empty part of the bar: on the bar's edge, at the pointer's place along it.
M.cursorX = 300
Superb:Bar().scripts.OnMouseUp(Superb:Bar(), "RightButton")
check.eq("empty bar, bottom", anchor(), "BOTTOMLEFT to TOPLEFT of bar 300.0,0")
Superb:SetPosition("top")
M.uiScale = 0.5
Superb:Bar().scripts.OnMouseUp(Superb:Bar(), "RightButton")
check.eq("empty bar, top, in the bar's scale", anchor(), "TOPLEFT to BOTTOMLEFT of bar 600.0,0")
M.uiScale, M.cursorX = nil, nil

check.eq("no module errors", #M.errors, 0)
for _, e in ipairs(M.errors) do io.write(e, "\n") end
check.done()
