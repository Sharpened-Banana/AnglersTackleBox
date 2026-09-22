-- Lifetime fishing statistics: casts, catch rate, time spent, quality mix.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Stats = {}
ns.Stats = Stats

local QUALITY_NAMES = {
  [0] = L["Poor"], [1] = L["Common"], [2] = L["Uncommon"], [3] = L["Rare"], [4] = L["Epic"], [5] = L["Legendary"],
}

-- The lifetime totals, created on first use. An existing player starts from
-- their saved sessions and daily roll-ups instead of from zero.
function Stats:Data()
  local chardb = ns.chardb
  local data = chardb.lifetime
  if data then return data end
  data = {
    since = time(), casts = 0, catches = 0, items = 0, value = 0,
    seconds = 0, castSeconds = 0, sessions = 0, longest = 0, quality = {},
  }
  local first
  local function Fold(casts, catches, value, seconds, sessions, start)
    data.casts, data.catches, data.value = data.casts + casts, data.catches + catches, data.value + value
    data.seconds, data.sessions = data.seconds + seconds, data.sessions + sessions
    data.longest = math.max(data.longest, seconds / math.max(1, sessions))
    if start and (not first or start < first) then first = start end
  end
  for _, session in ipairs(chardb.sessions or {}) do
    Fold(session.casts, session.catches, session.value, math.max(0, session.stop - session.start), 1, session.start)
  end
  for day, total in pairs(chardb.daily or {}) do
    local y, m, d = day:match("^(%d+)-(%d+)-(%d+)$")
    Fold(total.casts, total.catches, total.value, total.seconds, 0, y and time({ year = y, month = m, day = d }))
  end
  data.since = first or data.since
  chardb.lifetime = data
  return data
end

local function ZoneRow(data, mapID)
  data.zones = data.zones or {}
  local row = data.zones[mapID]
  if not row then
    row = { casts = 0, catches = 0 }
    data.zones[mapID] = row
  end
  return row
end

local function CurrentMap()
  return (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or 0
end

ns:On("CAST_START", function()
  local data = Stats:Data()
  data.casts = data.casts + 1
  local zone = ZoneRow(data, CurrentMap())
  zone.casts = zone.casts + 1
  Stats.castMap = CurrentMap()
  Stats.castStart = GetTime()
  Stats:SyncAccount()
end)

-- Time the line was in the water, from the cast to the reel-in.
ns:On("CAST_END", function()
  if not Stats.castStart then return end
  local data = Stats:Data()
  data.castSeconds = data.castSeconds + math.max(0, GetTime() - Stats.castStart)
  Stats.castStart = nil
  Stats:SyncAccount()
end)

ns:On("CATCH", function(_, _, quantity, quality, unit)
  local data = Stats:Data()
  data.items = data.items + quantity
  data.value = data.value + (unit or 0) * quantity
  quality = quality or 1
  data.quality[quality] = (data.quality[quality] or 0) + quantity
  Stats:SyncAccount()
end)

ns:On("CAST_LOOTED", function()
  local data = Stats:Data()
  data.catches = data.catches + 1
  local zone = ZoneRow(data, Stats.castMap or CurrentMap())
  zone.catches = zone.catches + 1
  Stats:SyncAccount()
end)

ns:On("SESSION_END", function(summary)
  local data = Stats:Data()
  local seconds = math.max(0, summary.stop - summary.start)
  data.sessions = data.sessions + 1
  data.seconds = data.seconds + seconds
  data.longest = math.max(data.longest, seconds)
  Stats:SyncAccount()
end)

-- Starts the totals over. They are not re-seeded from old sessions.
function Stats:Reset()
  ns.chardb.lifetime = {
    since = time(), casts = 0, catches = 0, items = 0, value = 0,
    seconds = 0, castSeconds = 0, sessions = 0, longest = 0, quality = {}, zones = {},
  }
  self:SyncAccount()
end

---------------------------------------------------------------------------
-- Account-wide (warband) totals: this character's lifetime Stats mirrored
-- into ns.db (account-wide), keyed by name-realm, so every character that
-- has played this addon on the account shows up in one place.
---------------------------------------------------------------------------

-- Stable across sessions and realms; nil while the player unit isn't ready
-- yet (should not happen once ADDON_LOADED / PLAYER_ENTERING_WORLD fired).
function Stats:AccountKey()
  local name = UnitName and UnitName("player")
  if not name or name == "" then return nil end
  local realm = (GetRealmName and GetRealmName()) or "?"
  if realm == "" then realm = "?" end
  return name .. "-" .. realm
end

-- Called after every lifetime-affecting event, and on reset, so the
-- account-wide slot never drifts from this character's own totals.
function Stats:SyncAccount()
  local key = self:AccountKey()
  if not key then return end
  local data = self:Data()
  ns.db.characters = ns.db.characters or {}
  ns.db.characters[key] = {
    name = key:match("^(.-)%-[^-]+$") or key,
    realm = key:match("%-([^-]+)$") or "?",
    casts = data.casts, catches = data.catches, items = data.items, value = data.value,
    seconds = data.seconds, since = data.since, updated = time(),
  }
end

-- Combined totals across every known character, plus the list they were
-- built from (sorted by gold value, richest first).
function Stats:AccountData()
  local characters = ns.db.characters or {}
  local combined = { casts = 0, catches = 0, items = 0, value = 0, seconds = 0, count = 0 }
  local list = {}
  for _, entry in pairs(characters) do
    combined.casts = combined.casts + (entry.casts or 0)
    combined.catches = combined.catches + (entry.catches or 0)
    combined.items = combined.items + (entry.items or 0)
    combined.value = combined.value + (entry.value or 0)
    combined.seconds = combined.seconds + (entry.seconds or 0)
    combined.count = combined.count + 1
    list[#list + 1] = entry
  end
  table.sort(list, function(a, b) return (a.value or 0) > (b.value or 0) end)
  return combined, list
end

-- Casts, catches, value and time over the last `days` days, from the saved
-- sessions, the daily roll-ups and the session in progress.
function Stats:Window(days)
  local cutoff = time() - days * 86400
  local total = { casts = 0, catches = 0, value = 0, seconds = 0 }
  local function Add(casts, catches, value, seconds)
    total.casts, total.catches = total.casts + casts, total.catches + catches
    total.value, total.seconds = total.value + value, total.seconds + seconds
  end
  for _, session in ipairs(ns.chardb.sessions or {}) do
    if session.start >= cutoff then
      Add(session.casts, session.catches, session.value, math.max(0, session.stop - session.start))
    end
  end
  for day, entry in pairs(ns.chardb.daily or {}) do
    local y, m, d = day:match("^(%d+)-(%d+)-(%d+)$")
    if y and time({ year = y, month = m, day = d, hour = 23 }) >= cutoff then
      Add(entry.casts, entry.catches, entry.value, entry.seconds)
    end
  end
  local live = ns.Log and ns.Log.session
  if live and live.casts > 0 then
    Add(live.casts, live.catches, live.value, GetTime() - live.t0)
  end
  return total
end

local function Duration(seconds)
  seconds = math.floor(seconds + 0.5)
  local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
  if hours > 0 then return string.format(L["%dh %dm"], hours, minutes) end
  return string.format(L["%dm %ds"], minutes, seconds % 60)
end
Stats.Duration = Duration

local function Percent(part, whole)
  return whole > 0 and string.format("%d%%", math.floor(part / whole * 100 + 0.5)) or "-"
end

-- The zone with the most fish, from the catch log.
local function BestZone()
  local bestName, bestCount = nil, 0
  for mapID, zone in pairs(ns.chardb.log or {}) do
    local count = 0
    for _, entry in pairs(zone) do
      if type(entry) == "table" and entry.count then count = count + entry.count end
    end
    if count > bestCount then
      local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
      bestName, bestCount = info and info.name or tostring(mapID), count
    end
  end
  return bestName, bestCount
end

function Stats:Lines()
  local data = self:Data()
  local lines = {}
  local function Header(text) lines[#lines + 1] = { text = text, header = true } end
  local function Add(text) lines[#lines + 1] = { text = text } end

  if data.casts == 0 then
    Add(L["Nothing yet - statistics start with your first cast."])
    return lines
  end

  Header(L["Overall"])
  Add(string.format(L["Casts: %d"], data.casts))
  Add(string.format(L["Catches: %d  (%s of casts)"], data.catches, Percent(data.catches, data.casts)))
  Add(string.format(L["Misses: %d  (%s of casts)"], math.max(0, data.casts - data.catches),
    Percent(math.max(0, data.casts - data.catches), data.casts)))
  Add(string.format(L["Items caught: %d"], data.items))
  Add(string.format(L["Sessions: %d"], data.sessions))
  Add(string.format(L["Total value: %s"], Compat.CoinString(data.value)))
  Add(string.format(L["Fishing since: %s"], date("%Y-%m-%d", data.since)))

  Header(L["Time"])
  Add(string.format(L["Time fishing: %s"], Duration(data.seconds)))
  if data.castSeconds > 0 then
    Add(string.format(L["Line in the water: %s"], Duration(data.castSeconds)))
    Add(string.format(L["Average cast: %.1f seconds"], data.castSeconds / data.casts))
  end
  if data.sessions > 0 then
    Add(string.format(L["Average session: %s"], Duration(data.seconds / data.sessions)))
    Add(string.format(L["Longest session: %s"], Duration(data.longest)))
  end

  Header(L["Rates"])
  if data.seconds >= 60 then
    Add(string.format(L["Casts per hour: %.0f"], data.casts / data.seconds * 3600))
    Add(string.format(L["Catches per hour: %.0f"], data.catches / data.seconds * 3600))
    Add(string.format(L["Gold per hour: %s"], Compat.CoinString(data.value / data.seconds * 3600)))
  end
  if data.catches > 0 then
    Add(string.format(L["Value per catch: %s"], Compat.CoinString(data.value / data.catches)))
  end

  local rows = {}
  for quality = 0, 5 do
    local count = data.quality[quality]
    if count and count > 0 then
      rows[#rows + 1] = string.format("%s: %d  (%s)", QUALITY_NAMES[quality], count, Percent(count, data.items))
    end
  end
  if #rows > 0 then
    Header(L["Catches by quality"])
    for _, row in ipairs(rows) do Add(row) end
  end

  for _, span in ipairs({ { 1, L["Last 24 hours"] }, { 7, L["Last 7 days"] }, { 30, L["Last 30 days"] } }) do
    local w = self:Window(span[1])
    if w.casts > 0 then
      Header(span[2])
      Add(string.format(L["%d casts, %d catches (%s), %s, %s fishing"], w.casts, w.catches,
        Percent(w.catches, w.casts), Compat.CoinString(w.value), Duration(w.seconds)))
    end
  end

  local zones = {}
  for mapID, row in pairs(data.zones or {}) do
    if row.casts > 0 then
      local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
      zones[#zones + 1] = { name = info and info.name or L["Unknown zone"], casts = row.casts, catches = row.catches }
    end
  end
  table.sort(zones, function(a, b) return a.casts > b.casts end)
  if #zones > 0 then
    Header(L["By zone (most casts first)"])
    for index = 1, math.min(8, #zones) do
      local z = zones[index]
      Add(string.format(L["%s: %d casts, %d catches (%s)"], z.name, z.casts, z.catches, Percent(z.catches, z.casts)))
    end
  end

  local zone, count = BestZone()
  if zone then
    Header(L["Best zone"])
    Add(string.format(L["%s: %d fish"], zone, count))
  end
  return lines
end

-- The warband report: combined totals across every character on the
-- account, and a per-character breakdown. With only one character known,
-- the breakdown is skipped - it would just repeat the totals above it.
function Stats:AccountLines()
  local combined, list = self:AccountData()
  local lines = {}
  local function Header(text) lines[#lines + 1] = { text = text, header = true } end
  local function Add(text) lines[#lines + 1] = { text = text } end

  if combined.count == 0 then
    Add(L["Nothing yet - statistics start with your first cast."])
    return lines
  end

  Header(L["Warband totals"])
  Add(string.format(L["Characters tracked: %d"], combined.count))
  Add(string.format(L["Casts: %d"], combined.casts))
  Add(string.format(L["Catches: %d  (%s of casts)"], combined.catches, Percent(combined.catches, combined.casts)))
  Add(string.format(L["Items caught: %d"], combined.items))
  Add(string.format(L["Total value: %s"], Compat.CoinString(combined.value)))
  Add(string.format(L["Time fishing: %s"], Duration(combined.seconds)))

  if combined.count > 1 then
    Header(L["By character"])
    for _, entry in ipairs(list) do
      Add(string.format(L["%s-%s: %d casts, %d catches, %s, last played %s"], entry.name, entry.realm,
        entry.casts, entry.catches, Compat.CoinString(entry.value), date("%Y-%m-%d", entry.updated)))
    end
  end

  return lines
end

-- /tb stats
function Stats:Print()
  local data = self:Data()
  if data.casts == 0 then return end
  ns:Print(string.format(L["Lifetime: %d casts, %d catches (%s), %s fishing, %s."], data.casts, data.catches,
    Percent(data.catches, data.casts), Duration(data.seconds), Compat.CoinString(data.value)))
end
