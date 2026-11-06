-- Superb modules: bag space and bag value. One scan of the bags serves both.
-- Auction prices come from AuctionDB when it is loaded (read only; its methods are not a declared API,
-- so every call is wrapped and checked here, in one place).
local S, F = Superb, Superb.Format

local scan = { free = 0, total = 0, bags = {}, vendor = 0, junk = 0, auction = 0, best = 0, priced = 0, items = {}, missing = false }
local dirty = true
local scanned = false

S:RegisterNotification("bagsfull", "Bags full")

local function lastBag() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end

-- Lowest current auction price per unit from AuctionDB, or nil.
local function auctionPrice(itemID)
  local adb = _G.AuctionDB
  if type(adb) ~= "table" or type(adb.LastPrice) ~= "function" or type(adb.PlayerHouse) ~= "function" then return end
  local ok, p = pcall(adb.LastPrice, adb, itemID, adb:PlayerHouse())
  if ok and type(p) == "table" and type(p[2]) == "number" and p[2] > 0 then return p[2] end
end

local function hasAuctionDB() return type(_G.AuctionDB) == "table" and type(_G.AuctionDB.LastPrice) == "function" end

local function rescan()
  dirty = false
  local s = { free = 0, total = 0, bags = {}, vendor = 0, junk = 0, auction = 0, best = 0, priced = 0, items = {}, missing = false }
  local byItem = {}
  for bag = 0, lastBag() do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    if slots > 0 then
      local free = C_Container.GetContainerNumFreeSlots(bag) or 0
      s.free, s.total = s.free + free, s.total + slots
      s.bags[#s.bags + 1] = { name = C_Container.GetBagName(bag) or ("Bag " .. bag), free = free, slots = slots }
      for slot = 1, slots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID then
          local count = info.stackCount or 1
          local sell = select(11, C_Item.GetItemInfo(info.itemID))
          if sell == nil then
            s.missing = true
            C_Item.RequestLoadItemDataByID(info.itemID)
          end
          local vendor = (not info.hasNoValue and sell or 0) * count
          s.vendor = s.vendor + vendor
          if info.quality == 0 then s.junk = s.junk + vendor end
          local unit = not info.isBound and auctionPrice(info.itemID)
          local auction = unit and unit * count or 0
          if unit then s.priced = s.priced + 1 end
          s.auction = s.auction + auction
          s.best = s.best + math.max(vendor, auction)
          local e = byItem[info.itemID]
          if not e then
            e = { link = info.hyperlink, count = 0, vendor = 0, auction = 0 }
            byItem[info.itemID] = e
            s.items[#s.items + 1] = e
          end
          e.count, e.vendor, e.auction = e.count + count, e.vendor + vendor, e.auction + auction
        end
      end
    end
  end
  table.sort(s.items, function(a, b) return math.max(a.vendor, a.auction) > math.max(b.vendor, b.auction) end)
  local before = scan.free
  scan = s
  if scanned and before > 0 and s.free == 0 and s.total > 0 then
    S:Notify("bagsfull", "Bags full", "No free bag slots left.")
  end
  scanned = true
end

local function current()
  if dirty then rescan() end
  return scan
end

local pending = false
local function markDirty()
  dirty = true
  if pending then return end
  pending = true
  C_Timer.After(0.5, function()
    pending = false
    S:Refresh("bags")
    S:Refresh("bagvalue")
  end)
end

local function valueCfg() return S:ModuleDB("bagvalue") end
local function useAuction() return valueCfg().source ~= "vendor" and hasAuctionDB() end

S:RegisterModule({
  id = "bags", name = "Bag space", side = "right", order = 40,
  events = { "BAG_UPDATE_DELAYED" },
  OnEvent = function() markDirty() return false end,

  Text = function()
    local s = current()
    return ("Bags %d free"):format(s.free)
  end,

  Tooltip = function(_, tip)
    local s = current()
    tip:AddLine("Bags", 1, 1, 1)
    tip:AddDoubleLine("Free", ("%d of %d"):format(s.free, s.total), nil, nil, nil, 1, 1, 1)
    for _, b in ipairs(s.bags) do
      tip:AddDoubleLine(b.name, ("%d / %d free"):format(b.free, b.slots), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    tip:AddLine(" ")
    tip:AddLine("Left-click: open bags.", 0.6, 0.6, 0.6)
  end,

  OnClick = function()
    if ToggleAllBags then ToggleAllBags() end
  end,
})

S:RegisterModule({
  id = "bagvalue", name = "Bag value", side = "right", order = 30,
  events = { "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" },
  OnEvent = function(_, event)
    if event == "BAG_UPDATE_DELAYED" or scan.missing then markDirty() end
    return false
  end,

  Text = function()
    local s = current()
    return F.Money(useAuction() and s.best or s.vendor, S:Theme().size)
  end,

  Tooltip = function(_, tip)
    local s = current()
    tip:AddLine("Bag value", 1, 1, 1)
    tip:AddDoubleLine("Vendor", F.Money(s.vendor, 12), nil, nil, nil, 1, 1, 1)
    if s.junk > 0 then tip:AddDoubleLine("  of which junk", F.Money(s.junk, 12), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8) end
    if hasAuctionDB() then
      tip:AddDoubleLine("Auction (AuctionDB)", F.Money(s.auction, 12), nil, nil, nil, 1, 1, 1)
      tip:AddDoubleLine("  items with a price", tostring(s.priced), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
      tip:AddDoubleLine("Best of both, per item", F.Money(s.best, 12), nil, nil, nil, 1, 1, 1)
    else
      tip:AddLine("Load AuctionDB for auction prices.", 0.6, 0.6, 0.6)
    end
    if s.missing then tip:AddLine("Some item prices are still loading.", 0.6, 0.6, 0.6) end
    if #s.items > 0 then
      tip:AddLine(" ")
      tip:AddLine("Most valuable", 1, 1, 1)
      for i = 1, math.min(5, #s.items) do
        local e = s.items[i]
        local label = e.count > 1 and (e.link .. " x" .. e.count) or e.link
        tip:AddDoubleLine(label, F.Money(math.max(e.vendor, e.auction), 12), nil, nil, nil, 1, 1, 1)
      end
    end
    tip:AddLine(" ")
    tip:AddLine("With AuctionDB, the bar shows the better of the auction and vendor price for each item. Right-click: options.", 0.6, 0.6, 0.6, true)
  end,

  Menu = function(_, root)
    root:CreateTitle("Bag value")
    local function isSource(v) return (valueCfg().source or "auction") == v end
    local function setSource(v) valueCfg().source = v S:Refresh("bagvalue") end
    root:CreateRadio("Auction price (AuctionDB)", isSource, setSource, "auction")
    root:CreateRadio("Vendor price", isSource, setSource, "vendor")
  end,
})
