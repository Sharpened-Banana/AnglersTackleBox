-- Catch Log: every catch by zone and subzone, plus live session stats.
-- Reads the loot window (LOOT_READY + GetLootSlotLink) rather than chat,
-- because chat loot messages may be secret inside instances on 12.x.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Log = ns:NewModule("Log")

local MAX_SESSIONS = 30
local SESSION_IDLE = 600 -- always-on: a session closes after this long without fishing
local HOVER_WINDOW = 20 -- seconds a hovered pool stays valid before a cast
local HookTooltips
local LOOT_SLOT_ITEM = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1

local function NewSession()
  return {
    start = time(), t0 = GetTime(),
    casts = 0, catches = 0, value = 0, sinceRare = 0,
    items = {},
  }
end

-- Copper value of one item: auction price when a pricing addon is loaded,
-- vendor price otherwise.
local UnitValue
function Log.UnitValue(itemID) return UnitValue(itemID) end

-- Grey items have no real auction market, only troll listings, so they are
-- always worth what a vendor pays.
function Log.IsJunk(itemID)
  local _, _, quality = Compat.GetItemInfo(itemID)
  return quality == 0
end

---------------------------------------------------------------------------
-- Prices, guarded against troll listings. Junk is vendor-only. For the rest:
-- the lower of Auctionator and TSM when both are loaded; a per-item memory
-- that ignores a price jumping SPIKE-fold unless it is still there on a
-- later day; and an absolute ceiling per single fish.
---------------------------------------------------------------------------

local SPIKE = 10
local CACHE_SECONDS = 5
local COPPER_PER_GOLD = 10000
local priceCache = {}
Log.suspect = {} -- [itemID] = { listed = copper, used = copper }

local function RawAuctionPrice(itemID)
  local lowest
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, price = pcall(api.GetAuctionPriceByItemID, "Angler's TackleBox", itemID)
    if ok and price and price > 0 then lowest = price end
  end
  if TSM_API and TSM_API.GetCustomPriceValue then
    local ok, price = pcall(TSM_API.GetCustomPriceValue, "dbmarket", "i:" .. itemID)
    if ok and price and price > 0 then lowest = math.min(lowest or price, price) end
  end
  return lowest
end

-- The price to trust for an item, given what the pricing addons say now.
local function Guarded(itemID, raw)
  local memory = ns.db.prices
  local known = memory[itemID]
  local today = date("%Y-%m-%d")
  local ceiling = (ns.db.priceCap or 0) * COPPER_PER_GOLD

  if ceiling > 0 and raw > ceiling then
    Log.suspect[itemID] = { listed = raw, used = known and known.price or 0 }
    return known and known.price or nil
  end

  if known and raw > known.price * SPIKE then
    -- A spike. Believe it only once it has lasted into another day.
    local pending = known.pending
    if pending and pending.day ~= today and raw >= pending.price / 2 then
      memory[itemID] = { price = raw, day = today }
      Log.suspect[itemID] = nil
      return raw
    end
    if not pending then known.pending = { price = raw, day = today } end
    Log.suspect[itemID] = { listed = raw, used = known.price }
    return known.price
  end

  memory[itemID] = { price = raw, day = today }
  Log.suspect[itemID] = nil
  return raw
end

-- Auction price (nil without a pricing addon, and for junk) and vendor
-- price, in copper.
function Log.Prices(itemID)
  local now = GetTime()
  local cached = priceCache[itemID]
  if cached and now - cached.at < CACHE_SECONDS then return cached.auction, cached.vendor end

  local auction
  if not Log.IsJunk(itemID) then
    local raw = RawAuctionPrice(itemID)
    if raw then auction = Guarded(itemID, raw) end
  end
  local _, _, _, _, _, _, _, _, _, _, vendor = Compat.GetItemInfo(itemID)
  vendor = vendor or 0
  priceCache[itemID] = { at = now, auction = auction, vendor = vendor }
  return auction, vendor
end

function Log.ForgetPrices()
  wipe(priceCache)
end

function UnitValue(itemID)
  local auction, vendor = Log.Prices(itemID)
  return auction or vendor
end

-- With always-on the session starts at the first cast instead.
function Log:Enable()
  self.session = not ns.db.alwaysOn and NewSession() or nil
  self.lootSeen, self.pool, self.hovered = nil, nil, nil
  HookTooltips()
end

function Log:Disable()
  self:EndSession()
end

function Log:Tick()
  if ns.db.alwaysOn and self.session and ns.Engine.state ~= "CHANNELING"
    and GetTime() - (ns.Core.lastActivity or 0) > SESSION_IDLE then
    self:EndSession()
  end
end

function Log:EndSession()
  local s = self.session
  self.session = nil
  ns.HUD:UpdateVisibility()
  if not s or s.casts == 0 then return end

  local sessions = ns.chardb.sessions
  local summary = {
    start = s.start, stop = time(),
    casts = s.casts, catches = s.catches, value = s.value,
    mapID = C_Map and C_Map.GetBestMapForUnit("player") or nil,
  }
  table.insert(sessions, summary)
  self.lastSession = s -- the sell helper still wants its items
  ns:Fire("SESSION_END", summary, s)

  -- Old sessions roll up into daily totals so the file stays small.
  while #sessions > MAX_SESSIONS do
    local old = table.remove(sessions, 1)
    local day = date("%Y-%m-%d", old.start)
    local total = ns.chardb.daily[day] or { casts = 0, catches = 0, value = 0, seconds = 0 }
    total.casts = total.casts + old.casts
    total.catches = total.catches + old.catches
    total.value = total.value + old.value
    total.seconds = total.seconds + math.max(0, old.stop - old.start)
    ns.chardb.daily[day] = total
  end
end

function Log:OnCast()
  if not self.session then
    self.session = NewSession()
    ns.HUD:UpdateVisibility()
  end
  if self.session.casts == 0 then ns:Fire("SESSION_START") end
  local hovered = self.hovered
  if hovered and GetTime() - hovered.at <= HOVER_WINDOW then self.pool = hovered.name end
  local s = self.session
  if s.casts == 0 then s.t0 = GetTime() end -- the clock starts at the first cast
  s.casts = s.casts + 1
  s.sinceRare = s.sinceRare + 1
  ns.HUD:Refresh()
end

function Log:Stats()
  local s = self.session
  if not s then return nil end
  local elapsed = s.casts > 0 and (GetTime() - s.t0) or 0
  return {
    casts = s.casts,
    catches = s.catches,
    rate = s.casts > 0 and (s.catches / s.casts) or 0,
    value = s.value,
    perHour = elapsed >= 60 and (s.value / elapsed * 3600) or 0,
    sinceRare = s.sinceRare,
    elapsed = elapsed,
  }
end

local function Record(itemID, name, quantity, quality)
  local s = Log.session
  local now = time()
  local mapID = (C_Map and C_Map.GetBestMapForUnit("player")) or 0
  local subzone = GetSubZoneText() or ""
  if subzone == "" then subzone = GetZoneText() or "" end

  local zone = ns.chardb.log[mapID]
  if not zone then zone = {} ns.chardb.log[mapID] = zone end
  local entry = zone[itemID]
  if not entry then
    entry = { count = 0, first = now, subs = {} }
    zone[itemID] = entry
  end
  entry.count = entry.count + quantity
  entry.last = now
  entry.name = name
  entry.subs[subzone] = (entry.subs[subzone] or 0) + quantity

  local unit = UnitValue(itemID)
  s.items[itemID] = (s.items[itemID] or 0) + quantity
  s.value = s.value + unit * quantity
  ns:Fire("CATCH", itemID, name, quantity, quality, unit)

  if Log.pool then
    entry.pools = entry.pools or {}
    entry.pools[Log.pool] = (entry.pools[Log.pool] or 0) + quantity
  end

  local special = Data.special[itemID]
  local isRare = special ~= nil or (quality or 0) >= ns.db.alertQuality
  if isRare then
    s.sinceRare = 0
    if special == "teleport" then
      ns.Alerts:Fire("teleport", string.format(L["%s: it teleports you to a random zone!"], name))
    elseif special == "hostile" then
      ns.Alerts:Fire("hostile", string.format(L["%s: a hostile spirit is coming."], name))
    elseif special == "mount" then
      ns.Alerts:Fire("mount", string.format(L["%s! That hatches into a mount!"], name))
    else
      ns.Alerts:Fire("rare", string.format(L["Caught %s!"], name))
    end
  end
end

---------------------------------------------------------------------------
-- Pools: the game never says which pool a cast landed in. The best signal
-- is the pool the player hovered shortly before casting; it sticks until
-- they move. Retail only (object tooltips), and only while fishing mode is on.
---------------------------------------------------------------------------

local tooltipHooked

local function LooksLikePool(name)
  if GetLocale() ~= "enUS" then return true end
  for _, word in ipairs(Data.poolWords) do
    if name:find(word, 1, true) then return true end
  end
  return false
end

function HookTooltips()
  if tooltipHooked or not TooltipDataProcessor or not (Enum.TooltipDataType and Enum.TooltipDataType.Object) then
    return
  end
  tooltipHooked = true
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip, data)
    if not ns.Core.mode or ns.Core.suspended or tooltip ~= GameTooltip then return end
    local line = data and data.lines and data.lines[1]
    local name = line and line.leftText
    if name and not Compat.IsSecret(name) and LooksLikePool(name) then
      Log.hovered = { name = name, at = GetTime() }
    end
  end)
end

ns:OnModeEvent("PLAYER_STARTED_MOVING", function()
  Log.pool, Log.hovered = nil, nil
end)

local function OnLoot()
  local s = Log.session
  if not s or Log.lootSeen then return end
  local engine = ns.Engine
  local recentlyFished = engine.state == "CHANNELING"
    or (engine.lastFishEnd ~= nil and GetTime() - engine.lastFishEnd < 3)
  if not Compat.IsFishingLoot(recentlyFished) then return end
  Log.lootSeen = true

  local caught, looted = false, {}
  for slot = 1, GetNumLootItems() do
    if GetLootSlotType(slot) == LOOT_SLOT_ITEM then
      local link = GetLootSlotLink(slot)
      local _, name, quantity, _, quality = GetLootSlotInfo(slot)
      if link and not Compat.IsSecret(link) and not Compat.IsSecret(name) then
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then
          Record(itemID, name, quantity or 1, quality)
          looted[itemID] = (looted[itemID] or 0) + (quantity or 1)
          caught = true
        end
      end
    end
  end
  if caught then
    s.catches = s.catches + 1
    ns:Fire("CAST_LOOTED", looted, Log.pool)
  end
  ns.HUD:Refresh()
end

ns:OnModeEvent("LOOT_READY", OnLoot)
ns:OnModeEvent("LOOT_OPENED", OnLoot)
ns:OnModeEvent("LOOT_CLOSED", function() Log.lootSeen = nil end)

---------------------------------------------------------------------------
-- Upkeep: the log is the player's to prune.
---------------------------------------------------------------------------

-- Forgets a zone's catches and its fishing spots.
function Log:ForgetZone(mapID)
  ns.chardb.log[mapID] = nil
  ns.chardb.spots[mapID] = nil
  ns.Spots:RefreshPins()
end

-- Saved sessions, newest first, for /tb sessions and the gold chart.
function Log:SessionLines(count)
  local sessions = ns.chardb.sessions
  local lines = { { text = string.format(L["Saved sessions (%d, newest first):"], #sessions), header = true } }
  for index = #sessions, math.max(1, #sessions - count + 1), -1 do
    local session = sessions[index]
    lines[#lines + 1] = { text = string.format("#%d  %s  %d casts, %d catches, %s", index,
      date("%Y-%m-%d %H:%M", session.start), session.casts, session.catches, Compat.CoinString(session.value)) }
  end
  if #sessions == 0 then lines[#lines + 1] = { text = L["None yet."] } end
  return lines
end

function Log:DropSession(index)
  return table.remove(ns.chardb.sessions, index) ~= nil
end

function Log:ClearSessions()
  wipe(ns.chardb.sessions)
  wipe(ns.chardb.daily)
end

-- The whole catch log as CSV text.
function Log:ExportCSV()
  local rows = { "zone,map_id,item,item_id,count,first_catch,last_catch,subzones,pools" }
  local function Quote(text) return '"' .. tostring(text):gsub('"', '""') .. '"' end
  local function Flat(tbl)
    local parts = {}
    for name, count in pairs(tbl or {}) do parts[#parts + 1] = name .. " " .. count end
    table.sort(parts)
    return table.concat(parts, "; ")
  end
  for mapID, zone in pairs(ns.chardb.log) do
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    for itemID, entry in pairs(zone) do
      rows[#rows + 1] = table.concat({
        Quote(info and info.name or mapID), mapID, Quote(entry.name or ""), itemID, entry.count,
        entry.first and date("%Y-%m-%d", entry.first) or "", entry.last and date("%Y-%m-%d", entry.last) or "",
        Quote(Flat(entry.subs)), Quote(Flat(entry.pools)),
      }, ",")
    end
  end
  return table.concat(rows, "\n"), #rows - 1
end

function Log:ResetSession()
  if self.session then self.session = NewSession() end
  ns.HUD:Refresh()
end

-- /tb stats
function Log:PrintStats()
  local stats = self:Stats()
  if stats then
    ns:Print(string.format(L["Session: %d casts, %d catches (%d%%), %s, %s/hour."],
      stats.casts, stats.catches, math.floor(stats.rate * 100 + 0.5),
      Compat.CoinString(stats.value), Compat.CoinString(stats.perHour)))
  end

  local mapID = (C_Map and C_Map.GetBestMapForUnit("player")) or 0
  local zone = ns.chardb.log[mapID]
  if not zone then
    ns:Print(L["Nothing logged in this zone yet."])
    return
  end
  local rows = {}
  for itemID, entry in pairs(zone) do
    rows[#rows + 1] = { name = entry.name or ("item:" .. itemID), count = entry.count }
  end
  table.sort(rows, function(a, b) return a.count > b.count end)
  ns:Print(string.format(L["All-time catches in %s:"], GetZoneText() or "?"))
  for i = 1, math.min(10, #rows) do
    print(string.format("   %5d  %s", rows[i].count, rows[i].name))
  end
end
