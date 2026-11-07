-- Superb: a menu bar along the top or bottom of the screen. Modules, here and in other addons, put text on it.
-- The rest of the UI moves out of the way: UIParent is shrunk by the bar height. Blizzard sets UIParent's top
-- offset itself in UpdateUIParentPosition (Blizzard_UIParentUtil/UIParentUtil.lua), so the bar re-applies its
-- offset after each call. Anchors are changed out of combat only.
local ADDON = ...
local S = Superb

S.modules = {}
local byId = {}
local DEFAULTS = { position = "top", theme = S.DEFAULT_THEME, modules = {}, chars = {} }

local function copyDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then dst[k] = type(v) == "table" and copyDefaults({}, v) or v end
  end
  return dst
end

-- SavedVariables load after this file runs, so DB is bound to SuperbDB on ADDON_LOADED.
local DB = copyDefaults({}, DEFAULTS)
local bar, ticker
local baseTop = 0          -- Blizzard's own top offset (notch, debug bars)
local pendingPosition = false
local expectTop, expectBottom -- the UIParent offsets Superb last set
local tipWidget
local reported = {}

function S:DB() return DB end

function S:ModuleDB(id)
  local m = DB.modules[id]
  if not m then m = {} DB.modules[id] = m end
  return m
end

function S:Theme() return S.Themes[DB.theme] or S.Themes[S.DEFAULT_THEME] end
function S:Position() return DB.position end
function S:Bar() return bar end

function S:IsEnabled(def)
  local m = DB.modules[def.id]
  if m and m.enabled ~= nil then return m.enabled end
  return def.defaultEnabled ~= false
end

-- Layout ----------------------------------------------------------------------------------------------------

-- Where an item sits: the player's choice (Shift+drag) if any, else the module's default.
function S:Side(def)
  local m = DB.modules[def.id]
  return m and m.side or def.side
end

function S:Order(def)
  local m = DB.modules[def.id]
  return m and m.order or def.order
end

local function byOrder(a, b)
  local oa, ob = S:Order(a), S:Order(b)
  if oa ~= ob then return oa < ob end
  return a.id < b.id
end

-- Secure items (spell buttons) cannot be moved, resized, shown or hidden in combat. Superb catches up when
-- combat ends. Items anchored to a secure item may still change.
local pendingLayout = false
local pendingSecure = {}
local function movable(w) return not (w.secure and InCombatLockdown()) end

function S:Layout()
  if not bar then return end
  local t = S:Theme()
  local left, right, centre = {}, {}, {}
  for _, def in ipairs(S.modules) do
    if def.widget and def.widget:IsShown() then
      local side = S:Side(def)
      local list = side == "right" and right or side == "centre" and centre or left
      list[#list + 1] = def
    end
  end
  table.sort(left, byOrder)
  table.sort(right, byOrder)
  table.sort(centre, byOrder)
  local width = 0
  for n, def in ipairs(centre) do width = width + (def.widget.width or 0) + (n > 1 and t.spacing or 0) end
  local prevCentre
  for _, def in ipairs(centre) do
    local w = def.widget
    if movable(w) then
      w:ClearAllPoints()
      if prevCentre then w:SetPoint("LEFT", prevCentre, "RIGHT", t.spacing, 0) else w:SetPoint("LEFT", bar, "CENTER", -width / 2, 0) end
    end
    prevCentre = w
  end
  local prev
  for _, def in ipairs(left) do
    local w = def.widget
    if movable(w) then
      w:ClearAllPoints()
      if prev then w:SetPoint("LEFT", prev, "RIGHT", t.spacing, 0) else w:SetPoint("LEFT", bar, "LEFT", t.spacing, 0) end
    end
    prev = w
  end
  prev = nil
  for _, def in ipairs(right) do
    local w = def.widget
    if movable(w) then
      w:ClearAllPoints()
      if prev then w:SetPoint("RIGHT", prev, "LEFT", -t.spacing, 0) else w:SetPoint("RIGHT", bar, "RIGHT", -t.spacing, 0) end
    end
    prev = w
  end
  if InCombatLockdown() then pendingLayout = true end
end

local function applyPosition()
  if not bar then return end
  if InCombatLockdown() then pendingPosition = true return end
  pendingPosition = false
  local t = S:Theme()
  local h = t.height
  local top = DB.position ~= "bottom"
  expectTop, expectBottom = -(baseTop + (top and h or 0)), top and 0 or h
  UIParent:SetPoint("TOPLEFT", 0, expectTop)
  UIParent:SetPoint("BOTTOMRIGHT", 0, expectBottom)
  -- The bar hangs on the screen edge (WorldFrame), not on UIParent's moving edge, so it stays on screen even
  -- if something else moves UIParent back.
  bar:ClearAllPoints()
  bar.edge:ClearAllPoints()
  if top then
    bar:SetPoint("TOPLEFT", WorldFrame, "TOPLEFT", 0, -baseTop)
    bar:SetPoint("TOPRIGHT", WorldFrame, "TOPRIGHT", 0, -baseTop)
    bar.edge:SetPoint("BOTTOMLEFT")
    bar.edge:SetPoint("BOTTOMRIGHT")
  else
    bar:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT", WorldFrame, "BOTTOMRIGHT")
    bar.edge:SetPoint("TOPLEFT")
    bar.edge:SetPoint("TOPRIGHT")
  end
  bar:SetHeight(h)
end

-- UIParent's offset as a number, or nil when it cannot be read.
local function offsetY(point)
  local ok, _, _, _, _, y = pcall(UIParent.GetPointByName, UIParent, point)
  if not ok or type(y) ~= "number" or (issecretvalue and issecretvalue(y)) then return nil end
  return y
end

-- Puts the offset back if something else moved UIParent. Runs every second, out of combat only.
local function healPosition()
  if not bar or not expectTop or InCombatLockdown() then return end
  local top, bottom = offsetY("TOPLEFT"), offsetY("BOTTOMRIGHT")
  if (top and math.abs(top - expectTop) > 0.5) or (bottom and math.abs(bottom - expectBottom) > 0.5) then
    applyPosition()
  end
end

-- Theme -----------------------------------------------------------------------------------------------------

local function styleWidget(w, t)
  w.label:SetFont(t.font, t.size, t.flags)
  w.label:SetTextColor(unpack(t.text))
  if t.shadow then
    w.label:SetShadowOffset(1, -1)
    w.label:SetShadowColor(0, 0, 0, 1)
  else
    w.label:SetShadowOffset(0, 0)
  end
  w.hl:SetColorTexture(unpack(t.highlight))
  w:SetHeight(t.height)
  w.text, w.width = nil, nil
end

local function styleBar(t)
  if t.bgTexture then
    bar.bg:SetTexture(t.bgTexture, "REPEAT", "REPEAT")
    bar.bg:SetHorizTile(true)
    bar.bg:SetVertTile(true)
    bar.bg:SetVertexColor(unpack(t.bg))
  else
    bar.bg:SetColorTexture(unpack(t.bg))
    bar.bg:SetVertexColor(1, 1, 1, 1)
  end
  bar.edge:SetColorTexture(unpack(t.edge))
  bar.edge:SetHeight(t.edgeSize)
  for _, def in ipairs(S.modules) do
    if def.widget then styleWidget(def.widget, t) end
  end
end

-- Widgets and tooltips --------------------------------------------------------------------------------------

function S:RenderTooltip(w)
  local tip = GameTooltip
  tip:SetOwner(w, "ANCHOR_NONE")
  tip:ClearAllPoints()
  local right = S:Side(w.def) == "right"
  if DB.position == "bottom" then
    tip:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", w, right and "TOPRIGHT" or "TOPLEFT", 0, 2)
  else
    tip:SetPoint(right and "TOPRIGHT" or "TOPLEFT", w, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -2)
  end
  w.def.Tooltip(w, tip)
  tip:Show()
end

local function hideTooltip()
  if tipWidget then tipWidget = nil GameTooltip:Hide() end
end

local function report(def, err)
  if reported[def.id] then return end
  reported[def.id] = true
  geterrorhandler()(("Superb module %s: %s"):format(def.id, tostring(err)))
end

-- The thin line that replaces Format.SEP: a white texture tinted with the theme's sep colour, about the height of
-- a capital letter. WHITE8X8 is used by other Forever addons (DBM, LibSharedMedia); the tint fields follow
-- Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua. It is one physical pixel wide (PixelUtil, as Blizzard's
-- pixel-perfect frames do): a width of 1 UI unit covers one or two pixels depending on where the text puts it.
-- The game accepts a fractional width here (checked in game, 2026-11-07).
local function separator(label)
  local t = S:Theme()
  local function c(v) return math.floor(v * 255 + 0.5) end
  local width = PixelUtil.GetPixelToUIUnitFactor() / label:GetEffectiveScale()
  return ("  |TInterface\\Buttons\\WHITE8X8:%d:%.3f:0:0:8:8:0:8:0:8:%d:%d:%d|t  "):format(
    math.floor(t.size * 0.7 + 0.5), width, c(t.sep[1]), c(t.sep[2]), c(t.sep[3]))
end

function S:Refresh(ref)
  local def = type(ref) == "table" and ref or byId[ref]
  local w = def and def.widget
  if not w then return end
  local text
  local enabled = S:IsEnabled(def)
  if enabled then
    local ok, res = pcall(def.Text, w)
    if ok then text = res else report(def, res) text = "?" end
    if type(text) == "string" then text = text:gsub(S.Format.SEP, separator(w.label)) end
  end
  if def.OnRefresh then
    local ok, err = pcall(def.OnRefresh, w, enabled)
    if not ok then report(def, err) end
  end
  local show = text ~= nil and text ~= ""
  local locked = not movable(w)
  if locked and not show then text = "" end
  if show or locked then
    if text ~= w.text then
      w.text = text
      w.label:SetText(text)
    end
    local width = math.ceil(w.label:GetStringWidth()) + 2 * S:Theme().pad + (w.leftInset or 0)
    if width ~= w.width then
      if locked then
        pendingLayout = true
      else
        w.width = width
        w:SetWidth(width)
        if S:Side(def) == "centre" and w:IsShown() then S:Layout() end
      end
    end
  end
  if locked then
    if show ~= w:IsShown() then pendingLayout = true end
  elseif show ~= w:IsShown() then
    w:SetShown(show)
    S:Layout()
  end
  if tipWidget == w then
    if show then S:RenderTooltip(w) else hideTooltip() end
  end
end

function S:RefreshAll()
  for _, def in ipairs(S.modules) do S:Refresh(def) end
end

local function onEnter(w)
  w.hl:Show()
  if w.def.Tooltip then
    tipWidget = w
    S:RenderTooltip(w)
  end
end

local function onLeave(w)
  w.hl:Hide()
  if tipWidget == w then hideTooltip() end
end

local function onClick(w, button)
  if button == "LeftButton" and IsShiftKeyDown() then return end -- Shift+left is for moving
  if button == "RightButton" then
    S:OpenMenu(w)
  elseif w.def.OnClick then
    w.def.OnClick(w, button)
  end
end

local function setupSecure(def)
  local w = def.widget
  if not w or not w.secure then return end
  if InCombatLockdown() then pendingSecure[def] = true return end
  pendingSecure[def] = nil
  w:SetAttribute("shift-type1", ATTRIBUTE_NOOP) -- Shift+left-drag moves the item
  w:SetAttribute("shift-type2", ATTRIBUTE_NOOP) -- Shift+right-click opens the menu (PostClick)
  if def.Setup then def.Setup(w) end
end

-- Sets a secure item's attributes again, now or when combat ends.
function S:Setup(ref)
  setupSecure(type(ref) == "table" and ref or byId[ref])
end

local function onPostClick(w, button, down)
  if down then return end
  if button == "RightButton" and IsShiftKeyDown() then S:OpenMenu(w) end
end

local function createWidget(def)
  if def.secure and InCombatLockdown() then pendingSecure[def] = "create" return end
  local w = CreateFrame("Button", nil, bar, def.secure and "SecureActionButtonTemplate" or nil)
  w.def = def
  w.secure = def.secure and true or nil
  w.hl = w:CreateTexture(nil, "BACKGROUND", nil, 1)
  w.hl:SetPoint("TOPLEFT", 0, -2)
  w.hl:SetPoint("BOTTOMRIGHT", 0, 2)
  w.hl:Hide()
  w.label = w:CreateFontString(nil, "OVERLAY")
  w.label:SetPoint("CENTER")
  w:SetScript("OnEnter", onEnter)
  w:SetScript("OnLeave", onLeave)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", S.DragStart)
  w:SetScript("OnDragStop", S.DragStop)
  if w.secure then
    -- Down and up, so the click works whatever the "cast on key down" setting is (SecureTemplates.lua).
    w:RegisterForClicks("AnyUp", "AnyDown")
    w:SetScript("PostClick", onPostClick)
  else
    w:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    w:SetScript("OnClick", onClick)
  end
  w:Hide()
  def.widget = w
  styleWidget(w, S:Theme())
  if def.events then
    w:SetScript("OnEvent", function(self, event, ...)
      if def.OnEvent and def.OnEvent(self, event, ...) == false then return end
      S:Refresh(def)
    end)
    for _, event in ipairs(def.events) do
      if not pcall(w.RegisterEvent, w, event) then print("Superb: event not available: " .. event) end
    end
  end
  if def.OnLoad then def.OnLoad(w) end
  setupSecure(def)
  S:Refresh(def)
end

-- Module API ------------------------------------------------------------------------------------------------
-- def = {
--   id = "unique", name = "Menu label", side = "left" | "centre" | "right", order = number (lower is nearer
--   the edge; in the centre, lower is further left),
--   Text = function(widget) return "bar text" end,       -- nil or "" hides the item; Format.SEP splits parts
--   Tooltip = function(widget, GameTooltip) end,         -- optional
--   OnClick = function(widget, button) end,              -- optional, left click
--   Menu = function(widget, rootDescription) end,        -- optional, added to the right-click menu
--   events = { "EVENT" }, OnEvent = function(widget, event, ...) end,  -- optional; the item refreshes after each
--                                                    event unless OnEvent returns false
--   tick = true,                                         -- optional, refresh every second
--   OnLoad = function(widget) end,                       -- optional, once, after saved data is loaded
--   secure = true, Setup = function(widget) end,         -- optional: a SecureActionButtonTemplate item that casts
--                                                        -- spells; Setup sets its attributes, out of combat only.
--                                                        -- Shift+right-click opens its menu. Call Superb:Setup(id)
--                                                        -- when the attributes must change.
--   widget.leftInset = pixels                            -- optional, room for an icon left of the text
--   OnRefresh = function(widget, enabled) end,           -- optional, after each refresh, for items that draw
--                                                        -- on the bar instead of showing text
--   defaultEnabled = false,                              -- optional
-- }
-- Superb:AddMenu(function(rootDescription) end) adds a section to the Superb menu.

function S:RegisterModule(def)
  assert(type(def.id) == "string" and not byId[def.id], "Superb: a module needs a unique id")
  assert(type(def.Text) == "function", "Superb: a module needs a Text function")
  def.side = (def.side == "right" or def.side == "centre") and def.side or "left"
  def.order = def.order or 50
  def.name = def.name or def.id
  byId[def.id] = def
  S.modules[#S.modules + 1] = def
  if bar then
    createWidget(def)
    S:Layout()
  end
  return def
end

function S:SetEnabled(def, on)
  S:ModuleDB(def.id).enabled = on and true or false
  S:Refresh(def)
end

function S:SetPosition(position)
  DB.position = position == "bottom" and "bottom" or "top"
  hideTooltip()
  applyPosition()
  S:RefreshAll()
end

function S:SetTheme(key)
  if not S.Themes[key] or key == "order" then return false end
  DB.theme = key
  if bar then
    styleBar(S:Theme())
    applyPosition()
    S:RefreshAll()
  end
  return true
end

-- Moving items ----------------------------------------------------------------------------------------------
-- Shift+drag an item; a marker shows where it lands. The zone (left, centre, right third of the bar) and the
-- place in it are saved per item. Secure items move out of combat only.

local dragging

local function cursorX()
  return GetCursorPosition() / bar:GetEffectiveScale() - bar:GetLeft()
end

-- The zone, the new order of ids in it, and the item the dragged one lands before.
local function dropTarget(w)
  local x = cursorX()
  local side = S.Arrange.Zone(x, bar:GetWidth())
  local others = {}
  for _, def in ipairs(S.modules) do
    local o = def.widget
    if o and o ~= w and o:IsShown() and S:Side(def) == side then
      others[#others + 1] = { id = def.id, x = (o:GetCenter()) - bar:GetLeft() }
    end
  end
  local ids, before = S.Arrange.Insert(others, side, w.def.id, x)
  return side, ids, before
end

local function placeMarker(w)
  local side, ids, before = dropTarget(w)
  local t = S:Theme()
  local m = bar.marker
  m:ClearAllPoints()
  local target = before and byId[before].widget
  if target then
    if side == "right" then m:SetPoint("LEFT", target, "RIGHT", t.spacing / 2 - 1, 0) else m:SetPoint("RIGHT", target, "LEFT", -t.spacing / 2 + 1, 0) end
  else
    local last = #ids > 1 and byId[ids[#ids - 1]].widget
    if last then
      if side == "right" then m:SetPoint("RIGHT", last, "LEFT", -t.spacing / 2 + 1, 0) else m:SetPoint("LEFT", last, "RIGHT", t.spacing / 2 - 1, 0) end
    elseif side == "left" then m:SetPoint("LEFT", bar, "LEFT", 2, 0)
    elseif side == "right" then m:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    else m:SetPoint("CENTER", bar, "CENTER") end
  end
  m:SetHeight(t.height - 6)
  m:SetColorTexture(t.text[1], t.text[2], t.text[3], 0.8)
  m:Show()
end

function S.DragStart(w)
  if not IsShiftKeyDown() or (w.secure and InCombatLockdown()) then return end
  dragging = w
  hideTooltip()
  placeMarker(w)
  bar:SetScript("OnUpdate", function() if dragging then placeMarker(dragging) end end)
end

function S.DragStop(w)
  if dragging ~= w then return end
  dragging = nil
  bar:SetScript("OnUpdate", nil)
  bar.marker:Hide()
  local side, ids = dropTarget(w)
  for i, id in ipairs(ids) do
    local m = S:ModuleDB(id)
    m.side, m.order = side, i * 10
  end
  S:Layout()
  if S:Side(w.def) == "centre" then S:Layout() end
end

function S:ResetPositions()
  for _, m in pairs(DB.modules) do m.side, m.order = nil, nil end
  S:Layout()
end

-- Menu ------------------------------------------------------------------------------------------------------

local menuExtras = {}
function S:AddMenu(fn) menuExtras[#menuExtras + 1] = fn end

local function buildMenu(root)
  root:CreateTitle("Superb")
  local position = root:CreateButton("Position")
  local function isPosition(p) return DB.position == p end
  local function setPosition(p) S:SetPosition(p) end
  position:CreateRadio("Top", isPosition, setPosition, "top")
  position:CreateRadio("Bottom", isPosition, setPosition, "bottom")

  local theme = root:CreateButton("Theme")
  local function isTheme(key) return DB.theme == key end
  local function setTheme(key) S:SetTheme(key) end
  for _, key in ipairs(S.Themes.order) do theme:CreateRadio(S.Themes[key].name, isTheme, setTheme, key) end

  local modules = root:CreateButton("Modules")
  local sorted = {}
  for _, def in ipairs(S.modules) do sorted[#sorted + 1] = def end
  table.sort(sorted, function(a, b) return a.name < b.name end)
  local function isOn(def) return S:IsEnabled(def) end
  local function toggle(def) S:SetEnabled(def, not S:IsEnabled(def)) end
  for _, def in ipairs(sorted) do modules:CreateCheckbox(def.name, isOn, toggle, def) end
  modules:CreateDivider()
  modules:CreateButton("Reset item positions", function() S:ResetPositions() end)
  for _, fn in ipairs(menuExtras) do fn(root) end
end

function S:OpenMenu(owner)
  hideTooltip()
  local def = owner and owner.def
  MenuUtil.CreateContextMenu(owner, function(_, root)
    if def and def.Menu then
      def.Menu(owner, root)
      root:CreateDivider()
    end
    buildMenu(root)
  end)
end

-- The bar's own first item, like the menu at the left of a macOS menu bar.
S:RegisterModule({
  id = "superb", name = "Superb menu", side = "left", order = 0,
  Text = function() return "Superb" end,
  OnClick = function(w) S:OpenMenu(w) end,
})

-- Start -----------------------------------------------------------------------------------------------------

local function start()
  bar = CreateFrame("Frame", "SuperbBar", UIParent)
  bar:SetFrameStrata("HIGH")
  bar:EnableMouse(true)
  bar:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then S:OpenMenu(nil) end end)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  bar.bg:SetAllPoints()
  bar.edge = bar:CreateTexture(nil, "BORDER")
  bar.marker = bar:CreateTexture(nil, "OVERLAY")
  bar.marker:SetWidth(2)
  bar.marker:Hide()
  styleBar(S:Theme())
  for _, def in ipairs(S.modules) do createWidget(def) end
  S:Layout()
  applyPosition()
  ticker = C_Timer.NewTicker(1, function()
    healPosition()
    for _, def in ipairs(S.modules) do
      if def.tick then S:Refresh(def) end
    end
    if tipWidget and not tipWidget.def.tick then S:RenderTooltip(tipWidget) end
  end)
end

if type(UpdateUIParentPosition) == "function" then
  hooksecurefunc("UpdateUIParentPosition", function()
    local y = offsetY("TOPLEFT")
    if y then baseTop = y < 0 and -y or 0 end
    applyPosition()
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    SuperbDB = copyDefaults(SuperbDB or {}, DEFAULTS)
    if not S.Themes[SuperbDB.theme] or SuperbDB.theme == "order" then SuperbDB.theme = S.DEFAULT_THEME end
    DB = SuperbDB
  elseif event == "PLAYER_LOGIN" then
    start()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendingPosition then applyPosition() end
    for def, what in pairs(pendingSecure) do
      if what == "create" then
        pendingSecure[def] = nil
        createWidget(def)
      else
        setupSecure(def)
      end
    end
    if pendingLayout then
      pendingLayout = false
      S:RefreshAll()
      S:Layout()
    end
  end
end)

-- Slash command ---------------------------------------------------------------------------------------------

SLASH_SUPERB1 = "/superb"
SlashCmdList.SUPERB = function(msg)
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
  if cmd == "top" or cmd == "bottom" then
    S:SetPosition(cmd)
  elseif cmd == "theme" then
    local found
    for _, key in ipairs(S.Themes.order) do
      if key:lower() == arg then found = key end
    end
    if not (found and S:SetTheme(found)) then
      print("Superb themes: " .. table.concat(S.Themes.order, ", "))
    end
  elseif cmd == "debug" then
    local function n(v) return v and ("%.1f"):format(v) or "?" end
    print(("Superb: position %s, theme %s, height %s, Blizzard top %s, combat %s, waiting %s"):format(
      DB.position, DB.theme, n(S:Theme().height), n(baseTop), tostring(InCombatLockdown()), tostring(pendingPosition)))
    print(("Superb: UIParent top %s (want %s), bottom %s (want %s); bar shown %s, top %s, bottom %s"):format(
      n(offsetY("TOPLEFT")), n(expectTop), n(offsetY("BOTTOMRIGHT")), n(expectBottom),
      tostring(bar and bar:IsVisible()), n(bar and bar:GetTop()), n(bar and bar:GetBottom())))
  elseif cmd == "toast" then
    S:TestNotify(arg)
  elseif cmd == "reset" then
    DB.position, DB.theme = DEFAULTS.position, DEFAULTS.theme
    S:SetTheme(DB.theme)
    S:SetPosition(DB.position)
  else
    print("Superb: /superb top | bottom | theme <name> | toast [type|all] | reset | debug. Right-click the bar for the menu.")
    if bar then S:OpenMenu(nil) end
  end
end
