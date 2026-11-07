-- Superb module: zone and coordinates in the middle of the bar, like a window title.
local S, F = Superb, Superb.Format

local function cfg() return S:ModuleDB("location") end

-- Player position on the current map as percentages, or nil (instances have no position).
local function coords()
  local mapID = C_Map.GetBestMapForUnit("player")
  local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return end
  local x, y = pos:GetXY()
  if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
  if not x or (x == 0 and y == 0) then return end
  return x * 100, y * 100
end

local function coordText(x, y)
  return (cfg().decimals and "%.1f, %.1f" or "%.0f, %.0f"):format(x, y)
end

S:RegisterModule({
  -- The leftmost item on the right; the centre is kept for class items such as the pet.
  id = "location", name = "Location", side = "right", order = 60, tick = true,
  events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },

  Text = function()
    local zone = GetMinimapZoneText()
    if not zone or zone == "" then zone = GetZoneText() end
    if cfg().coords ~= false then
      local x, y = coords()
      if x then return ("%s  %s"):format(zone, coordText(x, y)) end
    end
    return zone
  end,

  Tooltip = function(_, tip)
    tip:AddLine("Location", 1, 1, 1)
    tip:AddDoubleLine("Zone", GetRealZoneText() or "", nil, nil, nil, 1, 1, 1)
    local sub = GetSubZoneText()
    if sub and sub ~= "" then tip:AddDoubleLine("Area", sub, nil, nil, nil, 1, 1, 1) end
    local x, y = coords()
    tip:AddDoubleLine("Coordinates", x and coordText(x, y) or "none here", nil, nil, nil, 1, 1, 1)
    tip:AddLine(" ")
    tip:AddLine("Left-click: world map. Right-click: options.", 0.6, 0.6, 0.6)
  end,

  OnClick = function()
    if InCombatLockdown() then return end
    if ToggleWorldMap then ToggleWorldMap() end
  end,

  Menu = function(_, root)
    root:CreateTitle("Location")
    root:CreateCheckbox("Show coordinates", function() return cfg().coords ~= false end,
      function() cfg().coords = cfg().coords == false S:Refresh("location") end)
    root:CreateCheckbox("One decimal place", function() return cfg().decimals == true end,
      function() cfg().decimals = not cfg().decimals S:Refresh("location") end)
  end,
})
