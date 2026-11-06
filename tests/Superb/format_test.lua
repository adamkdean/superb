-- Pure tests for addons/Superb/Format.lua and Arrange.lua. Run from the repo root: lua tests/Superb/format_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
dofile("addons/Superb/Format.lua")
dofile("addons/Superb/Arrange.lua")
local F = Superb.Format

check.eq("duration nil", F.Duration(nil), "-")
check.eq("duration nan", F.Duration(0 / 0), "-")
check.eq("duration inf", F.Duration(math.huge), "-")
check.eq("duration negative", F.Duration(-5), "-")
check.eq("duration seconds", F.Duration(45), "45s")
check.eq("duration rounds", F.Duration(59.6), "1m")
check.eq("duration minutes", F.Duration(125), "2m")
check.eq("duration hours", F.Duration(3725), "1h 02m")
check.eq("duration days", F.Duration(26 * 3600 + 5), "1d 2h")

check.eq("short small", F.Short(999), "999")
check.eq("short 1.5k", F.Short(1500), "1.5k")
check.eq("short 12.3k", F.Short(12345), "12.3k")
check.eq("short 2k", F.Short(2000), "2k")
check.eq("short 123k", F.Short(123456), "123k")
check.eq("short 2.5m", F.Short(2500000), "2.5m")
check.eq("short nil", F.Short(nil), "-")

check.eq("thousands", F.Thousands(1234567), "1,234,567")
check.eq("thousands small", F.Thousands(999), "999")
check.eq("thousands exact", F.Thousands(100000), "100,000")
check.eq("thousands negative", F.Thousands(-4500), "-4,500")

check.eq("clock 24", F.Clock(14, 5, true), "14:05")
check.eq("clock 24 midnight", F.Clock(0, 0, true), "00:00")
check.eq("clock 12 pm", F.Clock(14, 5, false), "2:05 PM")
check.eq("clock 12 midnight", F.Clock(0, 7, false), "12:07 AM")
check.eq("clock 12 noon", F.Clock(12, 0, false), "12:00 PM")

check.eq("day", F.Day(5, 6, 11), "Thu 6 Nov")
check.eq("day sunday", F.Day(1, 1, 1), "Sun 1 Jan")

check.eq("coins full", F.Coins(123456), "12g 34s 56c")
check.eq("coins copper", F.Coins(50), "50c")
check.eq("coins zero", F.Coins(0), "0c")
check.eq("coins gold only", F.Coins(20000), "2g")
check.eq("coins gold and copper", F.Coins(20005), "2g 0s 5c")
check.eq("coins big", F.Coins(12345670000), "1,234,567g")
check.eq("coins negative", F.Coins(-150), "-1s 50c")
check.eq("money without the game", F.Money(150), "1s 50c")

check.eq("percent", F.Percent(549, 1000), 54)
check.eq("percent zero total", F.Percent(5, 0), 0)
check.eq("colour", F.Colour("hi", 1, 0.82, 0), "|cffffd100hi|r")

local A = Superb.Arrange
check.eq("zone left", A.Zone(100, 900), "left")
check.eq("zone centre", A.Zone(450, 900), "centre")
check.eq("zone right", A.Zone(800, 900), "right")
local items = { { id = "a", x = 50 }, { id = "c", x = 250 }, { id = "b", x = 150 } }
local ids, before = A.Insert(items, "left", "d", 200)
check.eq("left insert", table.concat(ids, ","), "a,b,d,c")
check.eq("left before", before, "c")
ids, before = A.Insert(items, "left", "d", 10)
check.eq("left first", table.concat(ids, ","), "d,a,b,c")
ids, before = A.Insert(items, "left", "d", 400)
check.eq("left last", table.concat(ids, ","), "a,b,c,d")
check.eq("left last before", before, nil)
local right = { { id = "clock", x = 880 }, { id = "gold", x = 800 }, { id = "bags", x = 720 } }
ids = A.Insert(right, "right", "d", 850)
check.eq("right between clock and gold", table.concat(ids, ","), "clock,d,gold,bags")
ids = A.Insert(right, "right", "d", 899)
check.eq("right at the edge", table.concat(ids, ","), "d,clock,gold,bags")
ids = A.Insert({}, "centre", "d", 450)
check.eq("empty zone", table.concat(ids, ","), "d")
check.eq("input not reordered", items[2].id, "c")

check.done()
