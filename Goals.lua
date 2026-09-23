-- Collections Tracker (/tb goals): unfinished Fishing-category achievements,
-- read live so no ID list goes stale, plus the fishing mounts.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Goals = {}
ns.Goals = Goals

local FISHING_CATEGORY = 171
local MAX_LINES = 15
local DETAILED = 4      -- achievements that get their missing parts listed
local MAX_MISSING = 6
local GAPS_KEPT = 8

local function FishingCategory()
  if not GetCategoryInfo then return nil end
  local wanted = PROFESSIONS_FISHING or "Fishing"
  if GetCategoryInfo(FISHING_CATEGORY) == wanted then return FISHING_CATEGORY end
  for _, categoryID in ipairs(GetCategoryList() or {}) do
    if GetCategoryInfo(categoryID) == wanted then return categoryID end
  end
end

-- "412/1000" for a counted goal, "3/7" for a checklist; third return is the missing parts.
local function Progress(achievementID)
  local total = GetAchievementNumCriteria(achievementID) or 0
  local done, missing = 0, {}
  for index = 1, total do
    local text, _, completed, quantity, required = GetAchievementCriteriaInfo(achievementID, index)
    if total == 1 and required and required > 1 then
      return quantity / required, string.format("%d/%d", quantity, required), missing
    end
    if completed then
      done = done + 1
    elseif text and text ~= "" then
      missing[#missing + 1] = text
    end
  end
  if total == 0 then return 0, "", missing end
  return done / total, string.format("%d/%d", done, total), missing
end

---------------------------------------------------------------------------
-- Attempt counters, in the style of Rarity.
---------------------------------------------------------------------------

local function Continent(mapID)
  local guard = 0
  while mapID and mapID > 0 and guard < 10 do
    local info = C_Map.GetMapInfo(mapID)
    if not info then return nil end
    if info.mapType == (Enum.UIMapType and Enum.UIMapType.Continent or 2) then return mapID end
    mapID, guard = info.parentMapID, guard + 1
  end
end

local function InScope(drop, looted, pool)
  if drop.poolOnly and not pool then return false end
  if drop.fishRange then
    for itemID in pairs(looted) do
      if itemID >= drop.fishRange[1] and itemID <= drop.fishRange[2] then return true end
    end
    return false
  end
  if drop.continent then
    local mapID = C_Map and C_Map.GetBestMapForUnit("player")
    return mapID ~= nil and Continent(mapID) == drop.continent
  end
  return true
end

local function Collected(drop)
  if not C_MountJournal then return false end
  local mountID = drop.mountSpell and C_MountJournal.GetMountFromSpell(drop.mountSpell)
    or drop.mountItem and C_MountJournal.GetMountFromItem(drop.mountItem)
  if not mountID then return false end
  local _, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(mountID)
  return collected and true or false
end

---------------------------------------------------------------------------
-- Skill-ups: catches per point, learned from your own skill gains.
---------------------------------------------------------------------------

local function FishingSkill()
  if GetProfessions then
    local _, _, _, fishing = GetProfessions()
    if not fishing then return nil end
    local _, _, level, max = GetProfessionInfo(fishing)
    return level, max
  end
  if GetNumSkillLines then -- Classic Era
    local wanted = Compat.FishingName()
    for index = 1, GetNumSkillLines() do
      local name, isHeader, _, level, _, _, max = GetSkillLineInfo(index)
      if not isHeader and name == wanted then return level, max end
    end
  end
end

ns:On("CAST_LOOTED", function(looted, pool)
  local attempts = ns.chardb.attempts
  for _, drop in ipairs(Data.rareDrops) do
    local counter = attempts[drop.key] or { n = 0 }
    attempts[drop.key] = counter
    if not counter.found and InScope(drop, looted, pool) then
      counter.n = counter.n + 1
      if looted[drop.item] then
        counter.found = counter.n
        ns:Print(string.format(L["%s after %d attempts!"], drop.name, counter.n))
      end
    end
  end

  local level = FishingSkill()
  if not level then return end
  local skill = ns.chardb.skill
  skill.since = (skill.since or 0) + 1
  if skill.level and level > skill.level then
    skill.gaps = skill.gaps or {}
    table.insert(skill.gaps, skill.since / (level - skill.level))
    while #skill.gaps > GAPS_KEPT do table.remove(skill.gaps, 1) end
    skill.since = 0
  end
  skill.level = level
end)

local function AttemptLines(lines)
  local shown = false
  for _, drop in ipairs(Data.rareDrops) do
    local counter = ns.chardb.attempts[drop.key]
    if counter and counter.n > 0 and not Collected(drop) then
      if not shown then
        lines[#lines + 1] = { text = L["Rare drops you are fishing for:"], header = true }
        shown = true
      end
      local text
      if counter.found then
        text = string.format(L["%s - found after %d attempts"], drop.name, counter.found)
      elseif drop.chance then
        local seen = 1 - (1 - drop.chance) ^ counter.n
        text = string.format(L["%s - %d attempts (about %d%% of anglers have it by now)"],
          drop.name, counter.n, math.floor(seen * 100 + 0.5))
      else
        text = string.format(L["%s - %d attempts"], drop.name, counter.n)
      end
      if drop.poolOnly then text = text .. "  |cff808080" .. L["(pool catches only)"] .. "|r" end
      lines[#lines + 1] = { text = text }
    end
  end
end

local function SkillLines(lines)
  local level, max = FishingSkill()
  if not level or not max or max == 0 then return end
  local text = string.format(L["Fishing skill: %d/%d"], level, max)
  local gaps = ns.chardb.skill.gaps
  if level < max and gaps and #gaps > 0 then
    local sum = 0
    for _, gap in ipairs(gaps) do sum = sum + gap end
    local perPoint = sum / #gaps
    text = text .. string.format(L[" - about %.1f catches per point"], perPoint)
    local stats = ns.Log:Stats()
    if stats and stats.catches > 0 and stats.elapsed > 0 then
      local seconds = (max - level) * perPoint * (stats.elapsed / stats.catches)
      text = text .. string.format(L[", roughly %dh %dm to the cap at this pace"],
        math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
    end
  end
  lines[#lines + 1] = { text = text, header = true }
end

-- Hallowfall derby: trophy fish still needed and where your log saw each.
function Goals:DerbyLines(lines)
  if not C_QuestLog or not C_QuestLog.IsOnQuest then return end
  for _, questID in ipairs(Data.derbyQuests) do
    if C_QuestLog.IsOnQuest(questID) then
      lines[#lines + 1] = { text = L["Hallowfall Fishing Derby - still to catch:"], header = true }
      local fish = ns.Journal:Fish()
      for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        if not objective.finished and objective.text then
          local text = objective.text
          for _, known in ipairs(fish) do
            if text:find(known.name, 1, true) and known.zones[1] then
              local info = C_Map.GetMapInfo(known.zones[1].mapID)
              text = text .. "  |cff808080" .. string.format(L["(you catch it in %s)"],
                info and info.name or "?") .. "|r"
              break
            end
          end
          lines[#lines + 1] = { text = text }
        end
      end
      return
    end
  end
end

local function MountLines(lines)
  if not C_MountJournal or #Data.mounts == 0 then return end
  local missing, total = {}, 0
  for _, mount in ipairs(Data.mounts) do
    local mountID = mount.spell and C_MountJournal.GetMountFromSpell(mount.spell)
      or mount.item and C_MountJournal.GetMountFromItem(mount.item)
    if mountID then
      total = total + 1
      local name, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(mountID)
      if not collected then missing[#missing + 1] = name end
    end
  end
  if total == 0 then return end
  lines[#lines + 1] = { text = string.format(L["Fishing mounts: %d of %d collected."], total - #missing, total),
    header = true }
  for _, name in ipairs(missing) do lines[#lines + 1] = { text = name } end
end

-- The parts that change while you fish, for the session window's tab.
function Goals:ShortLines()
  local lines = {}
  self:DerbyLines(lines)
  SkillLines(lines)
  AttemptLines(lines)
  if #lines == 0 then lines[1] = { text = L["Nothing tracked yet - keep fishing."] } end
  return lines
end

function Goals:Lines()
  local lines = {}
  self:DerbyLines(lines)
  SkillLines(lines)
  AttemptLines(lines)
  MountLines(lines)
  local categoryID = FishingCategory()
  if not categoryID then
    lines[#lines + 1] = { text = L["No fishing achievements on this game version."], header = true }
    return lines
  end

  local rows, finished, count = {}, 0, GetCategoryNumAchievements(categoryID) or 0
  for index = 1, count do
    local achievementID, name, _, completed = GetAchievementInfo(categoryID, index)
    if achievementID then
      if completed then
        finished = finished + 1
      else
        local fraction, text, missing = Progress(achievementID)
        rows[#rows + 1] = { id = achievementID, name = name, fraction = fraction, text = text,
          missing = missing }
      end
    end
  end

  table.sort(rows, function(a, b)
    if a.fraction ~= b.fraction then return a.fraction > b.fraction end
    return a.name < b.name
  end)

  lines[#lines + 1] = { text = string.format(L["Fishing achievements: %d of %d done."], finished, finished + #rows),
    header = true }
  for i = 1, math.min(MAX_LINES, #rows) do
    local row = rows[i]
    local link = GetAchievementLink and GetAchievementLink(row.id) or row.name
    lines[#lines + 1] = { text = string.format("%s  |cffffd100%s|r", link, row.text) }
    if i <= DETAILED and #row.missing > 0 then
      local parts = {}
      for index = 1, math.min(MAX_MISSING, #row.missing) do parts[index] = row.missing[index] end
      if #row.missing > MAX_MISSING then
        parts[#parts + 1] = string.format(L["+%d more"], #row.missing - MAX_MISSING)
      end
      lines[#lines + 1] = { text = "   |cff808080" .. L["Missing:"] .. " " .. table.concat(parts, ", ") .. "|r" }
    end
  end
  if #rows > MAX_LINES then
    lines[#lines + 1] = { text = string.format(L["...and %d more."], #rows - MAX_LINES) }
  end
  return lines
end

function Goals:Print()
  ns:PrintLines(self:Lines())
end
