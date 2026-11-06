-- Superb: notifications that drop from the bar, like macOS alerts. Silent, at most three at a time, gone after
-- six seconds or a click. Any addon can send one:
--   Superb:RegisterNotification("kind", "Menu label")   -- once, so the player can turn the kind off
--   Superb:Notify("kind", "Title", "Text")
local S = Superb

local LIFE, FADE_IN, FADE_OUT, MAX, WIDTH = 6, 0.15, 0.6, 3, 280
local kinds, order = {}, {}
local shown, pool = {}, {}
local def

local function cfg() return S:ModuleDB("notifications") end

function S:RegisterNotification(kind, label)
  if kinds[kind] then return end
  kinds[kind] = label
  order[#order + 1] = kind
end

local function layout()
  local bar = S:Bar()
  local top = S:Position() ~= "bottom"
  local prev
  for _, t in ipairs(shown) do
    t:ClearAllPoints()
    if top then
      if prev then t:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -6) else t:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -8, -8) end
    else
      if prev then t:SetPoint("BOTTOMRIGHT", prev, "TOPRIGHT", 0, 6) else t:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -8, 8) end
    end
    prev = t
  end
end

local function release(t)
  t:Hide()
  for i, s in ipairs(shown) do
    if s == t then table.remove(shown, i) break end
  end
  pool[#pool + 1] = t
  layout()
end

local function onUpdate(t)
  local age = GetTime() - t.born
  if age < FADE_IN then
    t:SetAlpha(age / FADE_IN)
  elseif age < LIFE then
    t:SetAlpha(1)
  elseif age < LIFE + FADE_OUT then
    t:SetAlpha(1 - (age - LIFE) / FADE_OUT)
  else
    release(t)
  end
end

local function edge(t, a, b)
  local e = t:CreateTexture(nil, "BORDER")
  e:SetPoint(a)
  e:SetPoint(b)
  return e
end

local function create()
  local t = CreateFrame("Button", nil, UIParent)
  t:SetFrameStrata("DIALOG")
  t:SetWidth(WIDTH)
  t.bg = t:CreateTexture(nil, "BACKGROUND")
  t.bg:SetAllPoints()
  t.edges = { edge(t, "TOPLEFT", "TOPRIGHT"), edge(t, "BOTTOMLEFT", "BOTTOMRIGHT"), edge(t, "TOPLEFT", "BOTTOMLEFT"), edge(t, "TOPRIGHT", "BOTTOMRIGHT") }
  t.title = t:CreateFontString(nil, "OVERLAY")
  t.title:SetPoint("TOPLEFT", 12, -10)
  t.title:SetWidth(WIDTH - 24)
  t.title:SetJustifyH("LEFT")
  t.body = t:CreateFontString(nil, "OVERLAY")
  t.body:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -4)
  t.body:SetWidth(WIDTH - 24)
  t.body:SetJustifyH("LEFT")
  t.body:SetWordWrap(true)
  t:SetScript("OnUpdate", onUpdate)
  t:SetScript("OnClick", release)
  return t
end

local function style(t, theme)
  local r, g, b, a = unpack(theme.bg)
  if theme.bgTexture then
    t.bg:SetTexture(theme.bgTexture, "REPEAT", "REPEAT")
    t.bg:SetHorizTile(true)
    t.bg:SetVertTile(true)
  else
    t.bg:SetColorTexture(r, g, b, math.max(a, 0.92))
  end
  for i, e in ipairs(t.edges) do
    local er, eg, eb, ea = unpack(theme.edge)
    e:SetColorTexture(er, eg, eb, math.max(ea, 0.25))
    if i <= 2 then e:SetHeight(1) else e:SetWidth(1) end
  end
  t.title:SetFont(theme.font, theme.size + 1, theme.flags)
  t.body:SetFont(theme.font, theme.size, theme.flags)
  local tr, tg, tb = unpack(theme.text)
  t.title:SetTextColor(tr, tg, tb, 1)
  t.body:SetTextColor(tr, tg, tb, 0.85)
  for _, fs in ipairs({ t.title, t.body }) do
    if theme.shadow then fs:SetShadowOffset(1, -1) fs:SetShadowColor(0, 0, 0, 1) else fs:SetShadowOffset(0, 0) end
  end
end

-- Shows a notification if notifications are on and the kind is not turned off. Returns true when shown.
function S:Notify(kind, title, text)
  if not S:Bar() or not def or not S:IsEnabled(def) or cfg()[kind] == false then return false end
  local t = table.remove(pool) or create()
  style(t, S:Theme())
  t.kind = kind
  t.title:SetText(title)
  t.body:SetText(text or "")
  t:SetHeight(10 + t.title:GetStringHeight() + 4 + t.body:GetStringHeight() + 12)
  t.born = GetTime()
  t:SetAlpha(0)
  t:Show()
  table.insert(shown, 1, t)
  if #shown > MAX then release(shown[#shown]) end
  layout()
  return true
end

def = S:RegisterModule({
  id = "notifications", name = "Notifications", side = "right", order = 1000,
  Text = function() return nil end,
})

S:AddMenu(function(root)
  local sub = root:CreateButton("Notifications")
  local function isOn(kind) return cfg()[kind] ~= false end
  local function toggle(kind) cfg()[kind] = cfg()[kind] == false end
  for _, kind in ipairs(order) do sub:CreateCheckbox(kinds[kind], isOn, toggle, kind) end
  sub:CreateDivider()
  sub:CreateButton("Show a test notification", function()
    if not S:IsEnabled(def) then
      print("Superb: notifications are off. Turn them on under Modules.")
    else
      S:Notify("test", "Superb", "This is how a notification looks with this theme.")
    end
  end)
end)

-- New mail, from the same calls the minimap mail icon uses (Blizzard_Minimap/Mainline/Minimap.lua).
S:RegisterNotification("mail", "New mail")
local hadMail
local mail = CreateFrame("Frame")
mail:RegisterEvent("UPDATE_PENDING_MAIL")
mail:RegisterEvent("PLAYER_LOGIN")
mail:SetScript("OnEvent", function(_, event)
  local has = HasNewMail() and true or false
  if event == "UPDATE_PENDING_MAIL" and has and not hadMail then
    local names = {}
    for _, n in ipairs({ GetLatestThreeSenders() }) do
      if not (issecretvalue and issecretvalue(n)) and type(n) == "string" then names[#names + 1] = n end
    end
    S:Notify("mail", "New mail", #names > 0 and ("From " .. table.concat(names, ", ")) or "You have new mail.")
  end
  hadMail = has
end)
