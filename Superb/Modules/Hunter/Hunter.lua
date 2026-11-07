-- Superb, hunter module: a pet item for the Superb bar. Shows the pet's name, level, mood, health and food; feeds it or
-- casts Mend Pet on a click; warns when it is unhappy, low on food, gains loyalty or dies. Everything is set in
-- its menu (Shift+right-click on the item).
local _, ns = ...
local S, F, Pet = Superb, Superb.Format, ns.Pet

local ID = "hunter.pet"
local FEED_PET_SPELL_ID = 6991    -- Blizzard_FrameXMLUtil/ItemUtil.lua
local MEND_PET = "Mend Pet"       -- by name: its spell ID on Forever is not in the UI source (check in game)
local ICON = 16

local DEFAULTS = {
  show = { name = true, level = true, mood = true, health = true, food = true },
  tip = { xp = true, loyalty = true, foods = true },
  left = "feed", right = "mend", foodMode = "lowest", lowFood = 5,
}

local def
local last = {}   -- last seen mood, loyalty, food count and death, for the warnings

S:RegisterNotification("pet.unhappy", "Pet unhappy", "warning")
S:RegisterNotification("pet.lowfood", "Pet food low", "warning")
S:RegisterNotification("pet.loyalty", "Pet loyalty up", "good")
S:RegisterNotification("pet.died", "Pet died", "bad")

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

local function hasPet()
  local _, isHunterPet = HasPetUI()
  return plain(isHunterPet) and UnitExists("pet")
end

local function feedName() return C_Spell.GetSpellName(FEED_PET_SPELL_ID) or "Feed Pet" end

-- Every stack in the bags that the pet eats. Cached until the bags or the pet change.
local foodCache
local function foodInBags()
  if foodCache then return foodCache end
  local list = {}
  if not hasPet() then return list end
  for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID and C_PetInfo.CanPetEatItem(info.itemID) then
        local _, _, _, itemLevel = C_Item.GetItemInfo(info.itemID)
        list[#list + 1] = { bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1,
                            level = itemLevel or 0, link = info.hyperlink, icon = info.iconFileID }
      end
    end
  end
  foodCache = list
  return list
end

local function chosenFood(foods)
  return Pet.ChooseFood(foods or foodInBags(), plain(UnitLevel("pet")) or 1, cfg().foodMode)
end

local ACTIONS = { feed = "Feed Pet", mend = "Mend Pet", none = "Nothing" }

local function setAction(w, n, action)
  if action == "feed" then
    w:SetAttribute("type" .. n, "macro")
    w:SetAttribute("macrotext" .. n, Pet.FeedMacro(feedName(), chosenFood()))
  elseif action == "mend" then
    w:SetAttribute("type" .. n, "spell")
    w:SetAttribute("spell" .. n, MEND_PET)
  else
    w:SetAttribute("type" .. n, ATTRIBUTE_NOOP)
  end
end

local function mood()
  local happiness, damage, rate = C_PetInfo.GetPetHappiness()
  return plain(happiness), plain(damage), plain(rate)
end

local function warn(foodTotal)
  local name = plain(UnitName("pet")) or "Your pet"
  local happiness = mood()
  if happiness and last.mood and happiness < last.mood and happiness <= 2 then
    S:Notify("pet.unhappy", ("%s is %s"):format(name, Pet.MOODS[happiness].name:lower()), "Feed it to keep its damage up.")
  end
  last.mood = happiness or last.mood
  local loyalty = plain(C_PetInfo.GetPetLoyalty())
  if loyalty and last.loyalty and loyalty ~= last.loyalty then
    S:Notify("pet.loyalty", "Loyalty up", ("%s: %s"):format(name, loyalty))
  end
  last.loyalty = loyalty or last.loyalty
  local threshold = cfg().lowFood
  if foodTotal and last.food and foodTotal < threshold and last.food >= threshold then
    S:Notify("pet.lowfood", "Pet food low", ("%d left that %s eats."):format(foodTotal, name))
  end
  last.food = foodTotal
end

local function onPetChanged()
  last = {}
  foodCache = nil
  last.food = Pet.CountFood(foodInBags()) -- the baseline for the low food warning
  S:Setup(ID)
end

-- Bar item ----------------------------------------------------------------------------------------------------

def = {
  id = ID, name = "Hunter pet", side = "centre", order = 5, secure = true,  -- the centre is for class items
  events = { "UNIT_PET", "UNIT_HAPPINESS", "PET_UI_UPDATE", "UNIT_PET_EXPERIENCE", "BAG_UPDATE_DELAYED" },

  OnLoad = function(w)
    w.leftInset = ICON + 4
    w.label:ClearAllPoints()
    w.label:SetPoint("LEFT", S:Theme().pad + ICON + 4, 0)
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(ICON, ICON)
    w.icon:SetPoint("LEFT", S:Theme().pad, 0)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_LEVEL" }) do pcall(w.RegisterUnitEvent, w, e, "pet") end
    last.food = Pet.CountFood(foodInBags())
  end,

  OnEvent = function(_, event, unit)
    if event == "UNIT_PET" then
      if unit == "player" then onPetChanged() end
    elseif event == "BAG_UPDATE_DELAYED" then
      foodCache = nil
      S:Setup(ID)
      warn((Pet.CountFood(foodInBags())))
      return
    elseif event == "UNIT_HEALTH" then
      local dead = plain(UnitIsDead("pet"))
      if dead and not last.dead then
        S:Notify("pet.died", "Pet died", ("%s died. Revive it before the next pull."):format(plain(UnitName("pet")) or "Your pet"))
      end
      last.dead = dead
    else
      warn(last.food)
    end
  end,

  Setup = function(w)
    setAction(w, 1, cfg().left)
    setAction(w, 2, cfg().right)
  end,

  Text = function(w)
    if not hasPet() then return nil end
    local c = cfg().show
    local happiness = mood()
    local parts = {}
    local name, level = plain(UnitName("pet")), plain(UnitLevel("pet"))
    if c.name and name then parts[#parts + 1] = c.level and level and ("%s %d"):format(name, level) or name
    elseif c.level and level then parts[#parts + 1] = "Lv " .. level end
    if c.mood and happiness and Pet.MOODS[happiness] then
      local m = Pet.MOODS[happiness]
      parts[#parts + 1] = F.Colour(m.name, m.r, m.g, m.b)
    end
    if c.health then
      local hp, hpMax = plain(UnitHealth("pet")), plain(UnitHealthMax("pet"))
      if hp and hpMax then parts[#parts + 1] = ("%d/%d"):format(hp, hpMax) end
    end
    if c.food then
      local foods = foodInBags()
      local total = Pet.CountFood(foods)
      local food = chosenFood(foods)
      parts[#parts + 1] = food and food.icon and ("|T%d:0|t%d"):format(food.icon, total) or ("food %d"):format(total)
    end
    return table.concat(parts, F.SEP)
  end,

  OnRefresh = function(w, enabled)
    if not w.icon then return end
    local on = enabled and hasPet()
    if on then SetPortraitTexture(w.icon, "pet") end
    w.icon:SetShown(on and true or false)
  end,

  Tooltip = function(_, tip)
    if not hasPet() then return end
    local c = cfg()
    local function line(l, r, rr, rg, rb) tip:AddDoubleLine(l, r, 0.75, 0.75, 0.75, rr or 1, rg or 1, rb or 1) end
    tip:AddDoubleLine(plain(UnitName("pet")) or "Pet", plain(UnitCreatureFamily("pet")) or "", 1, 1, 1, 0.6, 0.6, 0.6)
    local happiness, damage, rate = mood()
    if happiness and Pet.MOODS[happiness] then
      local m = Pet.MOODS[happiness]
      line("Mood", damage and ("%s (%d%% damage)"):format(m.name, damage) or m.name, m.r, m.g, m.b)
    end
    line("Loyalty", plain(C_PetInfo.GetPetLoyalty()) or "?")
    if c.tip.loyalty then line("Loyalty is", Pet.LoyaltyTrend(rate)) end
    local diet = C_PetInfo.GetPetFoodTypes() or {}
    line("Diet", #diet > 0 and table.concat(diet, ", ") or "none")
    local foods = foodInBags()
    local total, byItem = Pet.CountFood(foods)
    local food = chosenFood(foods)
    tip:AddLine(" ")
    line("Food", food and ("%s x%d"):format(food.link or "?", food.count) or "none in your bags", food and 1 or 1, food and 1 or 0.3, food and 1 or 0.3)
    if c.tip.foods and #byItem > 1 then
      for _, e in ipairs(byItem) do line("  in bags", ("%s x%d"):format(e.link or "?", e.count)) end
    end
    if c.tip.xp then
      local xp, need = GetPetExperience()
      if xp and need and need > 0 then line("Pet XP", ("%s / %s (%d%%)"):format(F.Thousands(xp), F.Thousands(need), F.Percent(xp, need))) end
      local totalPoints, used = C_PetInfo.GetPetTrainingPoints()
      if totalPoints then line("Training points", ("%d free of %d"):format(totalPoints - (used or 0), totalPoints)) end
    end
    tip:AddLine(" ")
    tip:AddDoubleLine("Left-click", ACTIONS[c.left], 0.3, 0.9, 0.3, 1, 1, 1)
    tip:AddDoubleLine("Right-click", ACTIONS[c.right], 0.3, 0.9, 0.3, 1, 1, 1)
    tip:AddDoubleLine("Shift+right-click", "Options", 0.3, 0.9, 0.3, 1, 1, 1)
    if total == 0 and (c.left == "feed" or c.right == "feed") then tip:AddLine("No food for this pet in your bags.", 1, 0.3, 0.3) end
  end,

  Menu = function(_, root)
    local c = cfg()
    root:CreateTitle("Hunter pet")
    local bar = root:CreateButton("Bar shows")
    local function isShow(k) return c.show[k] end
    local function toggleShow(k) c.show[k] = not c.show[k] S:Refresh(ID) end
    for _, k in ipairs({ "name", "level", "mood", "health", "food" }) do
      local labels = { name = "Name", level = "Level", mood = "Mood", health = "Health", food = "Food count" }
      bar:CreateCheckbox(labels[k], isShow, toggleShow, k)
    end
    local tipMenu = root:CreateButton("Tooltip shows")
    local function isTip(k) return c.tip[k] end
    local function toggleTip(k) c.tip[k] = not c.tip[k] end
    tipMenu:CreateCheckbox("Pet XP and training points", isTip, toggleTip, "xp")
    tipMenu:CreateCheckbox("Loyalty trend", isTip, toggleTip, "loyalty")
    tipMenu:CreateCheckbox("All food in bags", isTip, toggleTip, "foods")
    for _, side in ipairs({ { "left", "Left-click" }, { "right", "Right-click" } }) do
      local sub = root:CreateButton(side[2])
      local function isAction(a) return c[side[1]] == a end
      local function setAction(a) c[side[1]] = a S:Setup(ID) end
      for _, a in ipairs({ "feed", "mend", "none" }) do sub:CreateRadio(ACTIONS[a], isAction, setAction, a) end
    end
    local foodMenu = root:CreateButton("Food to use")
    local function isMode(m) return c.foodMode == m end
    local function setMode(m) c.foodMode = m S:Setup(ID) S:Refresh(ID) end
    foodMenu:CreateRadio("Lowest level that still works", isMode, setMode, "lowest")
    foodMenu:CreateRadio("Highest level", isMode, setMode, "highest")
    local low = root:CreateButton("Warn when food is under")
    local function isLow(n) return c.lowFood == n end
    local function setLow(n) c.lowFood = n end
    for _, n in ipairs({ 3, 5, 10, 20 }) do low:CreateRadio(tostring(n), isLow, setLow, n) end
    root:CreateTitle("Warnings: Superb menu, Notifications")
  end,
}

-- Hunters only. Registered at login, when the class is known; Superb creates the secure button out of combat.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  local _, class = UnitClass("player")
  if class == "HUNTER" then S:RegisterModule(def) end
end)
