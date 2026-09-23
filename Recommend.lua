-- "Where should I fish now?": ranks the player's zones by gold/hour (Spots),
-- falling back to catch rate (Stats) then catch count (Log) when data is thin.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Recommend = {}
ns.Recommend = Recommend

local MIN_SECONDS_FOR_RATE = 300 -- timed spot-seconds before gold/hour is trusted
local MIN_CASTS_FOR_RATE = 10    -- casts before a catch rate means anything
local LOW_RATE_WARNING = 0.5     -- flag the current spot when under this share of the best known rate
local MAX_ROWS = 5

local function ZoneName(mapID)
  local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or L["Unknown zone"]
end

-- Spots.Value returns a value even untimed, so every catch counts toward
-- the 5-minute threshold.
local function SpotTotals(mapID)
  local seconds, value = 0, 0
  for _, spot in ipairs(ns.chardb.spots[mapID] or {}) do
    local spotValue = ns.Spots.Value(spot)
    seconds = seconds + spot.seconds
    value = value + spotValue
  end
  return seconds, value
end

-- Read from the catch log because it outlives Stats:Reset().
local function LoggedCatches(mapID)
  local total = 0
  for _, entry in pairs(ns.chardb.log[mapID] or {}) do
    total = total + (entry.count or 0)
  end
  return total
end

-- One row per zone with data in any of the three sources.
local function ZoneRows()
  local mapIDs, seen = {}, {}
  local function Note(mapID)
    if mapID and not seen[mapID] then
      seen[mapID] = true
      mapIDs[#mapIDs + 1] = mapID
    end
  end
  for mapID in pairs(ns.chardb.spots) do Note(mapID) end
  for mapID in pairs(ns.chardb.log) do Note(mapID) end
  local statsData = ns.Stats and ns.Stats:Data()
  if statsData and statsData.zones then
    for mapID in pairs(statsData.zones) do Note(mapID) end
  end

  local rows = {}
  for _, mapID in ipairs(mapIDs) do
    local seconds, value = SpotTotals(mapID)
    local zoneStats = statsData and statsData.zones and statsData.zones[mapID]
    local casts = zoneStats and zoneStats.casts or 0
    local catches = zoneStats and zoneStats.catches or 0
    local logCatches = LoggedCatches(mapID)
    if logCatches > catches then catches = logCatches end

    if casts > 0 or catches > 0 or seconds > 0 then
      local perHour = seconds >= MIN_SECONDS_FOR_RATE and (value / seconds * 3600) or nil
      local rate = casts >= MIN_CASTS_FOR_RATE and (catches / casts) or nil
      rows[#rows + 1] = {
        mapID = mapID, name = ZoneName(mapID), seconds = seconds, value = value,
        perHour = perHour, casts = casts, catches = catches, rate = rate,
      }
    end
  end
  return rows
end

local function Metric(row)
  if row.perHour then return "perHour", row.perHour end
  if row.rate then return "rate", row.rate end
  return "catches", row.catches
end

local METRIC_RANK = { perHour = 3, rate = 2, catches = 1 }

-- Metrics are never compared across tiers: any gold/hour row outranks any
-- catch-rate row, since the numbers carry different confidence.
local function CompareRows(a, b)
  local metricA, valueA = Metric(a)
  local metricB, valueB = Metric(b)
  if METRIC_RANK[metricA] ~= METRIC_RANK[metricB] then
    return METRIC_RANK[metricA] > METRIC_RANK[metricB]
  end
  return valueA > valueB
end

function Recommend:Rank()
  local rows = ZoneRows()
  table.sort(rows, CompareRows)
  return rows
end

local function RowText(row, rank)
  local metric, value = Metric(row)
  if metric == "perHour" then
    return string.format(L["#%d  %s - %s per hour"], rank, row.name, Compat.CoinString(value))
  elseif metric == "rate" then
    return string.format(L["#%d  %s - %d%% catch rate (%d casts, not enough timed data for gold/hour yet)"],
      rank, row.name, math.floor(value * 100 + 0.5), row.casts)
  else
    return string.format(L["#%d  %s - %d fish caught (too little data yet for a rate)"],
      rank, row.name, row.catches)
  end
end

-- Best spot in a zone: by gold/hour where timed, else raw value.
local function BestSpotIn(mapID)
  local best, bestScore, bestPerHour
  for _, spot in ipairs(ns.chardb.spots[mapID] or {}) do
    local value, perHour = ns.Spots.Value(spot)
    local score = perHour or value
    if score and (not bestScore or score > bestScore) then
      best, bestScore, bestPerHour = spot, score, perHour
    end
  end
  return best, bestPerHour
end

function Recommend:Lines()
  local lines = {}
  local function Header(text) lines[#lines + 1] = { text = text, header = true } end
  local function Add(text) lines[#lines + 1] = { text = text } end

  local rows = self:Rank()
  if #rows == 0 then
    Add(L["Nothing yet - fish a few spots and check back."])
    return lines
  end

  Header(L["Recommended zones"])
  for index = 1, math.min(MAX_ROWS, #rows) do
    Add(RowText(rows[index], index))
  end

  local best = rows[1]
  if not best.perHour then
    Add(L["Still building confidence: a few minutes at one spot lets gold/hour be measured."])
  end

  local bestSpot, bestSpotPerHour = BestSpotIn(best.mapID)
  if bestSpot and bestSpotPerHour then
    Header(L["Best known spot"])
    Add(string.format(L["%s in %s: %s per hour"], ns.Spots.Name(bestSpot), best.name,
      Compat.CoinString(bestSpotPerHour)))
  end

  -- Warn about a slow current spot only once there's a confident best rate.
  local session = ns.Log and ns.Log.session
  local stats = session and ns.Log:Stats()
  if best.perHour and stats and stats.perHour > 0 then
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mapID and stats.perHour < best.perHour * LOW_RATE_WARNING then
      Header(L["Right now"])
      Add(string.format(L["This spot is running %s per hour - %s in %s has done much better."],
        Compat.CoinString(stats.perHour), Compat.CoinString(best.perHour), best.name))
    end
  end

  return lines
end
