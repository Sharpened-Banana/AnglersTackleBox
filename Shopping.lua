-- Shopping List: fish you've caught that a Cooking recipe wants as a
-- reagent, how many you're holding, and roughly how many more casts it
-- takes to fill the gap at your own catch rate.
--
-- Scope: Cooking only for v1. Other professions (Alchemy, Enchanting) do
-- occasionally take a fish, but which ones varies by expansion and we have
-- no reliable static list to cross-check against, so guessing IDs would be
-- worse than saying nothing. The trade skill window itself is scanned
-- instead of a hard-coded recipe/reagent table, so this stays correct as
-- recipes come and go - it just needs the Cooking window opened once.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Shopping = {}
ns.Shopping = Shopping

-- Reagent uses from the last time a trade skill window was open, keyed by
-- itemID. nil until the player has opened one this session.
local cache

local function Rebuild()
  if not Compat.IsCookingWindowOpen() then return end
  cache = Compat.TradeSkillReagentUses()
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("TRADE_SKILL_SHOW")
watcher:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
watcher:SetScript("OnEvent", Rebuild)

-- Rows: one per fish that is both a known Cooking reagent and something the
-- player has actually caught, worst shortfall first.
local function Rows()
  local rows = {}
  if not cache then return rows end

  local byID = {}
  for _, entry in ipairs(ns.Journal:Fish()) do byID[entry.id] = entry end

  for itemID, uses in pairs(cache) do
    local fish = byID[itemID]
    if fish then
      local needed = 0
      for _, use in ipairs(uses) do needed = math.max(needed, use.need) end
      local held = Compat.GetItemCount(itemID)
      rows[#rows + 1] = {
        id = itemID, name = fish.name, caught = fish.total,
        uses = uses, needed = needed, held = held, short = math.max(0, needed - held),
      }
    end
  end

  table.sort(rows, function(a, b)
    if a.short ~= b.short then return a.short > b.short end
    return a.name < b.name
  end)
  return rows
end

-- Casts still needed to close the gap, from lifetime casts vs. lifetime
-- catches of this fish (Stats/Journal). nil when there isn't enough data
-- to estimate a rate.
local function CastsNeeded(row)
  if row.short <= 0 or row.caught <= 0 then return nil end
  local stats = ns.Stats and ns.Stats:Data()
  local totalCasts = stats and stats.casts or 0
  if totalCasts <= 0 then return nil end
  local perCast = row.caught / totalCasts
  if perCast <= 0 then return nil end
  return math.ceil(row.short / perCast)
end

function Shopping:Lines()
  local lines = {}
  if not cache then
    lines[1] = { text = L["Open your Cooking profession window once and this list fills in."] }
    return lines
  end

  local rows = Rows()
  if #rows == 0 then
    lines[1] = { text = L["Nothing in your known Cooking recipes needs a fish you've caught."] }
    return lines
  end

  lines[#lines + 1] = { text = L["Cooking reagents you've fished up before:"], header = true }
  for _, row in ipairs(rows) do
    local recipeNames = {}
    for _, use in ipairs(row.uses) do recipeNames[#recipeNames + 1] = use.recipe end
    lines[#lines + 1] = { text = string.format(L["%s - have %d, %d recipes want %d: %s"],
      row.name, row.held, #row.uses, row.needed, table.concat(recipeNames, ", ")) }
    if row.short > 0 then
      local text = string.format(L["Need %d more."], row.short)
      local casts = CastsNeeded(row)
      if casts then
        text = text .. "  " .. string.format(L["About %d more casts at your rate."], casts)
      end
      lines[#lines + 1] = { text = "   |cff808080" .. text .. "|r" }
    end
  end
  return lines
end

-- Menu.lua calls this once, when the compartment is first built, so a
-- window already open before /tb menu is used still counts.
function Shopping:Refresh()
  Rebuild()
end
