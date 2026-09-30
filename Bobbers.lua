-- Keeps the Oversized Bobber and a chosen bobber toy up via the one-key queue:
-- one press applies a missing buff, the next casts.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Bobbers = {}
ns.Bobbers = Bobbers

local castAt = {}   -- [spellID] = GetTime() of the last successful cast
local auraSeen = {} -- [itemID] = true once its buff has been read

-- Unreadable buffs fall back to time since the toy's spell last succeeded.
local function Remaining(itemID, knownSpell)
  local spellName, spellID = Compat.GetItemSpell(itemID)
  local remaining = Compat.AuraRemaining(knownSpell or spellID, spellName)
  if remaining then
    auraSeen[itemID] = true
    return remaining
  end
  local at = spellID and castAt[spellID]
  if at and not auraSeen[itemID] then
    local left = at + Data.bobberDuration - GetTime()
    if left > 0 then return left end
  end
end

ns:OnModeEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
  if not Compat.IsSecret(spellID) and spellID then castAt[spellID] = GetTime() end
end)

-- Owned bobber toys: the known list, then any added with /tb bobber (Blizzard keeps adding them),
-- then the chosen one if it's somehow neither, so its buff is always seen.
function Bobbers:Owned()
  local owned, seen = {}, {}
  local function Add(itemID)
    if type(itemID) == "number" and not seen[itemID] and Compat.HasToy(itemID) then
      seen[itemID] = true
      owned[#owned + 1] = itemID
    end
  end
  for _, itemID in ipairs(Data.bobberToys) do Add(itemID) end
  for _, itemID in ipairs(ns.db.customBobbers) do Add(itemID) end
  Add(ns.db.bobber)
  return owned
end

function Bobbers:Known(itemID)
  for _, known in ipairs(Data.bobberToys) do
    if known == itemID then return true end
  end
  for _, known in ipairs(ns.db.customBobbers) do
    if known == itemID then return true end
  end
  return false
end

-- Adds a toy the list doesn't have yet. True when it was new.
function Bobbers:AddCustom(itemID)
  if self:Known(itemID) then return false end
  table.insert(ns.db.customBobbers, itemID)
  return true
end

function Bobbers:RemoveCustom(itemID)
  local list = ns.db.customBobbers
  for index = #list, 1, -1 do
    if list[index] == itemID then
      table.remove(list, index)
      if ns.db.bobber == itemID then ns.db.bobber = nil end
      return true
    end
  end
  return false
end

function Bobbers:HasOversized()
  return Data.oversizedBobber ~= nil and Compat.HasToy(Data.oversizedBobber.item)
end

-- The toy whose buff is up right now, if any.
function Bobbers:Active()
  for _, itemID in ipairs(self:Owned()) do
    local remaining = Remaining(itemID)
    if remaining then return itemID, remaining end
  end
end

function Bobbers:OversizedAction()
  local oversized = Data.oversizedBobber
  if not ns.db.oversizedBobber or not oversized or not Compat.HasToy(oversized.item) then return nil end
  if Remaining(oversized.item, oversized.spell) or not Compat.ItemReady(oversized.item) then return nil end
  return { id = "oversized", type = "toy", value = oversized.item, extra = true, label = L["Oversized bobber"] }
end

function Bobbers:ToyAction()
  local choice = ns.db.bobber
  if not choice then return nil end
  if self:Active() then
    self.randomPick = nil
    return nil
  end

  local itemID = choice
  if choice == "random" then
    -- Keep one pick until it lands, so the armed action doesn't flicker.
    if not self.randomPick or not Compat.HasToy(self.randomPick) then
      local owned = self:Owned()
      if #owned == 0 then return nil end
      self.randomPick = owned[math.random(#owned)]
    end
    itemID = self.randomPick
  end
  if not Compat.HasToy(itemID) or not Compat.ItemReady(itemID) then return nil end
  return { id = "bobber:" .. itemID, type = "toy", value = itemID, extra = true, label = L["Bobber toy"] }
end
