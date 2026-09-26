-- Shopping List: caught fish that Cooking recipes use, how many you hold, and casts to fill the gap.
-- Cooking only: other professions' fish vary by expansion with no reliable list, and guessed
-- IDs are worse than nothing. Recipes come from the open window, not a hard-coded table.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Shopping = {}
ns.Shopping = Shopping

-- Reagent uses by itemID from the last Cooking scan, saved per character so it survives
-- a reload; nil until the Cooking window has been opened once.
local cache

local function Saved()
  if not cache and ns.chardb then cache = ns.chardb.cookingReagents end
  return cache
end

local function Rebuild()
  if not Compat.IsCookingWindowOpen() then return end
  local uses = Compat.TradeSkillReagentUses()
  -- The list can arrive empty before the recipes load; keep the last good one.
  if next(uses) == nil and Saved() then return end
  cache = uses
  if ns.chardb then ns.chardb.cookingReagents = uses end
end

-- Retail fills the recipe list a moment after the window shows: scan on every list
-- update and once more after opening. Events a client doesn't know are skipped via pcall.
local watcher = CreateFrame("Frame")
for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
  pcall(watcher.RegisterEvent, watcher, event)
end
watcher:SetScript("OnEvent", function(_, event)
  Rebuild()
  if event == "TRADE_SKILL_SHOW" and C_Timer then C_Timer.After(1, Rebuild) end
end)

-- One row per caught fish that a known recipe uses, worst shortfall first.
local function Rows()
  local rows = {}
  if not Saved() then return rows end

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

-- Casts to close the gap, from lifetime casts vs catches of this fish; nil without enough data.
local function CastsNeeded(row)
  if row.short <= 0 or row.caught <= 0 then return nil end
  local stats = ns.Stats and ns.Stats:Data()
  local totalCasts = stats and stats.casts or 0
  if totalCasts <= 0 then return nil end
  local perCast = row.caught / totalCasts
  if perCast <= 0 then return nil end
  return math.ceil(row.short / perCast)
end

-- "|T<path>:<size>|t" icon markup; empty without a texture so no gap is left.
local function Icon(texture, size)
  return texture and ("|T" .. texture .. ":" .. (size or 16) .. ":" .. (size or 16) .. ":0:0|t ") or ""
end

-- The cached item link, or one built from id and name when the item info isn't loaded yet.
local function FishLink(itemID, name)
  local link = select(2, Compat.GetItemInfo(itemID))
  if type(link) == "string" and link:find("|Hitem:", 1, true) then return link end
  return string.format("|cffffffff|Hitem:%d|h[%s]|h|r", itemID, name)
end

-- Recipe name as a clickable link when the API gives one, else plain text.
local function RecipeText(use)
  if not use.link and use.recipeID then use.link = Compat.RecipeLink(use.recipeID, use.recipe) end
  return Icon(use.icon) .. (use.link or use.recipe)
end

-- A list saved before recipe links existed has names only.
local function MissingLinks()
  for _, uses in pairs(Saved() or {}) do
    for _, use in ipairs(uses) do
      if not use.link and not use.recipeID then return true end
    end
  end
  return false
end

-- By recipe: each known recipe that takes a fish you've caught, with every
-- such fish under it and how many of the recipe your fish would cover.
local function RecipeLines(rows)
  local recipes, order = {}, {}
  for _, row in ipairs(rows) do
    for _, use in ipairs(row.uses) do
      local key = use.recipeID or use.recipe
      local recipe = recipes[key]
      if not recipe then
        recipe = { use = use, name = use.recipe, fish = {} }
        recipes[key] = recipe
        order[#order + 1] = recipe
      end
      recipe.fish[#recipe.fish + 1] = { row = row, need = use.need }
    end
  end
  table.sort(order, function(a, b) return a.name < b.name end)

  local lines = { { text = L["Your Cooking recipes that use fish you've caught:"], header = true } }
  for _, recipe in ipairs(order) do
    local covers
    for _, fish in ipairs(recipe.fish) do
      local times = math.floor(fish.row.held / math.max(1, fish.need))
      covers = covers and math.min(covers, times) or times
    end
    local note = covers > 0 and string.format(L["|cff40ff40fish for %d|r"], covers)
      or "|cffff6060" .. L["short on fish"] .. "|r"
    if #lines > 1 then lines[#lines + 1] = { text = " " } end -- space between recipes
    lines[#lines + 1] = { text = RecipeText(recipe.use) .. "  " .. note }
    table.sort(recipe.fish, function(a, b) return a.row.name < b.row.name end)
    for _, fish in ipairs(recipe.fish) do
      local color = fish.row.held >= fish.need and "ffffff" or "ff6060"
      lines[#lines + 1] = { text = string.format("      %s%s  |cff%s%d / %d|r",
        Icon(Compat.ItemIcon(fish.row.id), 14), FishLink(fish.row.id, fish.row.name), color, fish.row.held, fish.need) }
    end
  end
  return lines
end

-- view: "fish" (default) or "recipe".
function Shopping:Lines(view)
  local lines = {}
  if not Saved() then
    lines[1] = { text = L["Open your Cooking profession window once and this list fills in."] }
    return lines
  end

  local rows = Rows()
  if #rows == 0 then
    lines[1] = { text = L["Nothing in your known Cooking recipes needs a fish you've caught."] }
    return lines
  end

  if view == "recipe" then
    lines = RecipeLines(rows)
  else
    lines[#lines + 1] = { text = L["Cooking reagents you've fished up before:"], header = true }
  end
  if MissingLinks() then
    local hint = L["Open your Cooking window again to turn these recipes into links."]
    table.insert(lines, 2, { text = "|cff808080" .. hint .. "|r" })
  end
  if view == "recipe" then return lines end
  for _, row in ipairs(rows) do
    lines[#lines + 1] = { text = string.format(L["%s%s - have %d:"],
      Icon(Compat.ItemIcon(row.id), 20), FishLink(row.id, row.name), row.held) }
    -- One recipe per line: easier to read than a comma list when a fish has several uses.
    for _, use in ipairs(row.uses) do
      lines[#lines + 1] = { text = "      " .. RecipeText(use) .. string.format(L[" - needs %d"], use.need) }
    end
    if row.short > 0 then
      local text = string.format(L["Need %d more."], row.short)
      local casts = CastsNeeded(row)
      if casts then
        text = text .. "  " .. string.format(L["About %d more casts at your rate."], casts)
      end
      lines[#lines + 1] = { text = "   |cff808080" .. text .. "|r" }
    end
    lines[#lines + 1] = { text = " " } -- breathing room before the next fish
  end
  lines[#lines] = nil -- no trailing gap after the last one
  return lines
end

-- Menu.lua calls this once when the compartment is built, so a window opened before /tb menu counts.
function Shopping:Refresh()
  Rebuild()
end

-- /tb shopdebug
function Shopping:Diagnose()
  Rebuild()
  for _, line in ipairs(Compat.ShoppingDiagnostics()) do ns:Print(line) end
  local saved, withID = 0, 0
  for _, uses in pairs(Saved() or {}) do
    for _, use in ipairs(uses) do
      saved = saved + 1
      if use.recipeID or use.link then withID = withID + 1 end
    end
  end
  ns:Print(string.format("Saved list: %d recipe uses, %d with a link or recipe ID.", saved, withID))
end
