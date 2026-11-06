-- Superb module: the clock at the right end of the bar. Local or realm time; the tooltip shows both.
local S, F = Superb, Superb.Format

local function cfg() return S:ModuleDB("clock") end

local function localNow()
  local t = date("*t")
  return t.hour, t.min, F.Day(t.wday, t.day, t.month)
end

local function realmNow()
  local h, m = GetGameTime()
  local c = C_DateAndTime.GetCurrentCalendarTime()
  return h, m, F.Day(c.weekday, c.monthDay, c.month)
end

local function line(h, m, day)
  local s = F.Clock(h, m, not cfg().use12)
  if cfg().showDate ~= false then s = day .. "  " .. s end
  return s
end

S:RegisterModule({
  id = "clock", name = "Clock", side = "right", order = 10, tick = true,

  Text = function()
    if cfg().source == "realm" then return line(realmNow()) end
    return line(localNow())
  end,

  Tooltip = function(_, tip)
    local realm = cfg().source == "realm"
    local lh, lm, lday = localNow()
    local rh, rm, rday = realmNow()
    local use24 = not cfg().use12
    tip:AddLine(realm and "Realm time" or "Local time", 1, 1, 1)
    tip:AddDoubleLine("Local time", lday .. "  " .. F.Clock(lh, lm, use24), nil, nil, nil, 1, 1, 1)
    tip:AddDoubleLine("Realm time", rday .. "  " .. F.Clock(rh, rm, use24), nil, nil, nil, 1, 1, 1)
    tip:AddDoubleLine("This session", F.Duration(GetSessionTime()), nil, nil, nil, 1, 1, 1)
    tip:AddLine(" ")
    tip:AddLine("Left-click: calendar. Right-click: options.", 0.6, 0.6, 0.6)
  end,

  OnClick = function()
    if ToggleCalendar then ToggleCalendar() end
  end,

  Menu = function(_, root)
    root:CreateTitle("Clock")
    local function isSource(v) return (cfg().source or "local") == v end
    local function setSource(v) cfg().source = v S:Refresh("clock") end
    root:CreateRadio("Local time", isSource, setSource, "local")
    root:CreateRadio("Realm time", isSource, setSource, "realm")
    root:CreateCheckbox("24-hour clock", function() return not cfg().use12 end,
      function() cfg().use12 = not cfg().use12 S:Refresh("clock") end)
    root:CreateCheckbox("Show date", function() return cfg().showDate ~= false end,
      function() cfg().showDate = cfg().showDate == false S:Refresh("clock") end)
  end,
})
