-- Midnight Helpers (Retail): Captain Tokka's Crew reputation and Coiled
-- Filament progress. The faction and currency IDs aren't published
-- anywhere reliable yet, so they are found by name in the player's own
-- reputation and currency lists and then remembered. Runs only when asked
-- (/tb midnight).
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Midnight = {}
ns.Midnight = Midnight

local function FindFaction()
  local ids = ns.db.ids
  if ids.tokkaFaction then return ids.tokkaFaction end
  if not C_Reputation or not C_Reputation.GetNumFactions then return nil end
  for index = 1, C_Reputation.GetNumFactions() do
    local faction = C_Reputation.GetFactionDataByIndex(index)
    if faction and not faction.isHeader and faction.name
      and faction.name:find(Data.midnight.factionName, 1, true) then
      ids.tokkaFaction = faction.factionID
      return faction.factionID
    end
  end
end

local function FindCurrency()
  local ids = ns.db.ids
  if ids.filamentCurrency then return ids.filamentCurrency end
  if not C_CurrencyInfo then return nil end
  local known = Data.midnight.currencyID
  if known and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(known) then
    return known
  end
  if not C_CurrencyInfo.GetCurrencyListSize then return nil end
  for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    if info and not info.isHeader and info.name == Data.midnight.currencyName then
      local link = C_CurrencyInfo.GetCurrencyListLink(index)
      local currencyID = link and tonumber(link:match("currency:(%d+)"))
      if currencyID then
        ids.filamentCurrency = currencyID
        return currencyID
      end
    end
  end
end

-- Standing name plus progress inside the current rank.
local function Reputation(factionID)
  local friend = C_GossipInfo and C_GossipInfo.GetFriendshipReputation
    and C_GossipInfo.GetFriendshipReputation(factionID)
  if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
    if not friend.nextThreshold then return friend.reaction, nil, nil end
    return friend.reaction, friend.standing - friend.reactionThreshold,
      friend.nextThreshold - friend.reactionThreshold
  end
  local faction = C_Reputation.GetFactionDataByID(factionID)
  if not faction then return nil end
  local standing = _G["FACTION_STANDING_LABEL" .. (faction.reaction or 0)] or "?"
  local span = (faction.nextReactionThreshold or 0) - (faction.currentReactionThreshold or 0)
  if span <= 0 then return standing, nil, nil end
  return standing, faction.currentStanding - faction.currentReactionThreshold, span
end

function Midnight:FilamentCount()
  local currencyID = FindCurrency()
  if currencyID then
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info then return info.quantity end
  end
  -- In case it turns out to be a bag item rather than a currency.
  local count = Compat.GetItemCount(Data.midnight.currencyName)
  if count and count > 0 then return count end
end

function Midnight:Lines()
  local names = Data.midnight
  local lines = {}
  local function Add(text) lines[#lines + 1] = { text = text, header = true } end

  local factionID = FindFaction()
  if factionID then
    local standing, progress, span = Reputation(factionID)
    if progress then
      Add(string.format("%s: %s, %d/%d", names.factionName, standing or "?", progress, span))
    else
      Add(string.format("%s: %s", names.factionName, standing or "?"))
    end
  else
    Add(string.format(L["%s: not found in your reputation list yet (check that its header isn't collapsed)."],
      names.factionName))
  end

  local filament = self:FilamentCount()
  if filament then
    local goal = names.mountCost
    Add(string.format(L["%s: %d of %d for the mount (%d%%)."], names.currencyName,
      filament, goal, math.floor(math.min(1, filament / goal) * 100)))
  else
    Add(string.format(L["%s: none found yet."], names.currencyName))
  end
  return lines
end

function Midnight:Print()
  ns:PrintLines(self:Lines())
end
