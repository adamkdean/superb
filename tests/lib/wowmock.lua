-- A small stub of the WoW client for mock tests: frames, points, events, timers, tooltip, menu and the game
-- state Superb reads. Not a game test. Only methods seen in the Blizzard API docs are stubbed, and
-- an unknown method (a capitalised name) is an error, so a typo in an addon fails here.
local M = { time = 1000, serverBase = 1800000000, frames = {}, textures = {}, tickers = {}, timers = {}, errors = {}, printed = {} }

M.state = {
  level = 23, xp = 4000, xpMax = 10000, maxLevel = 60, rested = 1500, resting = false, xpDisabled = false,
  money = 123456, afk = false, moving = false, combat = false, lockdown = false,
  guild = false, group = nil, chatLockdown = false,  -- group: nil, "party", "raid" or "instance"
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
  itemInstant = {},  -- by item ID: { subType, icon, classID, subClassID } for C_Item.GetItemInfoInstant
  ammo = nil,        -- the ammo slot: { icon, count }
  fps = 59.6, latencyHome = 40, latencyWorld = 45,
  zone = "Elwynn Forest", subzone = "Goldshire", mapPos = { 0.4213, 0.6578 },
  nameplates = {},  -- nameplate unit token -> nameplate frame; none for a forbidden plate
  questUnits = {},  -- nameplate unit token -> true when an active quest needs that unit
  cvars = { nameplateShowEnemies = true },
  durability = { [1] = { 80, 100 }, [5] = { 30, 60 }, [16] = { 100, 100 } },
  newMail = false, mailSenders = { "Alice" },
  professions = {},  -- by GetProfessions slot (1, 2 primary; 3 to 7 secondary): { name, icon, rank, max, skillLine }
  auras = {},  -- player auras by spell ID: { name, applications, expirationTime, tip, harmful }
  aurasSecret = false,  -- aura data restricted out of combat
  pet = nil,  -- set to { name, level, family, happiness, damage, rate, loyalty, hp, hpMax, dead, xp, xpNeed, diet, eats }
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

local function new(kind, parent, template)
  local r = setmetatable({ kind = kind, parent = parent, template = template, points = {}, scripts = {}, events = {},
    unitEvents = {}, attributes = {}, shown = true, width = 0, height = 0 }, Region)
  if kind == "Frame" or kind == "Button" then M.frames[#M.frames + 1] = r end
  return r
end

-- The game blocks these on a secure frame in combat; the mock raises an error so tests catch it.
local function guard(self, what)
  if self.template == "SecureActionButtonTemplate" and M.state.lockdown then
    M.blocked = (M.blocked or 0) + 1
    error("mock: " .. what .. " on a secure frame in combat", 3)
  end
end
function Region:SetPoint(...) guard(self, "SetPoint") local p, v = point({ ... }) self.points[p] = v end
function Region:ClearAllPoints() guard(self, "ClearAllPoints") self.points = {} end
function Region:SetAttribute(k, v) guard(self, "SetAttribute") self.attributes[k] = v end
function Region:GetAttribute(k) return self.attributes[k] end
function Region:SetStatusBarTexture() end
function Region:SetStatusBarColor(...) self.barColour = { ... } end
function Region:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Region:SetValue(v) self.value = v end
function Region:SetAllPoints() self.points.ALL = true end
function Region:GetPointByName(p)
  local v = self.points[p]
  if v then return p, v.rel, v.relPoint, v.x, v.y end
end
function Region:SetHeight(h) self.height = h end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:RegisterForDrag() end
-- No layout engine: tests set cx (centre x) on the items they drag around.
function Region:GetCenter() return self.cx or 0, 0 end
function Region:GetLeft() return 0 end
function Region:GetEffectiveScale() return M.uiScale or 1 end
function Region:SetWidth(w) guard(self, "SetWidth") self.width = w end
function Region:GetHeight() return self.height end
function Region:GetWidth() return self.width > 0 and self.width or 1000 end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetJustifyH() end
function Region:SetWordWrap() end
function Region:GetStringHeight() return self.text and 12 or 0 end
function Region:Show() guard(self, "Show") self.shown = true end
function Region:Hide() guard(self, "Hide") self.shown = false end
function Region:SetShown(v) guard(self, "SetShown") self.shown = v and true or false end
function Region:IsShown() return self.shown end
function Region:IsVisible() return self.shown end
function Region:GetTop() return 768 end
function Region:GetBottom() return 744 end
function Region:SetScript(n, fn) self.scripts[n] = fn end
function Region:RegisterEvent(e)
  if M.invalidEvents and M.invalidEvents[e] then error("unknown event " .. e) end
  self.events[e] = true
end
function Region:RegisterUnitEvent(e, unit) self.events[e] = true self.unitEvents[e] = unit end
function Region:UnregisterAllEvents() self.events = {} end
function Region:UnregisterEvent(e) self.events[e] = nil end
function Region:CreateTexture() local t = new("Texture", self) M.textures[#M.textures + 1] = t return t end
function Region:CreateFontString() return new("FontString", self) end
function Region:SetFrameStrata(s) self.strata = s end
function Region:EnableMouse() end
function Region:RegisterForClicks() end
function Region:SetColorTexture(...) self.colour = { ... } end
function Region:SetTexture(t) self.texture = t end
function Region:SetHorizTile() end
function Region:SetVertTile() end
function Region:SetVertexColor() end
function Region:SetAtlas(a) self.atlas = a end
function Region:SetBlendMode(m) self.blendMode = m end
-- An animation group records its animations and whether it plays.
function Region:CreateAnimationGroup()
  local g = { anims = {}, playing = false }
  function g:CreateAnimation(kind)
    local a = { kind = kind }
    function a:SetOffset(x, y) self.offset = { x, y } end
    function a:SetDuration(d) self.duration = d end
    function a:SetSmoothing(s) self.smoothing = s end
    self.anims[#self.anims + 1] = a
    return a
  end
  function g:SetLooping(l) self.looping = l end
  function g:Play() self.playing = true end
  function g:Stop() self.playing = false end
  return g
end
function Region:SetFont(f, s, flags)
  assert(type(f) == "string" and type(s) == "number" and type(flags) == "string", "SetFont arguments")
  self.font = f
end
function Region:SetTextColor() end
function Region:SetShadowOffset() end
function Region:SetShadowColor() end
function Region:SetText(t) self.text = t end
-- A secret argument draws, but marks the text secret until ClearText, as in game: its width is then secret too.
function Region:SetFormattedText(fmt, ...)
  local args = { ... }
  for _, v in ipairs(args) do if v == "SECRET" then self.secretText = true end end
  if self.secretText then
    for i, v in ipairs(args) do args[i] = tostring(v) end
    fmt = fmt:gsub("%%[%d%.]*[df]", "%%s")
  end
  self.text = fmt:format(table.unpack(args))
end
function Region:ClearText() self.text, self.secretText = "", nil end
function Region:GetStringWidth()
  if self.secretText then error("mock: the width of secret text is secret", 2) end
  return #(self.text or "") * 7
end

-- Globals ---------------------------------------------------------------------------------------------------

local S = M.state

function M.install()
  WorldFrame = new("Frame")
  UIParent = new("Frame")
  UIParent:SetPoint("TOPLEFT")
  UIParent:SetPoint("BOTTOMRIGHT")
  function UpdateUIParentPosition() UIParent:SetPoint("TOPLEFT", 0, -S.topOffset) end
  function hooksecurefunc(name, fn)
    local orig = _G[name]
    _G[name] = function(...) orig(...) fn(...) end
  end
  function CreateFrame(kind, _, parent, template)
    if template == "SecureActionButtonTemplate" and S.lockdown then error("mock: secure frame created in combat") end
    return new(kind, parent, template)
  end
  ATTRIBUTE_NOOP = ""
  function IsShiftKeyDown() return M.shift end
  function GetCursorPosition() return M.cursorX or 0, 0 end
  function InCombatLockdown() return S.lockdown end
  function GetTime() return M.time end
  -- UI units per physical pixel: 768 / screen height (Blizzard_SharedXML/PixelUtil.lua).
  PixelUtil = { GetPixelToUIUnitFactor = function() return M.pixelFactor or 0.5 end }
  -- Local time is pinned to Thu 6 Nov 2026 13:05, like the realm time below, so clock tests pass at any hour.
  date = function(fmt, t) return os.date(fmt, t or os.time({ year = 2026, month = 11, day = 6, hour = 13, min = 5 })) end
  unpack = table.unpack  -- a global in the game's Lua 5.1
  function GetServerTime() return M.serverBase + math.floor(M.time) end
  function GetSessionTime() return S.session end
  function GetGameTime() return S.gameHour, S.gameMinute end
  C_DateAndTime = { GetCurrentCalendarTime = function() return { weekday = 5, monthDay = 6, month = 11, year = 2026, hour = 13, minute = 5 } end }
  C_NamePlate = { GetNamePlateForUnit = function(unit) return S.nameplates[unit] end }
  C_QuestLog = { UnitIsRelatedToActiveQuest = function(unit) return S.questUnits[unit] and true or false end }
  C_CVar = { GetCVarBool = function(name) return S.cvars[name] end }
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
  M.sounds = {}
  function PlaySoundFile(path, channel) M.sounds[#M.sounds + 1] = { path = path, channel = channel } return true end

  C_Timer = {
    NewTicker = function(sec, fn) local t = { sec = sec, fn = fn } M.tickers[#M.tickers + 1] = t return t end,
    After = function(sec, fn) M.timers[#M.timers + 1] = fn end,
  }
  C_CurrencyInfo = { GetCoinTextureString = function(c) return "COIN" .. c end }
  C_ClassColor = { GetClassColor = function() return { WrapTextInColorCode = function(_, s) return "|c" .. s end } end }

  function GetMoney() return S.money end
  function GetRealmName() return S.realm end
  function UnitName(u) if u == "pet" then return S.pet and S.pet.name end return S.name end
  function UnitClass() return "Class", S.class end
  function UnitLevel(u) if u == "pet" then return S.pet and S.pet.level end return S.level end
  function UnitExists(u) if u == "pet" then return S.pet ~= nil end return true end
  function HasPetUI() return S.pet ~= nil, S.pet ~= nil and S.class == "HUNTER" end
  -- Pet health is secret in combat, and on Forever always (petHealthSecret; checked in game, 2026-11-07).
  function UnitHealth(u) if u == "pet" and S.pet then return (S.lockdown or S.petHealthSecret) and "SECRET" or S.pet.hp end end
  function UnitHealthMax(u) if u == "pet" and S.pet then return S.lockdown and "SECRET" or S.pet.hpMax end end
  -- 0 to 1, or 0 to 100 with CurveConstants.ScaleTo100 (Blizzard_SharedXMLBase/CurveConstants.lua); secret with health.
  CurveConstants = { ScaleTo100 = {} }
  function UnitHealthPercent(u, _, curve)
    if u ~= "pet" or not S.pet then return 0 end
    if S.lockdown or S.petHealthSecret then return "SECRET" end
    local p = S.pet.hp / S.pet.hpMax
    return curve == CurveConstants.ScaleTo100 and p * 100 or p
  end
  function UnitIsDead(u) return u == "pet" and S.pet and S.pet.dead or false end
  function UnitPower(u) if u == "pet" and S.pet then return S.pet.mana end end
  function UnitPowerMax(u) if u == "pet" and S.pet then return S.pet.manaMax end end
  function UnitCreatureFamily() return S.pet and S.pet.family end
  function GetPetExperience() return S.pet and S.pet.xp, S.pet and S.pet.xpNeed end
  function SetPortraitTexture(tex, unit) tex.portrait = unit end
  C_PetInfo = {
    CanPetEatItem = function(id) return S.pet and S.pet.eats[id] or false end,
    GetPetHappiness = function() return S.pet.happiness, S.pet.damage, S.pet.rate end,
    GetPetLoyalty = function() return S.pet.loyalty end,
    GetPetFoodTypes = function() return S.pet.diet end,
    GetPetTrainingPoints = function() return 120, 80 end,
  }
  C_Spell = { GetSpellName = function(id) return id == 6991 and "Feed Pet" or nil end }
  function UnitXP() return S.xp end
  function UnitXPMax() return S.xpMax end
  function GetMaxPlayerLevel() return S.maxLevel end
  function GetXPExhaustion() return S.rested end
  function IsResting() return S.resting end
  -- Aura data is restricted in combat (SecretWhenUnitAuraRestricted, RequiresNonSecretAura). What the call then
  -- returns is not proved in game; the stub gives nil in combat, the worst case for an addon that trusts it.
  C_UnitAuras = { GetAuraDataByIndex = function(_, index, filter)
    if S.lockdown then return nil end
    local ids = {}
    for id, a in pairs(S.auras) do if (a.harmful and "HARMFUL" or "HELPFUL") == filter then ids[#ids + 1] = id end end
    table.sort(ids)
    local a = S.auras[ids[index]]
    if not a then return nil end
    if S.aurasSecret then return "SECRET" end
    a.spellId, a.auraInstanceID = ids[index], ids[index]
    return a
  end }
  -- Tooltip text: a buff's is its name, then its `tip`; a bag item's is its `tip`.
  C_TooltipInfo = {
    GetUnitBuffByAuraInstanceID = function(_, instance)
      local a = S.auras[instance]
      return { lines = { { leftText = a.name }, { leftText = a.tip } } }
    end,
    GetBagItem = function(bag, slot)
      local item = S.bags[bag] and S.bags[bag].items[slot]
      if item then return { lines = { { leftText = item.hyperlink }, { leftText = item.tip } } } end
    end,
  }
  function IsXPUserDisabled() return S.xpDisabled end
  function UnitIsAFK() return S.afk end
  function IsPlayerMoving() return S.moving end
  function UnitAffectingCombat() return S.combat end

  M.chat = {}
  LE_PARTY_CATEGORY_INSTANCE = 2
  function IsInGuild() return S.guild end
  function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_INSTANCE then return S.group == "instance" end
    return S.group ~= nil
  end
  function IsInRaid() return S.group == "raid" end
  C_ChatInfo = {
    SendChatMessage = function(msg, chatType) M.chat[#M.chat + 1] = { msg = msg, chatType = chatType } end,
    InChatMessagingLockdown = function() return S.chatLockdown end,
  }

  NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4, 5
  C_Container = {
    GetContainerNumSlots = function(bag) return S.bags[bag] and S.bags[bag].slots or 0 end,
    GetContainerNumFreeSlots = function(bag)
      local b = S.bags[bag]
      if not b then return 0, 0 end
      local used = 0
      for _ in pairs(b.items) do used = used + 1 end
      return b.slots - used, b.family or 0
    end,
    GetContainerItemInfo = function(bag, slot) return S.bags[bag] and S.bags[bag].items[slot] end,
    GetBagName = function(bag) return "Bag" .. bag end,
    ContainerIDToInventoryID = function(bag) return 100 + bag end,  -- a stub numbering: bag n is slot 100 + n
  }
  Enum = { ItemClass = { Quiver = 11 } }
  C_Item = {
    GetItemInfoInstant = function(id)
      local i = S.itemInstant[id]
      if i then return id, "Type", i.subType, "INVTYPE_BAG", i.icon, i.classID, i.subClassID end
    end,
    GetItemInfo = function(id)
      local p = S.sellPrice[id]
      if p == nil then return nil end
      return "name", "link", 1, S.itemLevel and S.itemLevel[id] or 1, 1, "t", "s", 20, "", 1, p
    end,
    RequestLoadItemDataByID = function(id) M.requested = id end,
  }

  function GetFramerate() return S.fps end
  function GetNetStats() return 1.5, 0.5, S.latencyHome, S.latencyWorld end
  function UpdateAddOnMemoryUsage() M.memoryUpdates = (M.memoryUpdates or 0) + 1 end
  function GetAddOnMemoryUsage(i) return i * 1024 end
  C_AddOns = { GetNumAddOns = function() return 2 end, GetAddOnInfo = function(i) return "Addon" .. i, "Addon " .. i end }
  function GetZoneText() return S.zone end
  function GetRealZoneText() return S.zone end
  function GetSubZoneText() return S.subzone end
  function GetMinimapZoneText() return S.subzone ~= "" and S.subzone or S.zone end
  C_Map = {
    GetBestMapForUnit = function() return S.mapPos and 1429 or nil end,
    GetPlayerMapPosition = function() local p = S.mapPos return p and { GetXY = function() return p[1], p[2] end } end,
  }
  INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED, INVSLOT_AMMO = 1, 19, 0
  function GetInventoryItemDurability(slot) local d = S.durability[slot] if d then return d[1], d[2] end end
  function GetInventoryItemLink(_, slot) return "[Item" .. slot .. "]" end
  -- The ammo slot (0) and equipped bags (100 + bag): S.ammo = { icon, count }, S.bags[n].bagItem = item ID.
  function GetInventoryItemID(_, slot)
    if slot >= 100 then local b = S.bags[slot - 100] return b and b.bagItem end
  end
  function GetInventoryItemTexture(_, slot) if slot == INVSLOT_AMMO then return S.ammo and S.ammo.icon end end
  function GetInventoryItemCount(_, slot) if slot == INVSLOT_AMMO then return S.ammo and S.ammo.count or 0 end end
  function HasNewMail() return S.newMail end
  function GetLatestThreeSenders() return table.unpack(S.mailSenders) end
  function ToggleWorldMap() M.mapToggled = (M.mapToggled or 0) + 1 end
  function GetProfessions()
    local function at(i) return S.professions[i] and i or nil end
    return at(1), at(2), at(3), at(4), at(5), at(6), at(7)
  end
  function GetProfessionInfo(i)
    local p = S.professions[i]
    if p then return p.name, p.icon, p.rank, p.max, 0, 0, p.skillLine, 0 end
  end

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

-- A client restart after `gap` seconds offline: every frame, timer and addon global is gone, GetTime() starts
-- again near zero, the server clock moves on, and the saved variables are kept.
function M.restart(gap, saved)
  local server = M.serverBase + math.floor(M.time)
  M.frames, M.textures, M.tickers, M.timers = {}, {}, {}, {}
  Superb = nil
  M.time = 50
  M.serverBase = server + gap - M.time
  M.install()
  for k, v in pairs(saved) do _G[k] = v end
end

-- Bar text has a hairline texture between segments; tests read it as " | ".
function M.plain(text) return (text:gsub("  |TInterface\\Buttons\\WHITE8X8:[^|]*|t  ", " | ")) end

function M.runTimers()
  local list = M.timers
  M.timers = {}
  for _, fn in ipairs(list) do fn() end
end

function M.load(addon, files, ns)
  ns = ns or {}
  for _, f in ipairs(files) do
    local chunk = assert(loadfile(addon .. "/" .. f))
    chunk(addon, ns)
  end
  return ns
end

-- Superb is one addon. Tests load the core, then the modules they need, into one shared namespace.
M.CORE_FILES = { "Format.lua", "Arrange.lua", "Themes.lua", "Core.lua", "Notify.lua", "Modules/Clock.lua", "Modules/Gold.lua",
  "Modules/Bags.lua", "Modules/Durability.lua", "Modules/Performance.lua", "Modules/Location.lua", "Modules/Professions.lua" }
M.LEVELLING_FILES = { "Modules/Levelling/Stats.lua", "Modules/Levelling/Levelling.lua", "Modules/Levelling/XPLine.lua",
  "Modules/Levelling/Bonus.lua" }
M.HUNTER_FILES = { "Modules/Hunter/Pet.lua", "Modules/Hunter/Hunter.lua" }
M.WARLOCK_FILES = { "Modules/Warlock/Warlock.lua" }
M.QUEST_FILES = { "Modules/Quests/QuestArrow.lua" }
M.ALL_FILES = {}
for _, list in ipairs({ M.CORE_FILES, M.LEVELLING_FILES, M.HUNTER_FILES, M.WARLOCK_FILES, M.QUEST_FILES }) do
  for _, f in ipairs(list) do M.ALL_FILES[#M.ALL_FILES + 1] = f end
end

-- Checks that each TOC lists exactly the files the test loads, so the test and the game load the same code.
function M.tocFiles(addon)
  local list = {}
  for line in io.lines(addon .. "/" .. addon .. ".toc") do
    if line ~= "" and not line:match("^#") then list[#list + 1] = (line:gsub("\\", "/")) end
  end
  return list
end

return M
