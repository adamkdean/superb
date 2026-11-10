-- Superb, levelling module: an XP bonus item. The bar shows the total XP bonus and the time until the first
-- bonus ends; the tooltip lists each bonus, the campfire and the Camp Tent. A left click eats food from the bags
-- that gives the XP bonus.
--
-- An XP bonus is any buff whose tooltip says so, and XP food is any food whose tooltip says so. Seen in game
-- (2026-11-10): the food's Well Fed buff (1248421, one of several) reads "Experience gained from kills increased
-- by 5%."; the food reads "If you spend at least 10 sec eating ... experience gained from kills is increased by
-- 5%." The text match is English only.
-- Blizzard has not said if the bonuses add or multiply. They are added here.
local S, F = Superb, Superb.Format

local ID = "levelling.bonus"
local XP_TEXT = "experience[^%.]-(%d+)%%"  -- in lower case, within one sentence
local RESTED_PERCENT = 100         -- rested doubles XP from kills
local CAMP = 1229741               -- Camp Benefits (seen in game, 2026-11-10)
-- UNCERTAIN, not seen in game or in the Blizzard UI source. The campfire IDs are the ones the CozyFire addon
-- reads (Marking.lua); Boosted Rest is from a player guide. To check: hover the item near a campfire, while
-- sitting by it, and after using a Camp Tent.
local FIRE_NEAR = 1283391          -- Campfire Nearby
local FIRE_SIT = { 1289723, 1229739 }  -- Welcoming Campfire: sitting by the fire, a minute to Camp Benefits
local TENT_LOCK = 1229451          -- Boosted Rest: a Camp Tent was used, no other for an hour

S:RegisterNotification("xpbonus.ended", "XP bonus ended", "warning")

local auras = {}      -- the player's auras as last read, by spell ID: { name, expires (GetTime() base), percent }
local percentOf = {}  -- by spell ID and stack count: the XP percent in that buff's tooltip, or false
local foodOf = {}     -- by item ID: the XP percent in that food's tooltip, or false
local food            -- the XP food to eat: { bag, slot, link }, false for none, nil when the bags changed
local had = {}        -- by buff name: an XP bonus at the last refresh
local scannedAt

-- A value, or nil when the game made it secret.
local function plain(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- The XP percent in tooltip lines, or false. `word`, when given, must be in the same line.
local function xpPercent(lines, word)
  for _, line in ipairs(lines) do
    local text = plain(line.leftText)
    text = type(text) == "string" and text:lower() or ""
    local n = text:match(XP_TEXT)
    if n and (not word or text:find(word, 1, true)) then return tonumber(n) end
  end
  return false
end

-- Reads the player's auras, once for each refresh. Aura data is restricted in combat (SecretWhenUnitAuraRestricted),
-- so the last reading stands until combat ends; each aura still drops at its own end time.
local function scan()
  if InCombatLockdown() or scannedAt == GetTime() then return end
  local list = {}
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)  -- uncertain: it may throw while restricted
      if not ok or (a ~= nil and not plain(a)) then return end
      if not a then break end
      local id, stacks, expires = plain(a.spellId), plain(a.applications) or 0, plain(a.expirationTime)
      if id then
        local key = id .. ":" .. stacks
        if percentOf[key] == nil and filter == "HELPFUL" then
          local got, data = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", a.auraInstanceID, filter)
          -- A tooltip with no lines is not loaded yet: ask again at the next reading.
          if got and data and data.lines and #data.lines > 0 then percentOf[key] = xpPercent(data.lines) end
        end
        list[id] = { name = plain(a.name) or "Buff", expires = expires and expires > 0 and expires or nil,
                     percent = percentOf[key] or nil }
      end
    end
  end
  auras, scannedAt = list, GetTime()
end

local function aura(id)
  scan()
  local a = auras[id]
  if a and a.expires and a.expires <= GetTime() then auras[id] = nil return nil end
  return a
end

local function levelling() return UnitLevel("player") < GetMaxPlayerLevel() and not IsXPUserDisabled() end

-- Each bonus that is on: { name, percent, expires }, rested first, then buffs by name.
local function bonuses()
  scan()
  local list = {}
  for id in pairs(auras) do
    local a = aura(id)
    if a and a.percent then list[#list + 1] = a end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  if (GetXPExhaustion() or 0) > 0 then table.insert(list, 1, { name = "Rested", percent = RESTED_PERCENT, rested = true }) end
  return list
end

-- The total percent, and the end time of the first bonus to end (nil when none counts down).
local function total(list)
  local sum, first = 0
  for _, b in ipairs(list) do
    sum = sum + b.percent
    if b.expires and (not first or b.expires < first) then first = b.expires end
  end
  return sum, first
end

local function left(expires) return F.Duration(expires - GetTime()) end

-- The first food in the bags whose tooltip gives the XP bonus. Cached until the bags change.
local function xpFood()
  if food ~= nil then return food end
  food = false
  for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local id = info and info.itemID
      if id and foodOf[id] == nil then
        local data = C_TooltipInfo.GetBagItem(bag, slot)
        if data and data.lines and #data.lines > 0 then foodOf[id] = xpPercent(data.lines, "eating") end
      end
      if id and foodOf[id] then
        food = { bag = bag, slot = slot, link = info.hyperlink or "food" }
        return food
      end
    end
  end
  return food
end

S:RegisterModule({
  id = ID, name = "XP bonus", side = "left", order = 900, tick = true, secure = true,  -- last on the left, also after items the player moved
  events = { "BAG_UPDATE_DELAYED" },

  OnEvent = function()
    food = nil
    S:Setup(ID)
  end,

  -- Left click: eat the XP food, by its bag and slot, as the hunter item feeds the pet.
  Setup = function(w)
    local f = xpFood()
    if f then
      w:SetAttribute("type1", "macro")
      w:SetAttribute("macrotext1", ("/use %d %d"):format(f.bag, f.slot))
    else
      w:SetAttribute("type1", ATTRIBUTE_NOOP)
    end
  end,

  Text = function()
    if not levelling() then return nil end
    local sum, first = total(bonuses())
    local text = ("+%d%% XP"):format(sum)
    if first then text = text .. F.SEP .. left(first) end
    return text
  end,

  -- Warns when a buff's XP bonus ends.
  OnRefresh = function(_, enabled)
    local now = {}
    for _, b in ipairs(bonuses()) do if not b.rested then now[b.name] = true end end
    for name in pairs(had) do
      if enabled and not now[name] then
        S:Notify("xpbonus.ended", "XP bonus ended", ("Your %s XP bonus ended."):format(name))
      end
    end
    had = now
  end,

  Tooltip = function(_, tip)
    local list = bonuses()
    local function line(l, r) tip:AddDoubleLine(l, r, 0.75, 0.75, 0.75, 1, 1, 1) end
    tip:AddDoubleLine("XP bonus", ("+%d%%"):format((total(list))), 1, 1, 1, 1, 1, 1)
    local rested, buffs = "None", 0
    for _, b in ipairs(list) do
      if b.rested then
        rested = ("+%d%% (%d%% of a level left)"):format(b.percent, F.Percent(GetXPExhaustion(), UnitXPMax("player")))
      end
    end
    line("Rested", rested)
    for _, b in ipairs(list) do
      if not b.rested then
        buffs = buffs + 1
        line(b.name, b.expires and ("+%d%% (%s)"):format(b.percent, left(b.expires)) or ("+%d%%"):format(b.percent))
      end
    end
    if buffs == 0 then line("Food and buffs", "None") end
    tip:AddLine(" ")
    local sit = aura(FIRE_SIT[1]) or aura(FIRE_SIT[2])
    if aura(CAMP) then line("Campfire", "Camp benefits active")
    elseif sit then line("Campfire", sit.expires and "Camp benefits in " .. left(sit.expires) or "Sitting")
    elseif aura(FIRE_NEAR) then line("Campfire", "Nearby. Sit by it for a minute")
    else line("Campfire", "None nearby") end
    local lock = aura(TENT_LOCK)
    if lock then line("Camp Tent", lock.expires and "Ready in " .. left(lock.expires) or "Used") end
    tip:AddLine(" ")
    local f = xpFood()
    tip:AddDoubleLine("Left-click", f and "Eat " .. f.link or "No XP food in your bags", 0.3, 0.9, 0.3, 1, 1, 1)
    tip:AddDoubleLine("Shift+right-click", "Options", 0.3, 0.9, 0.3, 1, 1, 1)
  end,
})
