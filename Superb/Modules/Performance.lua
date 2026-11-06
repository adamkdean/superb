-- Superb module: frame rate and latency, with addon memory in the tooltip.
local S, F = Superb, Superb.Format

local MEMORY_EVERY = 10   -- UpdateAddOnMemoryUsage is slow, so at most once in this many seconds
local memory, memoryAt = nil, -math.huge

local function latency()
  local _, _, home, world = GetNetStats()
  return home or 0, world or 0
end

local function readMemory()
  if GetTime() - memoryAt < MEMORY_EVERY and memory then return memory end
  UpdateAddOnMemoryUsage()
  local list, total = {}, 0
  for i = 1, C_AddOns.GetNumAddOns() do
    local kb = GetAddOnMemoryUsage(i) or 0
    if kb > 0 then
      local name, title = C_AddOns.GetAddOnInfo(i)
      list[#list + 1] = { name = title or name, kb = kb }
      total = total + kb
    end
  end
  table.sort(list, function(a, b) return a.kb > b.kb end)
  memory, memoryAt = { list = list, total = total }, GetTime()
  return memory
end

local function mb(kb) return ("%.1f MB"):format(kb / 1024) end

S:RegisterModule({
  id = "performance", name = "Performance", side = "right", order = 50, tick = true,

  Text = function()
    local home, world = latency()
    return ("%d fps · %d ms"):format(math.floor(GetFramerate() + 0.5), math.max(home, world))
  end,

  Tooltip = function(_, tip)
    local bwIn, bwOut = GetNetStats()
    local home, world = latency()
    tip:AddLine("Performance", 1, 1, 1)
    tip:AddDoubleLine("Frame rate", ("%.0f fps"):format(GetFramerate()), nil, nil, nil, 1, 1, 1)
    tip:AddDoubleLine("Latency, home", home .. " ms", nil, nil, nil, 1, 1, 1)
    tip:AddDoubleLine("Latency, world", world .. " ms", nil, nil, nil, 1, 1, 1)
    tip:AddDoubleLine("Network in / out", ("%.1f / %.1f KB/s"):format(bwIn or 0, bwOut or 0), nil, nil, nil, 1, 1, 1)
    local m = readMemory()
    tip:AddLine(" ")
    tip:AddDoubleLine("Addon memory", mb(m.total), 1, 1, 1, 1, 1, 1)
    for i = 1, math.min(5, #m.list) do
      tip:AddDoubleLine(m.list[i].name, mb(m.list[i].kb), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    tip:AddLine(" ")
    tip:AddLine(("Memory updates every %d seconds."):format(MEMORY_EVERY), 0.6, 0.6, 0.6)
  end,
})
