-- Superb, hunter module: pet moods, food choice and the feed macro. Pure Lua: no game API, so
-- tests/pet_test.lua runs it outside the game.
local _, ns = ...
local Pet = {}
ns.Pet = Pet

-- C_PetInfo.GetPetHappiness() gives 1, 2 or 3 (Blizzard_FrameXML/PetHappiness.lua uses the same scale).
Pet.MOODS = {
  [1] = { name = "Unhappy", r = 1, g = 0.25, b = 0.25 },
  [2] = { name = "Content", r = 1, g = 0.82, b = 0 },
  [3] = { name = "Happy", r = 0.3, g = 0.9, b = 0.3 },
}

-- Food more than this many levels below the pet is treated as weak. An assumption from Classic; check in game.
Pet.FULL_EFFECT_GAP = 10

-- foods: list of { bag, slot, itemID, count, level }. Returns the stack to feed, or nil.
-- "lowest": the lowest level food still within FULL_EFFECT_GAP of the pet, else the highest level food.
-- "highest": the highest level food.
function Pet.ChooseFood(foods, petLevel, mode)
  local best
  if mode ~= "highest" then
    for _, f in ipairs(foods) do
      if f.level >= petLevel - Pet.FULL_EFFECT_GAP and (not best or f.level < best.level) then best = f end
    end
    if best then return best end
  end
  for _, f in ipairs(foods) do
    if not best or f.level > best.level then best = f end
  end
  return best
end

-- Total items, and one entry per item ID with its count, sorted by name order of the list given.
function Pet.CountFood(foods)
  local total, byItem, list = 0, {}, {}
  for _, f in ipairs(foods) do
    total = total + f.count
    local e = byItem[f.itemID]
    if not e then
      e = { itemID = f.itemID, link = f.link, count = 0, level = f.level }
      byItem[f.itemID] = e
      list[#list + 1] = e
    end
    e.count = e.count + f.count
  end
  table.sort(list, function(a, b) return a.level < b.level end)
  return total, list
end

-- The macro a Feed Pet click runs: cast Feed Pet, then use the chosen stack as its target.
function Pet.FeedMacro(spellName, food)
  if not food then return "/cast " .. spellName end
  return ("/cast %s\n/use %d %d"):format(spellName, food.bag, food.slot)
end

-- "rising", "falling" or "steady" from the loyalty rate.
function Pet.LoyaltyTrend(rate)
  if not rate or rate == 0 then return "steady" end
  return rate > 0 and "rising" or "falling"
end
