-- Superb module: professions. The bar shows each profession's icon and skill rank; the tooltip adds the cap.
-- GetProfessions and GetProfessionInfo are what Forever's own professions frame calls
-- (Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua); SKILL_LINES_CHANGED is what its skills frame
-- listens to (Blizzard_UIPanels_Game/Camelot/SkillsFrame.lua).
local S = Superb

local ID = "professions"
local SLOTS = 7  -- GetProfessions: two primary, then five secondary, nil where none is learnt
local ICON = "|T%s:%d:%d:0:0:64:64:5:59:5:59|t %d"  -- the icon cropped to drop its border, then the rank

-- Professions the player unticked in the item's menu, by skill line.
local function hidden()
  local c = S:ModuleDB(ID)
  c.hidden = c.hidden or {}
  return c.hidden
end

local function professions()
  local list, slots = {}, { GetProfessions() }
  for i = 1, SLOTS do
    if slots[i] then
      local name, icon, rank, max, _, _, skillLine = GetProfessionInfo(slots[i])
      if name then list[#list + 1] = { name = name, icon = icon, rank = rank or 0, max = max or 0, key = skillLine or name } end
    end
  end
  return list
end

S:RegisterModule({
  id = ID, name = "Professions", side = "left", order = 50,
  events = { "SKILL_LINES_CHANGED" },

  Text = function()
    local list = professions()
    if #list == 0 then return nil end
    local size, off, parts = S:Theme().size + 2, hidden(), {}
    for _, p in ipairs(list) do
      if not off[p.key] then parts[#parts + 1] = ICON:format(p.icon, size, size, p.rank) end
    end
    -- With every profession unticked, the name keeps the item on the bar, so its menu can bring them back.
    if #parts == 0 then return "Professions" end
    return table.concat(parts, "  ")
  end,

  Tooltip = function(_, tip)
    tip:AddLine("Professions", 1, 1, 1)
    for _, p in ipairs(professions()) do
      tip:AddDoubleLine(p.name, ("%d / %d"):format(p.rank, p.max), nil, nil, nil, 1, 1, 1)
    end
  end,

  Menu = function(_, root)
    root:CreateTitle("Professions")
    local off = hidden()
    local function isShown(key) return not off[key] end
    local function toggle(key) off[key] = not off[key] or nil S:Refresh(ID) end
    for _, p in ipairs(professions()) do root:CreateCheckbox(p.name, isShown, toggle, p.key) end
  end,
})
