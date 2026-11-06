-- Pure tests for Superb/Modules/Hunter/Pet.lua. Run from the repo root: lua tests/pet_test.lua
package.path = "tests/lib/?.lua;" .. package.path
local check = require("check")
local ns = {}
loadfile("Superb/Modules/Hunter/Pet.lua")("Superb", ns)
local Pet = ns.Pet

local foods = {
  { bag = 0, slot = 1, itemID = 10, count = 5, level = 5, link = "[Old Cheese]" },
  { bag = 0, slot = 2, itemID = 11, count = 2, level = 25, link = "[Skycheddar]" },
  { bag = 1, slot = 4, itemID = 12, count = 3, level = 15, link = "[Fruit]" },
  { bag = 1, slot = 5, itemID = 11, count = 1, level = 25, link = "[Skycheddar]" },
}
check.eq("lowest that works", Pet.ChooseFood(foods, 20, "lowest").itemID, 12)
check.eq("highest", Pet.ChooseFood(foods, 20, "highest").itemID, 11)
check.eq("all too low: highest", Pet.ChooseFood({ foods[1] }, 40, "lowest").itemID, 10)
check.eq("edge of the gap counts", Pet.ChooseFood(foods, 25, "lowest").itemID, 12)
check.eq("no food", Pet.ChooseFood({}, 20, "lowest"), nil)

local total, list = Pet.CountFood(foods)
check.eq("total", total, 11)
check.eq("one entry per item", #list, 3)
check.eq("merged stacks", list[3].count, 3)
check.eq("sorted by level", list[1].itemID, 10)

check.eq("macro with food", Pet.FeedMacro("Feed Pet", foods[3]), "/cast Feed Pet\n/use 1 4")
check.eq("macro without food", Pet.FeedMacro("Feed Pet", nil), "/cast Feed Pet")

check.eq("trend up", Pet.LoyaltyTrend(2), "rising")
check.eq("trend down", Pet.LoyaltyTrend(-1), "falling")
check.eq("trend none", Pet.LoyaltyTrend(0), "steady")
check.eq("trend nil", Pet.LoyaltyTrend(nil), "steady")
check.eq("moods", Pet.MOODS[3].name .. Pet.MOODS[2].name .. Pet.MOODS[1].name, "HappyContentUnhappy")
check.done()
