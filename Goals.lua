-- Collections Tracker: progress on every unfinished achievement in the
-- game's own Fishing category (read live, so no ID list can go stale), plus
-- the fishing mounts. Runs only when asked (/tb goals).
local _, ns = ...
local L, Data = ns.L, ns.Data

local Goals = {}
ns.Goals = Goals

local FISHING_CATEGORY = 171
local MAX_LINES = 15

local function FishingCategory()
  if not GetCategoryInfo then return nil end
  local wanted = PROFESSIONS_FISHING or "Fishing"
  if GetCategoryInfo(FISHING_CATEGORY) == wanted then return FISHING_CATEGORY end
  for _, categoryID in ipairs(GetCategoryList() or {}) do
    if GetCategoryInfo(categoryID) == wanted then return categoryID end
  end
end

-- "412/1000" for a counted goal, "3/7" parts done for a checklist.
local function Progress(achievementID)
  local total = GetAchievementNumCriteria(achievementID) or 0
  local done = 0
  for index = 1, total do
    local _, _, completed, quantity, required = GetAchievementCriteriaInfo(achievementID, index)
    if total == 1 and required and required > 1 then
      return quantity / required, string.format("%d/%d", quantity, required)
    end
    if completed then done = done + 1 end
  end
  if total == 0 then return 0, "" end
  return done / total, string.format("%d/%d", done, total)
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

function Goals:Lines()
  local lines = {}
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
        local fraction, text = Progress(achievementID)
        rows[#rows + 1] = { id = achievementID, name = name, fraction = fraction, text = text }
      end
    end
  end

  -- Closest to done first.
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
  end
  if #rows > MAX_LINES then
    lines[#lines + 1] = { text = string.format(L["...and %d more."], #rows - MAX_LINES) }
  end
  return lines
end

function Goals:Print()
  ns:PrintLines(self:Lines())
end
