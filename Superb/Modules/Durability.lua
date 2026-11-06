-- Superb module: armour durability. The bar shows the most worn item, in orange under 50% and red under 25%.
-- Sends a notification when an item drops under 25% and when one breaks.
local S, F = Superb, Superb.Format

local WARN, LOW = 50, 25
local lastLowest

S:RegisterNotification("durability", "Repair needed")

local function scan()
  local items, cur, max, lowest, lowestItem = {}, 0, 0, nil, nil
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    local c, m = GetInventoryItemDurability(slot)
    if c and m and m > 0 then
      local pct = 100 * c / m
      cur, max = cur + c, max + m
      local item = { slot = slot, pct = pct, link = GetInventoryItemLink("player", slot) or ("Slot " .. slot) }
      if c < m then items[#items + 1] = item end
      if not lowest or pct < lowest then lowest, lowestItem = pct, item end
    end
  end
  table.sort(items, function(a, b) return a.pct < b.pct end)
  return lowest, lowestItem, max > 0 and 100 * cur / max or nil, items
end

local function coloured(pct)
  local s = ("%d%%"):format(math.floor(pct))
  if pct < LOW then return F.Colour(s, 1, 0.25, 0.25) end
  if pct < WARN then return F.Colour(s, 1, 0.6, 0.1) end
  return s
end

S:RegisterModule({
  id = "durability", name = "Durability", side = "right", order = 45,
  events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },

  OnEvent = function()
    local lowest, item = scan()
    if lowest and lastLowest then
      if lowest <= 0 and lastLowest > 0 then
        S:Notify("durability", "Item broken", item.link .. " is broken. Repair it to use it again.")
      elseif lowest < LOW and lastLowest >= LOW then
        S:Notify("durability", "Repair soon", ("%s is at %d%%."):format(item.link, math.floor(lowest)))
      end
    end
    lastLowest = lowest
  end,

  OnLoad = function() lastLowest = scan() end,

  Text = function()
    local lowest = scan()
    if not lowest then return nil end
    return "Armour " .. coloured(lowest)
  end,

  Tooltip = function(_, tip)
    local _, _, overall, items = scan()
    tip:AddLine("Durability", 1, 1, 1)
    if overall then tip:AddDoubleLine("All armour", coloured(overall), nil, nil, nil, 1, 1, 1) end
    if #items == 0 then
      tip:AddLine("Nothing is damaged.", 0.6, 0.6, 0.6)
    else
      for _, item in ipairs(items) do tip:AddDoubleLine(item.link, coloured(item.pct), nil, nil, nil, 1, 1, 1) end
    end
  end,
})
