-- The Briny Best tracker (Retail): each Midnight fish's Anglin' Score and catch rank, its zones and
-- where it bites best, Toxic Trophies and the Coiled Huntress's venom. Fish are read by BrinyJournal.lua.
-- Approach, fish IDs and rank cutoffs from BrinyBest, Copyright (c) 2026 Andrew Edmond, MIT License:
-- see Licenses/BrinyBest.txt.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data
if not Data.briny then return end

local Briny = ns:NewModule("Briny")
local Journal = ns.BrinyJournal

-- Seconds after a catch to re-read the journal: the new score can take a moment to show.
local RECHECKS = { 1.5, 4, 8 }
local RECENT_KEPT = 5

-- Rank from score, so it works in every language. Every fish shares these cutoffs; 75, 80 and 95
-- are BrinyBest's best fit to live data, and Trophy is exactly 100.
Briny.ranks = {
  { key = "guppy", label = L["Guppy"], from = 0, color = "9d9d9d" },
  { key = "minnow", label = L["Minnow"], from = 75, color = "1eff00" },
  { key = "pike", label = L["Pike"], from = 80, color = "0070dd" },
  { key = "shark", label = L["Shark"], from = 95, color = "a335ee" },
  { key = "trophy", label = L["Trophy"], from = 100, color = "ff8000" },
}

function Briny:Rank(score)
  local found = 1
  for index, rank in ipairs(self.ranks) do
    if score >= rank.from then found = index end
  end
  return found, self.ranks[found]
end

-- "Pike 78.3", in the rank's color.
function Briny:RankText(fish)
  local _, rank = self:Rank(fish.score)
  return string.format("|cff%s%s|r %.1f", rank.color, rank.label, fish.score)
end

-- "1.7 to Shark", or nil at Trophy.
function Briny:NextRankText(score)
  local index = self:Rank(score)
  local nextRank = self.ranks[index + 1]
  if not nextRank then return nil end
  return string.format(L["%.1f to %s"], nextRank.from - score, nextRank.label)
end

local BEST = {
  open = { L["open water"], "69ccf0" },
  pools = { L["pools"], "ffcc00" },
  poolsOnly = { L["pools only"], "ff7f3f" },
  either = { L["either"], "1eff00" },
}

-- "(pools) (lure)": where the fish bites best, and whether it has its own lure.
function Briny:Tags(fish)
  local tags = {}
  local best = BEST[fish.best]
  if best then tags[#tags + 1] = string.format("|cff%s(%s)|r", best[2], best[1]) end
  if Journal.lures[fish.id] then
    tags[#tags + 1] = string.format("|cffa335ee(%s)|r",
      Journal.lureRequired[fish.id] and L["lure needed"] or L["lure"])
  end
  return table.concat(tags, " ")
end

---------------------------------------------------------------------------
-- Reading the journal
---------------------------------------------------------------------------

local scan

function Briny:Invalidate()
  scan = nil
end

-- The game keeps serving a description's old text until asked to load it again, and the new score
-- can land after the loot window opens. So after a catch every fish is re-requested a few times (as
-- BrinyBest does); SPELL_TEXT_UPDATE re-reads when the text arrives, and each pass re-reads too.
local function RequestAll()
  if not (C_Spell and C_Spell.RequestLoadSpellData) then return end
  for _, spellID in ipairs(Data.briny.fish) do C_Spell.RequestLoadSpellData(spellID) end
end

local refreshQueued
function Briny:Refresh()
  if refreshQueued then return end
  refreshQueued = true
  for index, delay in ipairs(RECHECKS) do
    C_Timer.After(delay, function()
      if index == 1 then refreshQueued = nil end
      RequestAll()
      self:Invalidate()
      self:CheckRecent()
      ns.HUD:Refresh()
    end)
  end
end

-- Fish grouped by the zones the journal lists, each with its total and maximum (100 a fish).
local function Zones(fish)
  local zones, byKey = {}, {}
  for _, entry in ipairs(fish) do
    for _, area in ipairs(entry.areas) do
      local key = Journal.ZoneKey(area)
      local zone = byKey[key]
      if not zone then
        zone = { key = key, name = area, fish = {}, total = 0, trophies = 0 }
        byKey[key] = zone
        zones[#zones + 1] = zone
      end
      zone.fish[#zone.fish + 1] = entry
      zone.total = zone.total + entry.score
      if entry.score >= 100 then zone.trophies = zone.trophies + 1 end
    end
  end
  for _, zone in ipairs(zones) do
    zone.max = #zone.fish * 100
    table.sort(zone.fish, function(a, b)
      if a.score ~= b.score then return a.score < b.score end
      return a.name < b.name
    end)
  end
  table.sort(zones, function(a, b) return a.name < b.name end)
  return zones, byKey
end

-- { fish, byName, byID, zones, zoneByKey, pending }. Cached until something changes; fish still
-- loading are asked for and re-read next time.
function Briny:Scan()
  if scan and scan.pending == 0 then return scan end
  scan = { fish = {}, byName = {}, byID = {}, pending = 0 }
  for _, spellID in ipairs(Data.briny.fish) do
    local fish = Journal.Read(spellID)
    if fish then
      scan.fish[#scan.fish + 1] = fish
      scan.byName[fish.name] = fish
      scan.byID[spellID] = fish
    else
      scan.pending = scan.pending + 1
      if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellID) end
    end
  end
  scan.zones, scan.zoneByKey = Zones(scan.fish)
  return scan
end

-- The journal zone you're standing in, most specific name first, or nil outside Midnight.
function Briny:Here()
  local current = self:Scan()
  for _, key in ipairs(Journal.HereKeys()) do
    if current.zoneByKey[key] then return current.zoneByKey[key] end
  end
end

-- The achievement's own count. The call errors, rather than returning nil, when the client
-- can't find the criteria, so it's guarded.
local function CriteriaCount()
  local ok, _, _, _, quantity = pcall(GetAchievementCriteriaInfo, Data.briny.achievement, 1)
  if ok then return quantity end
end

-- The warband score: the achievement's own count, else the fish added up.
function Briny:Score()
  local quantity = CriteriaCount()
  if type(quantity) == "number" and not Compat.IsSecret(quantity) and quantity > 0 then return quantity end
  local total = 0
  for _, fish in ipairs(self:Scan().fish) do total = total + fish.score end
  return math.floor(total)
end

local function AchievementDone(achievementID)
  local ok, _, _, _, completed = pcall(GetAchievementInfo, achievementID)
  return ok and completed == true
end

-- Toxic Trophies: how many of its eight fish are at Trophy, and the names of the rest.
function Briny:Toxic()
  local byID, done, missing = self:Scan().byID, 0, {}
  for _, spellID in ipairs(Data.briny.toxic.fish) do
    local fish = byID[spellID]
    if fish and fish.score >= 100 then
      done = done + 1
    elseif fish then
      missing[#missing + 1] = fish
    end
  end
  table.sort(missing, function(a, b) return a.score > b.score end)
  return done, #Data.briny.toxic.fish, missing, AchievementDone(Data.briny.toxic.achievement)
end

-- The Coiled Huntress's stored venom, read from its tooltip; nil when it isn't in the fishing tool
-- slot or no line mentions venom. English clients only.
function Briny:Venom()
  local huntress = Data.briny.huntress
  if GetInventoryItemID("player", huntress.slot) ~= huntress.itemID then return nil end
  local data = C_TooltipInfo and C_TooltipInfo.GetInventoryItem("player", huntress.slot)
  if not data or Compat.IsSecret(data) or type(data.lines) ~= "table" then return nil end
  for _, line in ipairs(data.lines) do
    local text = line.leftText
    if type(text) == "string" and not Compat.IsSecret(text) and text:lower():find(huntress.venomWord, 1, true) then
      local number = text:match("(%d[%d,]*)")
      if number then return tonumber((number:gsub(",", ""))) end
    end
  end
end

---------------------------------------------------------------------------
-- Turning it on, and following catches
---------------------------------------------------------------------------

-- On adds the Briny tab to the Fishing Companion and opens it; off removes the tab.
function Briny:SetEnabled(on)
  ns.db.briny.enabled = on and true or false
  if on then
    self:Invalidate()
    self:Scan()
    if not ns.HUD:SetTab("briny", true) then
      ns:Print(L["The Fishing Companion is full. Remove a tab with /tb tabs to add the Briny tab."])
    else
      ns.db.hud.tab = "briny"
    end
  else
    ns.HUD:SetTab("briny", false)
    self.recent = {}
  end
  ns.HUD:Refresh()
end

-- Journal fish caught this session, newest first, one entry per fish: its score at the first catch
-- ("before", for the points gained) and now, once the journal catches up.
Briny.recent = {}

function Briny:CheckRecent()
  local byName = self:Scan().byName
  for _, entry in ipairs(self.recent) do
    local fish = byName[entry.name]
    if fish then
      entry.score = fish.score
      local rank, info = self:Rank(fish.score)
      if rank > entry.rankBefore and not entry.alerted then
        entry.alerted = true
        if info.key == "trophy" then
          ns.Alerts:Fire("briny", string.format(L["Trophy! %s is maxed at 100 on the Briny Best."], fish.name))
        else
          ns.Alerts:Fire("briny", string.format(L["%s reached %s rank on the Briny Best."], fish.name, info.label))
        end
      end
    end
  end
end

-- Moves the fish to the front, keeping its session start score.
local function Remember(fish)
  local recent, entry = Briny.recent, nil
  for index = #recent, 1, -1 do
    if recent[index].name == fish.name then entry = table.remove(recent, index) end
  end
  entry = entry or { name = fish.name, before = fish.score }
  entry.score, entry.rankBefore, entry.alerted = fish.score, (Briny:Rank(fish.score)), nil
  table.insert(recent, 1, entry)
  recent[RECENT_KEPT + 1] = nil
end

ns:On("CAST_LOOTED", function(looted)
  if not ns.db.briny.enabled then return end
  local byName = Briny:Scan().byName
  for itemID in pairs(looted) do
    local name = Compat.GetItemInfo(itemID)
    local fish = name and byName[name]
    if fish then Remember(fish) end
  end
  Briny:Refresh()
end)

ns:On("SESSION_START", function() Briny.recent = {} end)

-- Fires in bursts as a catch counts toward the achievement.
ns:OnModeEvent("CRITERIA_UPDATE", function()
  if ns.db.briny.enabled then Briny:Refresh() end
end)

-- The journal text changed (a score moved, or a description finished loading).
ns:OnModeEvent("SPELL_TEXT_UPDATE", function()
  if not ns.db.briny.enabled then return end
  Briny:Invalidate()
  Briny:CheckRecent()
  ns.HUD:Refresh()
end)

function Briny:Enable()
  if ns.db.briny.enabled then
    self:Invalidate()
    self:Scan()
  end
end

---------------------------------------------------------------------------
-- Text for the Fishing Companion tab, its tooltips and the Goals compartment
---------------------------------------------------------------------------

function Briny:ScoreText()
  local score, target = self:Score(), Data.briny.target
  if AchievementDone(Data.briny.achievement) or score >= target then
    return string.format("|cff1eff00%d / %d|r", score, target)
  end
  return string.format("%d / %d", score, target)
end

-- "412.3 / 600", green when every fish here is at Trophy.
function Briny:ZoneText(zone)
  local color = zone.total >= zone.max and "1eff00" or "ffffff"
  return string.format("|cff%s%.1f / %d|r", color, zone.total, zone.max)
end

-- "Pike 81.0 +2.7": a recent catch's rank and score, and the points it gained this session.
function Briny:RecentText(entry)
  local text = self:RankText({ score = entry.score })
  local gained = entry.score - entry.before
  if gained > 0.05 then text = text .. string.format(" |cff1eff00+%.1f|r", gained) end
  return text
end

-- A fish's rank progress, where it bites best, its pools and zones.
function Briny:FillTooltip(tooltip, name)
  local fish = self:Scan().byName[name]
  if not fish then return end
  tooltip:AddLine(fish.name)
  tooltip:AddDoubleLine(L["Anglin' Score"], self:RankText(fish), 1, 1, 1, 1, 1, 1)
  local nextRank = self:NextRankText(fish.score)
  tooltip:AddLine(nextRank or L["Trophy rank: nothing left to earn."], 0.8, 0.8, 0.8)
  local tags = self:Tags(fish)
  if tags ~= "" then tooltip:AddDoubleLine(L["Bites best in"], tags, 1, 1, 1) end
  if #fish.pools > 0 then
    tooltip:AddLine(string.format(L["Pools: %s"], table.concat(fish.pools, ", ")), 0.7, 0.7, 0.7, true)
  end
  if #fish.areas > 0 then
    tooltip:AddLine(string.format(L["Zones: %s"], table.concat(fish.areas, ", ")), 0.7, 0.7, 0.7, true)
  end
end

-- One fish on a Goals line: rank, score, what's left to the next rank, and tags.
local function FishLine(fish)
  local nextRank = Briny:NextRankText(fish.score)
  return string.format("   %s  %s%s  %s", fish.name, Briny:RankText(fish),
    nextRank and ("  |cff808080" .. nextRank .. "|r") or "", Briny:Tags(fish))
end

-- /tb briny: what the tracker read, for checking it against the journal in game.
function Briny:Diagnose()
  local current = self:Scan()
  local quantity = CriteriaCount()
  ns:Print(string.format("Briny: tracking %s, %d fish read, %d loading, %d zones, achievement count %s, score %s",
    tostring(ns.db.briny.enabled), #current.fish, current.pending, #current.zones, tostring(quantity),
    self:ScoreText()))
  local here = self:Here()
  print("   here: " .. (here and (here.name .. " " .. self:ZoneText(here)) or "no Midnight zone")
    .. "  (" .. table.concat(Journal.HereKeys(), " / ") .. ")")
  print("   venom: " .. tostring(self:Venom()))
  for _, entry in ipairs(self.recent) do
    print(string.format("   caught: %s %.1f -> %.1f", entry.name, entry.before, entry.score))
  end
end

function Briny:Lines()
  local lines = { { text = string.format(L["The Briny Best: %s Anglin' Score"], self:ScoreText()), header = true } }
  local current = self:Scan()
  if #current.fish == 0 then
    lines[#lines + 1] = { text = L["Reading the Fishing Journal... open it once if this stays empty."] }
    return lines
  end

  local trophies = 0
  for _, fish in ipairs(current.fish) do
    if fish.score >= 100 then trophies = trophies + 1 end
  end
  lines[#lines + 1] = { text = string.format(L["%d of %d fish at Trophy rank."], trophies, #current.fish) }

  local done, total, missing, earned = self:Toxic()
  local names = {}
  for _, fish in ipairs(missing) do names[#names + 1] = string.format("%s %.1f", fish.name, fish.score) end
  lines[#lines + 1] = { text = earned and string.format("|cff1eff00" .. L["Toxic Trophies: earned."] .. "|r")
    or string.format(L["Toxic Trophies: %d of %d at Trophy. Still to go: %s"], done, total, table.concat(names, ", ")) }

  local venom = self:Venom()
  if venom then lines[#lines + 1] = { text = string.format(L["Coiled Huntress venom: %d"], venom) } end
  if current.pending > 0 then
    lines[#lines + 1] = { text = string.format(L["%d fish still loading from the journal."], current.pending) }
  end

  -- This zone first, then the rest; each zone's fish lowest score first, the most to gain on top.
  local here = self:Here()
  local zones = {}
  if here then zones[1] = here end
  for _, zone in ipairs(current.zones) do
    if zone ~= here then zones[#zones + 1] = zone end
  end
  for _, zone in ipairs(zones) do
    lines[#lines + 1] = { text = " " }
    lines[#lines + 1] = { header = true, text = string.format("%s%s  %s  |cff808080(%d Trophy)|r",
      zone == here and (L["Here: "]) or "", zone.name, self:ZoneText(zone), zone.trophies) }
    for _, fish in ipairs(zone.fish) do
      if fish.score < 100 then lines[#lines + 1] = { text = FishLine(fish) } end
    end
  end
  return lines
end
