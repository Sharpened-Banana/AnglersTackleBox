-- Fishing journal: one page per fish, built from the catch log. Answers
-- "where do I catch this?" with your own zones, subzones, pools and rates.
local _, ns = ...
local L = ns.L

local Journal = {}
ns.Journal = Journal

local function MapName(mapID)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or string.format(L["Map %d"], mapID)
end

-- Every fish ever logged, most caught first.
function Journal:Fish()
  local byItem = {}
  for mapID, zone in pairs(ns.chardb.log) do
    local total = 0
    for _, entry in pairs(zone) do total = total + entry.count end
    for itemID, entry in pairs(zone) do
      local fish = byItem[itemID]
      if not fish then
        fish = { id = itemID, name = entry.name or ("item:" .. itemID), total = 0, zones = {} }
        byItem[itemID] = fish
      end
      fish.total = fish.total + entry.count
      if entry.first and (not fish.first or entry.first < fish.first) then fish.first = entry.first end
      if entry.last and (not fish.last or entry.last > fish.last) then fish.last = entry.last end
      fish.zones[#fish.zones + 1] = { mapID = mapID, entry = entry, share = entry.count / total }
    end
  end
  local list = {}
  for _, fish in pairs(byItem) do
    table.sort(fish.zones, function(a, b) return a.share > b.share end)
    list[#list + 1] = fish
  end
  table.sort(list, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.name < b.name
  end)
  return list
end

local function Counted(tbl)
  local parts = {}
  for name, count in pairs(tbl) do parts[#parts + 1] = { name = name, count = count } end
  table.sort(parts, function(a, b) return a.count > b.count end)
  local out = {}
  for index = 1, math.min(4, #parts) do
    out[index] = string.format("%s %d", parts[index].name, parts[index].count)
  end
  return table.concat(out, ", ")
end

-- The page for one fish.
function Journal:Page(fish)
  local lines = { { text = fish.name, header = true } }
  local function Add(text) lines[#lines + 1] = { text = text } end
  Add(string.format(L["Caught %d in total, worth %s each right now."], fish.total,
    ns.Compat.CoinString(ns.Log.UnitValue(fish.id))))
  if fish.first then
    Add(string.format(L["First catch %s, latest %s."], date("%Y-%m-%d", fish.first), date("%Y-%m-%d", fish.last)))
  end
  lines[#lines + 1] = { text = L["Where you catch it (share of that zone's catch):"], header = true }
  for _, zone in ipairs(fish.zones) do
    Add(string.format("%s - %d  (%.1f%%)", MapName(zone.mapID), zone.entry.count, zone.share * 100))
    if zone.entry.subs and next(zone.entry.subs) then
      Add("   |cff808080" .. Counted(zone.entry.subs) .. "|r")
    end
    if zone.entry.pools then
      Add("   |cff808080" .. L["Pools:"] .. " " .. Counted(zone.entry.pools) .. "|r")
    end
  end
  return lines
end

-- /tb find <text>
function Journal:Find(text)
  local needle = text:lower()
  local lines, found = {}, 0
  for _, fish in ipairs(self:Fish()) do
    if fish.name:lower():find(needle, 1, true) then
      found = found + 1
      if found <= 3 then
        for _, line in ipairs(self:Page(fish)) do lines[#lines + 1] = line end
      end
    end
  end
  if found == 0 then
    lines[1] = { text = string.format(L["You haven't caught anything matching \"%s\" yet."], text), header = true }
  elseif found > 3 then
    lines[#lines + 1] = { text = string.format(L["...and %d more matches. The Journal lists them all."], found - 3) }
  end
  return lines
end
