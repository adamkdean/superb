-- A small stub of the WoW client for mock tests: frames, points, events, timers, tooltip, menu and the game
-- state the Superb addons read. Not a game test. Only methods seen in the Blizzard API docs are stubbed, and
-- an unknown method (a capitalised name) is an error, so a typo in an addon fails here.
local M = { time = 1000, frames = {}, tickers = {}, timers = {}, errors = {}, printed = {} }

M.state = {
  level = 23, xp = 4000, xpMax = 10000, maxLevel = 60, rested = 1500, resting = false, xpDisabled = false,
  money = 123456, afk = false, moving = false, combat = false, lockdown = false,
  realm = "Testrealm", name = "Hero", class = "WARRIOR", session = 600,
  gameHour = 13, gameMinute = 5, topOffset = 0,
  bags = {
    [0] = { slots = 4, items = {
      [1] = { itemID = 1, stackCount = 2, quality = 0, hyperlink = "[Junk]", isBound = false, hasNoValue = false },
      [2] = { itemID = 2, stackCount = 1, quality = 2, hyperlink = "[Sword]", isBound = true, hasNoValue = false },
      [3] = { itemID = 3, stackCount = 5, quality = 1, hyperlink = "[Cloth]", isBound = false, hasNoValue = false },
    } },
    [1] = { slots = 6, items = {} },
  },
  sellPrice = { [1] = 100, [2] = 5000, [3] = 20 },
}

local function point(args)
  local p, a, b, c, d = table.unpack(args)
  if type(a) == "number" or a == nil then return p, { rel = nil, relPoint = p, x = a or 0, y = b or 0 } end
  if type(b) == "string" then return p, { rel = a, relPoint = b, x = c or 0, y = d or 0 } end
  return p, { rel = a, relPoint = p, x = b or 0, y = c or 0 }
end

local Region = {}
Region.__index = function(_, k)
  local v = rawget(Region, k)
  -- Frame methods are CapitalisedNames; other keys are an addon's own fields and may be nil.
  if v == nil and type(k) == "string" and k:match("^%u") then error("mock: no method " .. k, 2) end
  return v
end

local function new(kind, parent)
  local r = setmetatable({ kind = kind, parent = parent, points = {}, scripts = {}, events = {}, unitEvents = {},
    shown = true, width = 0, height = 0 }, Region)
  if kind == "Frame" or kind == "Button" then M.frames[#M.frames + 1] = r end
  return r
end

function Region:SetPoint(...) local p, v = point({ ... }) self.points[p] = v end
function Region:ClearAllPoints() self.points = {} end
function Region:SetAllPoints() self.points.ALL = true end
function Region:GetPointByName(p)
  local v = self.points[p]
  if v then return p, v.rel, v.relPoint, v.x, v.y end
end
function Region:SetHeight(h) self.height = h end
function Region:SetWidth(w) self.width = w end
function Region:GetHeight() return self.height end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetShown(v) self.shown = v and true or false end
function Region:IsShown() return self.shown end
function Region:SetScript(n, fn) self.scripts[n] = fn end
function Region:RegisterEvent(e)
  if M.invalidEvents and M.invalidEvents[e] then error("unknown event " .. e) end
  self.events[e] = true
end
function Region:RegisterUnitEvent(e, unit) self.events[e] = true self.unitEvents[e] = unit end
function Region:UnregisterAllEvents() self.events = {} end
function Region:UnregisterEvent(e) self.events[e] = nil end
function Region:CreateTexture() return new("Texture", self) end
function Region:CreateFontString() return new("FontString", self) end
function Region:SetFrameStrata(s) self.strata = s end
function Region:EnableMouse() end
function Region:RegisterForClicks() end
function Region:SetColorTexture(...) self.colour = { ... } end
function Region:SetTexture(t) self.texture = t end
function Region:SetHorizTile() end
function Region:SetVertTile() end
function Region:SetVertexColor() end
function Region:SetFont(f, s, flags)
  assert(type(f) == "string" and type(s) == "number" and type(flags) == "string", "SetFont arguments")
  self.font = f
end
function Region:SetTextColor() end
function Region:SetShadowOffset() end
function Region:SetShadowColor() end
function Region:SetText(t) self.text = t end
function Region:GetStringWidth() return #(self.text or "") * 7 end

-- Globals ---------------------------------------------------------------------------------------------------

local S = M.state

function M.install()
  UIParent = new("Frame")
  UIParent:SetPoint("TOPLEFT")
  UIParent:SetPoint("BOTTOMRIGHT")
  function UpdateUIParentPosition() UIParent:SetPoint("TOPLEFT", 0, -S.topOffset) end
  function hooksecurefunc(name, fn)
    local orig = _G[name]
    _G[name] = function(...) orig(...) fn(...) end
  end
  function CreateFrame(kind, _, parent) return new(kind, parent) end
  function InCombatLockdown() return S.lockdown end
  function GetTime() return M.time end
  date = os.date
  unpack = table.unpack  -- a global in the game's Lua 5.1
  function GetServerTime() return 1800000000 + M.time end
  function GetSessionTime() return S.session end
  function GetGameTime() return S.gameHour, S.gameMinute end
  C_DateAndTime = { GetCurrentCalendarTime = function() return { weekday = 5, monthDay = 6, month = 11, year = 2026, hour = 13, minute = 5 } end }
  function geterrorhandler() return function(e) M.errors[#M.errors + 1] = e end end
  print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end M.printed[#M.printed + 1] = table.concat(t, " ") end
  -- Plain Lua cannot make a truth test on a value fail, as the game does for a secret, so tests check that
  -- the addon asked issecretvalue about the secret before using it.
  M.secretChecks = 0
  function issecretvalue(v)
    if v == "SECRET" then M.secretChecks = M.secretChecks + 1 return true end
    return false
  end
  SlashCmdList = {}

  C_Timer = {
    NewTicker = function(sec, fn) local t = { sec = sec, fn = fn } M.tickers[#M.tickers + 1] = t return t end,
    After = function(sec, fn) M.timers[#M.timers + 1] = fn end,
  }
  C_CurrencyInfo = { GetCoinTextureString = function(c) return "COIN" .. c end }
  C_ClassColor = { GetClassColor = function() return { WrapTextInColorCode = function(_, s) return "|c" .. s end } end }

  function GetMoney() return S.money end
  function GetRealmName() return S.realm end
  function UnitName() return S.name end
  function UnitClass() return "Warrior", S.class end
  function UnitLevel() return S.level end
  function UnitXP() return S.xp end
  function UnitXPMax() return S.xpMax end
  function GetMaxPlayerLevel() return S.maxLevel end
  function GetXPExhaustion() return S.rested end
  function IsResting() return S.resting end
  function IsXPUserDisabled() return S.xpDisabled end
  function UnitIsAFK() return S.afk end
  function IsPlayerMoving() return S.moving end
  function UnitAffectingCombat() return S.combat end

  NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4, 5
  C_Container = {
    GetContainerNumSlots = function(bag) return S.bags[bag] and S.bags[bag].slots or 0 end,
    GetContainerNumFreeSlots = function(bag)
      local b = S.bags[bag]
      if not b then return 0, 0 end
      local used = 0
      for _ in pairs(b.items) do used = used + 1 end
      return b.slots - used, 0
    end,
    GetContainerItemInfo = function(bag, slot) return S.bags[bag] and S.bags[bag].items[slot] end,
    GetBagName = function(bag) return "Bag" .. bag end,
  }
  C_Item = {
    GetItemInfo = function(id)
      local p = S.sellPrice[id]
      if p == nil then return nil end
      return "name", "link", 1, 1, 1, "t", "s", 20, "", 1, p
    end,
    RequestLoadItemDataByID = function(id) M.requested = id end,
  }

  GameTooltip = { lines = {} }
  function GameTooltip:SetOwner(owner) self.owner = owner self.lines = {} end
  function GameTooltip:ClearAllPoints() end
  function GameTooltip:SetPoint(...) self.point = { ... } end
  function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = t end
  function GameTooltip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " = " .. r end
  function GameTooltip:Show() self.shown = true end
  function GameTooltip:Hide() self.shown = false end

  MenuUtil = { CreateContextMenu = function(owner, gen) M.menu = M.buildMenu(owner, gen) end }
end

-- A menu description that records elements and runs every callback once, as a click would.
function M.buildMenu(owner, gen)
  local function desc(label)
    local d = { label = label, children = {} }
    local function add(kind, text, a, b, data)
      local e = desc(text)
      e.kind = kind
      d.children[#d.children + 1] = e
      if kind == "radio" or kind == "checkbox" then
        e.selected = a(data)
        e.select = function() b(data) end
      elseif kind == "button" and a then
        e.click = function() a(data) end
      end
      return e
    end
    function d:CreateTitle(t) return add("title", t) end
    function d:CreateDivider() return add("divider", "-") end
    function d:CreateButton(t, fn, data) return add("button", t, fn, nil, data) end
    function d:CreateRadio(t, isSel, setSel, data) return add("radio", t, isSel, setSel, data) end
    function d:CreateCheckbox(t, isSel, setSel, data) return add("checkbox", t, isSel, setSel, data) end
    return d
  end
  local root = desc("root")
  gen(owner, root)
  return root
end

function M.find(menu, label)
  for _, e in ipairs(menu.children) do
    if e.label == label then return e end
    local sub = M.find(e, label)
    if sub then return sub end
  end
end

function M.fire(event, ...)
  for _, f in ipairs(M.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

function M.tick(n)
  for _ = 1, n or 1 do
    M.time = M.time + 1
    for _, t in ipairs(M.tickers) do t.fn() end
  end
end

function M.runTimers()
  local list = M.timers
  M.timers = {}
  for _, fn in ipairs(list) do fn() end
end

function M.load(addon, files, ns)
  ns = ns or {}
  for _, f in ipairs(files) do
    local chunk = assert(loadfile("addons/" .. addon .. "/" .. f))
    chunk(addon, ns)
  end
  return ns
end

M.SUPERB_FILES = { "Format.lua", "Themes.lua", "Core.lua", "Modules/Clock.lua", "Modules/Gold.lua", "Modules/Bags.lua" }
M.LEVELLING_FILES = { "Stats.lua", "Levelling.lua" }

-- Checks that each TOC lists exactly the files the test loads, so the test and the game load the same code.
function M.tocFiles(addon)
  local list = {}
  for line in io.lines("addons/" .. addon .. "/" .. addon .. ".toc") do
    if line ~= "" and not line:match("^#") then list[#list + 1] = (line:gsub("\\", "/")) end
  end
  return list
end

return M
