-- Superb: where a dragged item lands. Pure Lua, tested in tests/Superb/format_test.lua.
-- The bar has three sticky zones: the left, centre and right thirds.
Superb = Superb or {}
local A = {}
Superb.Arrange = A

function A.Zone(x, width)
  if x < width / 3 then return "left" end
  if x > width * 2 / 3 then return "right" end
  return "centre"
end

-- items: the other items in the zone, as { id, x } (x = centre). Returns the ids in the zone's order with dragId
-- placed at x, and the id it lands before (nil at the end). Left and centre run left to right; the right zone
-- runs from the right edge inwards, as Superb lays it out.
function A.Insert(items, side, dragId, x)
  local list = {}
  for _, it in ipairs(items) do list[#list + 1] = it end
  local fromRight = side == "right"
  table.sort(list, function(a, b) if fromRight then return a.x > b.x end return a.x < b.x end)
  local ids, before = {}, nil
  for _, it in ipairs(list) do
    if not before and ((fromRight and x > it.x) or (not fromRight and x < it.x)) then
      ids[#ids + 1] = dragId
      before = it.id
    end
    ids[#ids + 1] = it.id
  end
  if not before then ids[#ids + 1] = dragId end
  return ids, before
end
