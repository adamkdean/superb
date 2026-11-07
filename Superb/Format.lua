-- Superb: plain text formatting helpers, shared with module addons as Superb.Format.
-- Pure Lua: no game API, so tests/Superb/format_test.lua runs them outside the game.
Superb = Superb or {}
local F = {}
Superb.Format = F

local floor, format = math.floor, string.format

-- Seconds as "45s", "12m", "1h 05m" or "2d 3h". Nil, NaN or infinite gives "-".
function F.Duration(sec)
  if type(sec) ~= "number" or sec ~= sec or sec == math.huge or sec < 0 then return "-" end
  sec = floor(sec + 0.5)
  if sec < 60 then return sec .. "s" end
  local m = floor(sec / 60)
  if m < 60 then return m .. "m" end
  local h = floor(m / 60)
  m = m % 60
  if h < 24 then return format("%dh %02dm", h, m) end
  return format("%dd %dh", floor(h / 24), h % 24)
end

-- 999 -> "999", 1500 -> "1.5k", 12345 -> "12.3k", 123456 -> "123k", 2500000 -> "2.5m".
function F.Short(n)
  if type(n) ~= "number" then return "-" end
  local a = math.abs(n)
  local s
  if a >= 1e6 then s = format(a >= 1e8 and "%.0fm" or "%.1fm", n / 1e6)
  elseif a >= 1e3 then s = format(a >= 1e5 and "%.0fk" or "%.1fk", n / 1e3)
  else return tostring(floor(n + 0.5)) end
  return (s:gsub("%.0([km])$", "%1"))
end

-- 1234567 -> "1,234,567".
function F.Thousands(n)
  local s = tostring(floor((n or 0) + 0.5))
  local sign, digits = s:match("^(-?)(%d+)$")
  if not digits then return s end
  digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return sign .. digits
end

-- 14, 5 -> "14:05" (24-hour) or "2:05 PM" (12-hour).
function F.Clock(h, m, use24)
  if use24 then return format("%02d:%02d", h, m) end
  local suffix = h < 12 and "AM" or "PM"
  local h12 = h % 12
  if h12 == 0 then h12 = 12 end
  return format("%d:%02d %s", h12, m, suffix)
end

local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- weekday 1 = Sunday (as date("*t") and C_DateAndTime give it) -> "Thu 6 Nov".
function F.Day(weekday, monthDay, month)
  return format("%s %d %s", DAYS[weekday] or "?", monthDay, MONTHS[month] or "?")
end

-- Copper as plain text: 123456 -> "12g 34s 56c", 50 -> "50c", 0 -> "0c".
function F.Coins(copper)
  copper = floor(copper or 0)
  local sign = copper < 0 and "-" or ""
  copper = math.abs(copper)
  local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = F.Thousands(g) .. "g" end
  if s > 0 or (g > 0 and c > 0) then parts[#parts + 1] = s .. "s" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
  return sign .. table.concat(parts, " ")
end

-- Copper with the game's coin icons, or plain text outside the game.
function F.Money(copper, fontHeight)
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and copper >= 0 then
    return C_CurrencyInfo.GetCoinTextureString(floor(copper), fontHeight or 12)
  end
  return F.Coins(copper)
end

-- Whole percent, rounded down: 54.9 -> 54. Zero or missing total gives 0.
function F.Percent(part, total)
  if not total or total <= 0 then return 0 end
  return floor(100 * (part or 0) / total)
end

-- Goes between the parts of a bar item's text: ("%d fps" .. SEP .. "%d ms"). The bar draws it as a thin line in
-- the theme's colour.
F.SEP = "\t"

-- Text in a colour: Colour("hi", 1, 0.82, 0) -> "|cffffd100hi|r".
function F.Colour(text, r, g, b)
  return format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), text)
end
