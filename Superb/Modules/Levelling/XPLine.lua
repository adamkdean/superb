-- Superb, levelling module: a thin XP line along the inner edge of the Superb bar, with rested XP shaded ahead of it.
-- Like the game's XP bar, the line is blue while rested and purple when not.
local S = Superb

local HEIGHT = 2
local XP_COLOUR = { 0.62, 0.36, 1.0, 1 }
local RESTED_XP_COLOUR = { 0.25, 0.55, 1.0, 1 }
local RESTED_COLOUR = { 0.25, 0.55, 1.0, 0.55 }
local track, rested, fill

local function place(tex, top, width)
  local edge = top and "BOTTOM" or "TOP"
  local bar = S:Bar()
  tex:ClearAllPoints()
  tex:SetPoint(edge .. "LEFT", bar, edge .. "LEFT", 0, 0)
  if width then tex:SetWidth(width) else tex:SetPoint(edge .. "RIGHT", bar, edge .. "RIGHT", 0, 0) end
  tex:SetHeight(HEIGHT)
end

S:RegisterModule({
  id = "levelling.xpline", name = "XP line", side = "left", order = 1000, tick = true,
  events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP" },

  Text = function() return nil end,

  OnLoad = function()
    local bar = S:Bar()
    track = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    rested = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    fill = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    rested:SetColorTexture(unpack(RESTED_COLOUR))
  end,

  OnRefresh = function(_, enabled)
    if not track then return end
    local mx = UnitXPMax("player") or 0
    local on = enabled and UnitLevel("player") < GetMaxPlayerLevel() and not IsXPUserDisabled() and mx > 0
    track:SetShown(on)
    if not on then
      rested:Hide()
      fill:Hide()
      return
    end
    local top = S:Position() ~= "bottom"
    local width = S:Bar():GetWidth()
    local xp, extra = UnitXP("player"), GetXPExhaustion() or 0
    fill:SetColorTexture(unpack(extra > 0 and RESTED_XP_COLOUR or XP_COLOUR))
    track:SetColorTexture(unpack(S:Theme().highlight))
    place(track, top)
    local xpWidth = width * math.min(1, xp / mx)
    local restedWidth = width * math.min(1, (xp + extra) / mx)
    fill:SetShown(xpWidth >= 1)
    rested:SetShown(restedWidth - xpWidth >= 1)
    if xpWidth >= 1 then place(fill, top, xpWidth) end
    if restedWidth - xpWidth >= 1 then place(rested, top, restedWidth) end
  end,
})
