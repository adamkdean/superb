-- Superb, warlock module: a demon item for the Superb bar. Shows the demon's name, level and health; casts Health
-- Funnel on a click; warns when the demon dies. Everything is set in its menu (Shift+right-click on the item).
local S, F = Superb, Superb.Format

local ID = "warlock.demon"
local HEALTH_FUNNEL_SPELL_ID = 755  -- Blizzard_NewPlayerExperience/Mainline/Blizzard_TutorialData.lua
local ICON = 16

local DEFAULTS = { show = { name = true, level = true, health = true }, left = "funnel", right = "none" }

local def
local wasDead

S:RegisterNotification("demon.died", "Demon died", "bad")

local function cfg()
  local c = S:ModuleDB(ID)
  for k, v in pairs(DEFAULTS) do
    if c[k] == nil then
      if type(v) == "table" then c[k] = {} for kk, vv in pairs(v) do c[k][kk] = vv end else c[k] = v end
    elseif type(v) == "table" then
      for kk, vv in pairs(v) do if c[k][kk] == nil then c[k][kk] = vv end end
    end
  end
  return c
end

-- A value, or nil when the game made it secret.
local function plain(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

local function hasDemon() return plain(UnitExists("pet")) end

-- By name, so the secure button casts the highest rank the warlock knows.
local function funnelName() return C_Spell.GetSpellName(HEALTH_FUNNEL_SPELL_ID) or "Health Funnel" end

local ACTIONS = { funnel = "Health Funnel", none = "Nothing" }

local function setAction(w, n, action)
  if action == "funnel" then
    w:SetAttribute("type" .. n, "spell")
    w:SetAttribute("spell" .. n, funnelName())
  else
    w:SetAttribute("type" .. n, ATTRIBUTE_NOOP)
  end
end

local function pair(cur, max)
  if not (cur and max and max > 0) then return nil end
  return ("%s / %s (%d%%)"):format(F.Thousands(cur), F.Thousands(max), F.Percent(cur, max))
end

-- The demon's health in percent, after the label. On Forever it is secret even out of combat (checked in game,
-- 2026-11-07): Superb cannot read it, but SetFormattedText takes it and the game draws it. UnitHealthPercent with
-- Blizzard's ScaleTo100 curve gives 0 to 100 without Lua maths (Blizzard_SharedXMLBase/CurveConstants.lua). The
-- width of secret text is secret, so the room for it is measured on the widest plain text, "100%".
local function showHealth(w, on)
  w.hp:ClearText()
  if not (on and cfg().show.health) then
    w.hp:Hide()
    w.rightInset = 0
    return
  end
  local t = S:Theme()
  w.hp:SetFont(t.font, t.size, t.flags)
  w.hp:SetTextColor(unpack(t.text))
  if t.shadow then w.hp:SetShadowOffset(1, -1) w.hp:SetShadowColor(0, 0, 0, 1) else w.hp:SetShadowOffset(0, 0) end
  local sep = S:Separator(w.label)
  w.hp:SetText(sep .. "100%")
  w.rightInset = math.ceil(w.hp:GetStringWidth())
  w.hp:SetFormattedText("%s%.0f%%", sep, UnitHealthPercent("pet", true, CurveConstants.ScaleTo100))
  w.hp:Show()
end

-- Bar item ----------------------------------------------------------------------------------------------------

def = {
  id = ID, name = "Warlock demon", side = "centre", order = 5, secure = true,  -- the centre is for class items
  events = { "UNIT_PET", "PET_UI_UPDATE" },

  OnLoad = function(w)
    w.leftInset = ICON + 4
    w.label:ClearAllPoints()
    w.label:SetPoint("LEFT", S:Theme().pad + ICON + 4, 0)
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(ICON, ICON)
    w.icon:SetPoint("LEFT", S:Theme().pad, 0)
    w.hp = w:CreateFontString(nil, "OVERLAY")
    w.hp:SetPoint("LEFT", w.label, "RIGHT", 0, 0)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_LEVEL", "UNIT_POWER_UPDATE" }) do
      pcall(w.RegisterUnitEvent, w, e, "pet")
    end
  end,

  OnEvent = function(_, event, unit)
    if event == "UNIT_PET" then
      if unit == "player" then wasDead = nil S:Setup(ID) end
    elseif event == "UNIT_HEALTH" then
      local dead = plain(UnitIsDead("pet"))
      if dead and not wasDead then
        S:Notify("demon.died", "Demon died",
          ("%s died. Summon it again before the next pull."):format(plain(UnitName("pet")) or "Your demon"))
      end
      wasDead = dead
    end
  end,

  Setup = function(w)
    setAction(w, 1, cfg().left)
    setAction(w, 2, cfg().right)
  end,

  Text = function()
    if not hasDemon() then return nil end
    local c = cfg().show
    local parts = {}
    local name, level = plain(UnitName("pet")), plain(UnitLevel("pet"))
    if c.name and name then parts[#parts + 1] = c.level and level and ("%s %d"):format(name, level) or name
    elseif c.level and level then parts[#parts + 1] = "Lv " .. level end
    return table.concat(parts, F.SEP) -- health is drawn after it, by showHealth
  end,

  OnRefresh = function(w, enabled)
    if not w.icon then return end
    local on = enabled and hasDemon()
    if on then SetPortraitTexture(w.icon, "pet") end
    w.icon:SetShown(on and true or false)
    showHealth(w, on)
  end,

  Tooltip = function(_, tip)
    if not hasDemon() then return end
    local c = cfg()
    local function line(l, r) tip:AddDoubleLine(l, r, 0.75, 0.75, 0.75, 1, 1, 1) end
    tip:AddDoubleLine(plain(UnitName("pet")) or "Demon", plain(UnitCreatureFamily("pet")) or "", 1, 1, 1, 0.6, 0.6, 0.6)
    local hp, max = plain(UnitHealth("pet")), plain(UnitHealthMax("pet"))
    if hp and max then line("Health", pair(hp, max)) elseif max then line("Max health", F.Thousands(max)) end
    local mana = pair(plain(UnitPower("pet")), plain(UnitPowerMax("pet")))
    if mana then line("Mana", mana) end
    tip:AddLine(" ")
    tip:AddDoubleLine("Left-click", ACTIONS[c.left], 0.3, 0.9, 0.3, 1, 1, 1)
    tip:AddDoubleLine("Right-click", ACTIONS[c.right], 0.3, 0.9, 0.3, 1, 1, 1)
    tip:AddDoubleLine("Shift+right-click", "Options", 0.3, 0.9, 0.3, 1, 1, 1)
  end,

  Menu = function(_, root)
    local c = cfg()
    root:CreateTitle("Warlock demon")
    local bar = root:CreateButton("Bar shows")
    local function isShow(k) return c.show[k] end
    local function toggleShow(k) c.show[k] = not c.show[k] S:Refresh(ID) end
    local labels = { name = "Name", level = "Level", health = "Health" }
    for _, k in ipairs({ "name", "level", "health" }) do bar:CreateCheckbox(labels[k], isShow, toggleShow, k) end
    for _, side in ipairs({ { "left", "Left-click" }, { "right", "Right-click" } }) do
      local sub = root:CreateButton(side[2])
      local function isAction(a) return c[side[1]] == a end
      local function setAction(a) c[side[1]] = a S:Setup(ID) end
      for _, a in ipairs({ "funnel", "none" }) do sub:CreateRadio(ACTIONS[a], isAction, setAction, a) end
    end
    root:CreateTitle("Warnings: Superb menu, Notifications")
  end,
}

-- Warlocks only. Registered at login, when the class is known; Superb creates the secure button out of combat.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  local _, class = UnitClass("player")
  if class == "WARLOCK" then S:RegisterModule(def) end
end)
