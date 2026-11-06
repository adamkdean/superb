-- Superb module: the character's gold, with the session change and the gold of every character on the realm.
local S, F = Superb, Superb.Format

local sessionStart

local function realmChars()
  local chars = S:DB().chars
  local realm = GetRealmName()
  chars[realm] = chars[realm] or {}
  return chars[realm]
end

local function save()
  local _, class = UnitClass("player")
  realmChars()[UnitName("player")] = { money = GetMoney(), class = class }
end

local function coins(copper) return F.Money(copper, S:Theme().size) end

S:RegisterModule({
  id = "gold", name = "Gold", side = "right", order = 20, events = { "PLAYER_MONEY" },

  OnLoad = function()
    sessionStart = GetMoney()
    save()
  end,

  OnEvent = save,

  Text = function() return coins(GetMoney()) end,

  Tooltip = function(_, tip)
    tip:AddLine("Gold", 1, 1, 1)
    local change = GetMoney() - (sessionStart or GetMoney())
    if change >= 0 then
      tip:AddDoubleLine("This session", "+" .. F.Money(change, 12), nil, nil, nil, 0.3, 1, 0.3)
    else
      tip:AddDoubleLine("This session", "-" .. F.Money(-change, 12), nil, nil, nil, 1, 0.3, 0.3)
    end
    tip:AddLine(" ")
    local list, total = {}, 0
    for name, c in pairs(realmChars()) do
      list[#list + 1] = { name = name, money = c.money or 0, class = c.class }
      total = total + (c.money or 0)
    end
    table.sort(list, function(a, b) return a.money > b.money end)
    tip:AddLine(GetRealmName(), 1, 1, 1)
    for _, c in ipairs(list) do
      local colour = c.class and C_ClassColor.GetClassColor(c.class)
      local name = colour and colour:WrapTextInColorCode(c.name) or c.name
      tip:AddDoubleLine(name, F.Money(c.money, 12), nil, nil, nil, 1, 1, 1)
    end
    if #list > 1 then tip:AddDoubleLine("Total", F.Money(total, 12), 1, 1, 1, 1, 1, 1) end
  end,
})
