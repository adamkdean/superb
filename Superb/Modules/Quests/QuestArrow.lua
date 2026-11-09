-- Superb module: a big yellow arrow over each unit your active quests need, enemies and friendly NPCs alike.
-- It sits on the unit's nameplate, so it shows only where the game shows nameplates. The art, size and bounce
-- come from Blizzard's own tutorial pointer (Blizzard_TutorialTemplates.xml, Tutorial_PointerDown).
-- C_QuestLog.UnitIsRelatedToActiveQuest decides; its answer is never secret (QuestLogDocumentation.lua).
-- Uncertain until seen in game: whether it lets go of a unit once its objective is complete. To check, finish
-- a kill objective and watch the other mobs of that kind lose their arrows.
local S = Superb

local ID = "questarrow"
local SIZE = 64               -- Tutorial_PointerDown
local BOB, BOB_TIME = 6, 0.6  -- pixels down, and seconds each way

local def
local plateOf = {}  -- nameplate unit token -> its nameplate frame, while the game shows it
local arrows = {}   -- nameplate frame -> its arrow; the game reuses nameplate frames, so each gets one arrow

local function arrowFor(plate)
  local a = arrows[plate]
  if a then return a end
  a = CreateFrame("Frame", nil, plate)
  a:SetSize(SIZE, SIZE)
  a:SetPoint("BOTTOM", plate, "TOP", 0, 0)
  local art = a:CreateTexture(nil, "ARTWORK")
  art:SetAllPoints()
  art:SetAtlas("NPE_ArrowDown")
  local glow = a:CreateTexture(nil, "OVERLAY")
  glow:SetAllPoints()
  glow:SetAtlas("NPE_ArrowDownGlow")
  glow:SetAlpha(0.75)
  glow:SetBlendMode("ADD")
  a.bob = a:CreateAnimationGroup()
  local move = a.bob:CreateAnimation("Translation")
  move:SetOffset(0, -BOB)
  move:SetDuration(BOB_TIME)
  move:SetSmoothing("IN_OUT")
  a.bob:SetLooping("BOUNCE")
  arrows[plate] = a
  return a
end

local function setArrow(plate, on)
  if on then
    local a = arrowFor(plate)
    a:Show()
    a.bob:Play()
  elseif arrows[plate] then
    arrows[plate].bob:Stop()
    arrows[plate]:Hide()
  end
end

local function update(unit)
  local plate = plateOf[unit]
  if plate then setArrow(plate, S:IsEnabled(def) and C_QuestLog.UnitIsRelatedToActiveQuest(unit)) end
end

local function updateAll()
  for unit in pairs(plateOf) do update(unit) end
end

def = {
  id = ID, name = "Quest arrows", side = "right", order = 2000,
  events = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE" },

  Text = function() return nil end,  -- draws on nameplates, not on the bar

  OnEvent = function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
      plateOf[unit] = C_NamePlate.GetNamePlateForUnit(unit)  -- none for a forbidden nameplate
      update(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      local plate = plateOf[unit]
      plateOf[unit] = nil
      if plate then setArrow(plate, false) end
    else
      updateAll()
    end
    return false
  end,

  -- After each refresh, and when the module is turned on or off under Modules.
  OnRefresh = function(_, enabled)
    updateAll()
    local c = S:ModuleDB(ID)
    if enabled and not c.hinted and C_CVar.GetCVarBool("nameplateShowEnemies") == false then
      c.hinted = true
      print("Superb: quest arrows show on nameplates. Turn on enemy nameplates, and friendly NPC nameplates for"
        .. " quest NPCs, in the game options.")
    end
  end,
}

S:RegisterModule(def)
