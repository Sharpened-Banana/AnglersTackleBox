-- The Briny Best tracker (Retail): each Midnight fish's Anglin' Score and catch rank, read live from
-- the Fishing Journal's recipe descriptions. Approach, fish IDs, score labels and rank cutoffs from
-- BrinyBest, Copyright (c) 2026 Andrew Edmond, MIT License: see Licenses/BrinyBest.txt.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data
if not Data.briny then return end

local Briny = ns:NewModule("Briny")

local RECHECK = 1.5 -- seconds after a catch before the journal shows the new score

-- "Anglin' Score" as each client language writes it; unknown languages try English.
local SCORE_LABELS = {
  enUS = "Anglin' Score", enGB = "Anglin' Score", deDE = "Angelwertung", esES = "Puntuación de pesca",
  esMX = "Puntaje de pesca", frFR = "Score de pêche", itIT = "Punteggio di Pesca", koKR = "강태공 점수",
  ptBR = "Pontuação de pescaria", ruRU = "Счет рыбалки", zhCN = "钓鱼得分", zhTW = "釣魚分數",
}
local SCORE_LABEL = SCORE_LABELS[GetLocale()] or SCORE_LABELS.enUS

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

---------------------------------------------------------------------------
-- Reading the journal
---------------------------------------------------------------------------

local function StripCodes(text)
  return (text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    :gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

-- Nil while the description, or the number in it, hasn't loaded yet.
local function ReadScore(spellID)
  local describe = C_Spell and C_Spell.GetSpellDescription
  local text = describe and describe(spellID)
  if not text or text == "" or Compat.IsSecret(text) then return nil end
  text = StripCodes(text)
  local _, labelEnd = text:find(SCORE_LABEL, 1, true)
  if not labelEnd then return nil end
  -- Skip the colon (" : " in French, fullwidth in Chinese) without crossing onto the next line.
  local raw = text:match("^[^%d\r\n]*([%d%.,]+)", labelEnd + 1)
  return raw and tonumber((raw:gsub(",", "."):gsub("%.+$", "")))
end

local scan

function Briny:Invalidate()
  scan = nil
end

-- { fish = { { id, name, score } }, byName = {}, pending = n }. Cached until something changes;
-- fish still loading are asked for and re-read next time.
function Briny:Scan()
  if scan and scan.pending == 0 then return scan end
  scan = { fish = {}, byName = {}, pending = 0 }
  for _, spellID in ipairs(Data.briny.fish) do
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    local score = ReadScore(spellID)
    if name and score then
      local fish = { id = spellID, name = name, score = score }
      scan.fish[#scan.fish + 1] = fish
      scan.byName[name] = fish
    else
      scan.pending = scan.pending + 1
      if C_Spell and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellID) end
    end
  end
  return scan
end

-- The warband score: the achievement's own count, else the fish added up.
function Briny:Score()
  local _, _, _, quantity = GetAchievementCriteriaInfo(Data.briny.achievement, 1)
  if type(quantity) == "number" and not Compat.IsSecret(quantity) and quantity > 0 then return quantity end
  local total = 0
  for _, fish in ipairs(self:Scan().fish) do total = total + fish.score end
  return math.floor(total)
end

function Briny:Done()
  local _, _, _, completed = GetAchievementInfo(Data.briny.achievement)
  return completed == true
end

-- Fish sorted lowest score first: the most points still to gain. mapID limits it to fish in your
-- catch log for that zone.
function Briny:Lowest(mapID)
  local list, fish = {}, self:Scan().fish
  local zone = mapID and ns.chardb.log[mapID]
  for _, entry in ipairs(fish) do
    local caughtHere = false
    if zone then
      for _, logged in pairs(zone) do
        if logged.name == entry.name then caughtHere = true end
      end
    end
    if (not zone or caughtHere) and entry.score < 100 then list[#list + 1] = entry end
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score < b.score end
    return a.name < b.name
  end)
  return list
end

---------------------------------------------------------------------------
-- Turning it on, and following catches
---------------------------------------------------------------------------

-- On adds the Briny tab to the session window and opens it; off removes the tab.
function Briny:SetEnabled(on)
  ns.db.briny.enabled = on and true or false
  if on then
    self:Invalidate()
    self:Scan()
    if not ns.HUD:SetTab("briny", true) then
      ns:Print(L["The session window is full. Remove a tab with /tb tabs to add the Briny tab."])
    else
      ns.db.hud.tab = "briny"
    end
  else
    ns.HUD:SetTab("briny", false)
    self.last = nil
  end
  ns.HUD:Refresh()
end

-- The last journal fish caught: its score before, and after once the journal catches up.
function Briny:CheckLast()
  local last = self.last
  if not last then return end
  local fish = self:Scan().byName[last.name]
  if not fish then return end
  last.score = fish.score
  local rank, info = self:Rank(fish.score)
  if rank > last.rankBefore and not last.alerted then
    last.alerted = true
    ns.Alerts:Fire("briny", string.format(L["%s reached %s rank on the Briny Best."], fish.name, info.label))
  end
end

ns:On("CAST_LOOTED", function(looted)
  if not ns.db.briny.enabled then return end
  local byName = Briny:Scan().byName
  for itemID in pairs(looted) do
    local name = Compat.GetItemInfo(itemID)
    local fish = name and byName[name]
    if fish then
      Briny.last = { name = fish.name, before = fish.score, score = fish.score, rankBefore = (Briny:Rank(fish.score)) }
      Briny:Invalidate()
      C_Timer.After(RECHECK, function()
        Briny:Invalidate()
        Briny:CheckLast()
        ns.HUD:Refresh()
      end)
    end
  end
end)

-- The journal text changed (a score moved, or a description finished loading).
ns:OnModeEvent("SPELL_TEXT_UPDATE", function()
  if not ns.db.briny.enabled then return end
  Briny:Invalidate()
  Briny:CheckLast()
end)

function Briny:Enable()
  if ns.db.briny.enabled then
    self:Invalidate()
    self:Scan()
  end
end

---------------------------------------------------------------------------
-- Text for the session window tab and the Goals compartment
---------------------------------------------------------------------------

function Briny:ScoreText()
  local score, target = self:Score(), Data.briny.target
  if self:Done() or score >= target then
    return string.format("|cff1eff00%d / %d|r", score, target)
  end
  return string.format("%d / %d", score, target)
end

function Briny:LastText()
  local last = self.last
  if not last then return nil end
  local gained = (last.score or last.before) - last.before
  local text = self:RankText({ score = last.score or last.before })
  if gained > 0.05 then text = text .. string.format(" |cff1eff00+%.1f|r", gained) end
  return last.name, text
end

function Briny:Lines()
  local lines = { { text = string.format(L["The Briny Best: %s Anglin' Score"], self:ScoreText()), header = true } }
  local current = self:Scan()
  if #current.fish == 0 then
    lines[#lines + 1] = { text = L["Reading the Fishing Journal... open it once if this stays empty."] }
    return lines
  end
  local lowest = self:Lowest()
  local trophies = #current.fish - #lowest
  lines[#lines + 1] = { text = string.format(L["%d of %d fish at Trophy rank. Lowest scores first:"],
    trophies, #current.fish) }
  for _, fish in ipairs(lowest) do
    lines[#lines + 1] = { text = string.format("   %s  %s", fish.name, self:RankText(fish)) }
  end
  if current.pending > 0 then
    lines[#lines + 1] = { text = string.format(L["%d fish still loading from the journal."], current.pending) }
  end
  return lines
end
