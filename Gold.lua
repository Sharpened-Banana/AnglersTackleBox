-- Gold: everything that turns the catch log into money decisions. Best
-- zones and spots by gold per hour, a value-based catch alert, a sell
-- helper at vendors and the auction house, and the session history chart.
--
-- Self-contained on purpose: nothing else depends on this file, so it can
-- be left out of a release by adding it to the ignore list in .pkgmeta and
-- removing it from the TOC files.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Gold = ns:NewModule("Gold")

local COPPER_PER_GOLD = 10000
local AUCTION_CUT = 0.05
local MIN_ZONE_SECONDS = 300

local function MapName(mapID)
  local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or L["Unknown zone"]
end

local function Hours(seconds)
  return string.format(L["%dh %dm"], math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

---------------------------------------------------------------------------
-- Rankings
---------------------------------------------------------------------------

-- Zones by gold per hour, from saved sessions.
function Gold:Zones()
  local byZone = {}
  for _, session in ipairs(ns.chardb.sessions) do
    if session.mapID then
      local zone = byZone[session.mapID] or { mapID = session.mapID, value = 0, seconds = 0, sessions = 0 }
      zone.value = zone.value + session.value
      zone.seconds = zone.seconds + math.max(0, session.stop - session.start)
      zone.sessions = zone.sessions + 1
      byZone[session.mapID] = zone
    end
  end
  local list = {}
  for _, zone in pairs(byZone) do
    if zone.seconds >= MIN_ZONE_SECONDS then
      zone.perHour = zone.value / zone.seconds * 3600
      list[#list + 1] = zone
    end
  end
  table.sort(list, function(a, b) return a.perHour > b.perHour end)
  return list
end

-- Individual spots by gold per hour at current prices.
function Gold:Spots()
  local list = {}
  for mapID, spots in pairs(ns.chardb.spots) do
    for _, spot in ipairs(spots) do
      local _, perHour = ns.Spots.Value(spot)
      if perHour then list[#list + 1] = { mapID = mapID, spot = spot, perHour = perHour } end
    end
  end
  table.sort(list, function(a, b) return a.perHour > b.perHour end)
  return list
end

local function Days(age)
  if age == 0 then return L["today"] end
  return string.format(age == 1 and L["%d day ago"] or L["%d days ago"], age)
end

function Gold:Lines()
  local lines = {}
  local age = self:PriceAge()
  if not age then
    lines[#lines + 1] = { header = true,
      text = L["Prices: vendor value only. Install Auctionator for auction prices."] }
  elseif age.total > 0 then
    local text
    if age.newest then
      text = string.format(L["Auction prices: newest %s, oldest %s."], Days(age.newest), Days(age.oldest))
    else
      text = L["Auction prices: none seen yet."]
    end
    if age.unseen > 0 then text = text .. " " .. string.format(L["%d fish never priced."], age.unseen) end
    lines[#lines + 1] = { text = text, header = true }
    if self:PricesStale() then
      lines[#lines + 1] = { text = L["Visit the auction house to refresh them (/tb scan while it is open)."] }
    end
  end
  lines[#lines + 1] = { text = L["Best zones by gold per hour (your sessions):"], header = true }
  local zones = self:Zones()
  for index = 1, math.min(8, #zones) do
    local zone = zones[index]
    lines[#lines + 1] = { text = string.format(L["%d. %s - %s/hr  (%d sessions, %s)"], index,
      MapName(zone.mapID), Compat.CoinString(zone.perHour), zone.sessions, Hours(zone.seconds)) }
  end
  if #zones == 0 then
    lines[#lines + 1] = { text = L["Not enough yet: a zone needs five minutes of saved sessions."] }
  end

  lines[#lines + 1] = { text = L["Best spots by gold per hour (today's prices):"], header = true }
  local spots = self:Spots()
  for index = 1, math.min(10, #spots) do
    local row = spots[index]
    lines[#lines + 1] = { text = string.format("%d. %s, %s (%.1f, %.1f) - %s/hr", index,
      ns.Spots.Name(row.spot), MapName(row.mapID), row.spot.x * 100, row.spot.y * 100,
      Compat.CoinString(row.perHour)) }
  end
  if #spots == 0 then
    lines[#lines + 1] = { text = L["Not enough yet: a spot needs three minutes of fishing."] }
  end
  return lines
end

-- Gold per hour of the most recent sessions, oldest first, for the chart.
function Gold:History(count)
  local sessions, out = ns.chardb.sessions, {}
  for index = math.max(1, #sessions - count + 1), #sessions do
    local session = sessions[index]
    local seconds = math.max(0, session.stop - session.start)
    out[#out + 1] = {
      perHour = seconds >= 60 and (session.value / seconds * 3600) or 0,
      value = session.value, start = session.start, mapID = session.mapID,
    }
  end
  return out
end

---------------------------------------------------------------------------
-- Value alert: a single catch worth at least the chosen amount.
---------------------------------------------------------------------------

ns:On("CATCH", function(_, name, quantity, _, unit)
  local threshold = (ns.db.valueAlert or 0) * COPPER_PER_GOLD
  if threshold <= 0 then return end
  local worth = unit * quantity
  if worth >= threshold then
    ns.Alerts:Fire("value", string.format(L["%s is worth %s!"], name, Compat.CoinString(worth)))
  end
end)

---------------------------------------------------------------------------
-- Sell helper: when a vendor or the auction house opens, say what the
-- session's fish are worth and which are better vendored than listed.
---------------------------------------------------------------------------

function Gold:SellLines()
  local session = ns.Log.session or ns.Log.lastSession
  local lines = {}
  if not session then return lines end

  local total, vendorThese = 0, {}
  for itemID in pairs(session.items) do
    local held = Compat.GetItemCount(itemID)
    if held > 0 then
      local auction, vendor = ns.Log.Prices(itemID)
      local name = Compat.GetItemInfo(itemID) or ("item:" .. itemID)
      local listed = auction and auction * (1 - AUCTION_CUT) or 0
      if vendor > 0 and vendor >= listed then
        vendorThese[#vendorThese + 1] = string.format("%s x%d (%s)", name, held, Compat.CoinString(vendor * held))
        total = total + vendor * held
      else
        total = total + listed * held
      end
    end
  end
  if total == 0 then return lines end
  lines[1] = { text = string.format(L["Your session's fish are worth about %s after the auction cut."],
    Compat.CoinString(total)), header = true }
  if #vendorThese > 0 then
    lines[2] = { text = L["Better sold to a vendor:"] .. " " .. table.concat(vendorThese, ", ") }
  end
  return lines
end

---------------------------------------------------------------------------
-- Price refresh: the game only answers auction queries while the auction
-- house is open, so that is when fish prices get refreshed. Auctionator does
-- the searching and keeps the prices; Tacklebox just hands it the fish list.
---------------------------------------------------------------------------

local SCAN_LIMIT = 80 -- fish names per search, most caught first

local function AuctionatorAPI()
  return Auctionator and Auctionator.API and Auctionator.API.v1
end

local function AuctionHouseOpen()
  return (AuctionHouseFrame and AuctionHouseFrame:IsShown())
    or (AuctionFrame and AuctionFrame:IsShown()) or false
end

-- Days since each logged fish was last priced: newest, oldest, and how many
-- have never been seen. nil without Auctionator.
function Gold:PriceAge()
  local api = AuctionatorAPI()
  if not api or not api.GetAuctionAgeByItemID then return nil end
  local newest, oldest, unseen, total = nil, nil, 0, 0
  for _, fish in ipairs(ns.Journal:Fish()) do
    total = total + 1
    local ok, age = pcall(api.GetAuctionAgeByItemID, "Tacklebox", fish.id)
    if ok and age then
      newest = math.min(newest or age, age)
      oldest = math.max(oldest or age, age)
    else
      unseen = unseen + 1
    end
  end
  return { newest = newest, oldest = oldest, unseen = unseen, total = total }
end

function Gold:PricesStale()
  local age = self:PriceAge()
  if not age or age.total == 0 then return false end
  return age.unseen > 0 or (age.oldest or 0) >= (ns.db.ahScanDays or 1)
end

-- Searches the auction house for every logged fish. Returns false and a
-- reason when it can't.
function Gold:Scan()
  local api = AuctionatorAPI()
  if not api or not api.MultiSearchExact then
    return false, L["Price scans need the Auctionator addon."]
  end
  if not AuctionHouseOpen() then
    return false, L["Open the auction house first - the game only answers price queries there."]
  end
  local names = {}
  for _, fish in ipairs(ns.Journal:Fish()) do
    -- Item names only; Auctionator rejects terms with these characters.
    if #names < SCAN_LIMIT and not fish.name:find("^item:") and not fish.name:find('[;^"]') then
      names[#names + 1] = fish.name
    end
  end
  if #names == 0 then return false, L["No fish in your log to price yet."] end
  local ok, problem = pcall(api.MultiSearchExact, "Tacklebox", names)
  if not ok then return false, tostring(problem) end
  self.lastScan = GetTime()
  return true, string.format(L["Pricing %d kinds of fish. Auctionator shows the results in its Shopping tab."], #names)
end

local frame
local function OnShopOpened(_, event)
  if event == "AUCTION_HOUSE_SHOW" and ns.db.ahScan and Gold:PricesStale() then
    -- Give Auctionator a moment to build its tabs.
    C_Timer.After(1, function()
      if not AuctionHouseOpen() then return end
      local ok, message = Gold:Scan()
      if ok then ns:Print(message) end
    end)
  end
  local now = GetTime()
  if Gold.lastShop and now - Gold.lastShop < 30 then return end
  Gold.lastShop = now
  ns:PrintLines(Gold:SellLines())
end

-- Opening the auction house never happens in combat, so this one event is
-- safe to keep registered. The vendor event waits for a session.
function Gold:Init()
  frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", OnShopOpened)
  pcall(frame.RegisterEvent, frame, "AUCTION_HOUSE_SHOW")
end

ns:On("SESSION_START", function()
  if frame then frame:RegisterEvent("MERCHANT_SHOW") end
end)
