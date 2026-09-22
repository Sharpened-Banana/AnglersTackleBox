-- Lure & Buff Manager: keeps a lure up through the one-key queue, warns
-- before it expires and says so when the bag runs dry.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Lures = ns:NewModule("Lures")

Lures.appliedAt = {} -- [itemID] = GetTime() of the last successful use
Lures.auraSeen = {}  -- [itemID] = true once its buff has been read

-- First known lure in the bags other than skip, best first.
local function NextOwned(skip)
  for _, itemID in ipairs(Data.knownLures) do
    if itemID ~= skip and Compat.GetItemCount(itemID) > 0 then return itemID end
  end
end

-- The lure to use: the player's pick, else the best known one in the bags.
function Lures:Current()
  local picked = ns.chardb.lureID
  if picked then
    -- Auto-swap only redirects what the next keypress applies; the pick
    -- itself is kept, so restocking it switches back. Waits for the old
    -- lure to wear off so a running one is never overwritten.
    if ns.chardb.lureAutoSwap and Compat.GetItemCount(picked) == 0
      and (self:Remaining(picked) or 0) <= 0 then
      return NextOwned(picked) or picked
    end
    return picked
  end
  for _, itemID in ipairs(Data.lures) do
    if Compat.GetItemCount(itemID) > 0 then return itemID end
  end
end

-- Seconds left on the active lure, or nil when none is up.
function Lures:Remaining(itemID)
  itemID = itemID or self:Current()
  if not itemID then return nil end

  -- Classic: the lure is a temporary enchant on the pole.
  if Data.lureIsEnchant and ns.Gear:PoleEquipped() then
    local hasEnchant, expirationMS = GetWeaponEnchantInfo()
    if hasEnchant and expirationMS then return expirationMS / 1000 end
    return nil
  end

  -- Retail: usually a buff named after the item's use spell.
  local spellName, spellID = Compat.GetItemSpell(itemID)
  local remaining = Compat.AuraRemaining(spellID, spellName)
  if remaining then
    self.auraSeen[itemID] = true
    return remaining
  end

  -- Last resort, for lures whose buff can't be read: time since we saw the
  -- use spell succeed. A readable buff that is gone is simply gone.
  local appliedAt = self.appliedAt[itemID]
  if appliedAt and not self.auraSeen[itemID] then
    local left = appliedAt + Data.lureDuration - GetTime()
    if left > 0 then return left end
  end
end

function Lures:Action()
  if not ns.chardb.lureEnabled then return nil end
  local itemID = self:Current()
  if not itemID or Compat.GetItemCount(itemID) == 0 then return nil end
  if (self:Remaining(itemID) or 0) > 0 then return nil end
  return {
    id = "lure:" .. itemID,
    type = "item",
    value = "item:" .. itemID,
    targetSlot = Data.lureIsEnchant and Compat.MAINHAND or nil,
    label = L["Apply lure"],
  }
end

function Lures:Enable()
  self.warned, self.expiredSaid, self.emptySaid, self.swappedTo = nil, nil, nil, nil
end

function Lures:Tick()
  if not ns.chardb.lureEnabled then return end
  local itemID = self:Current()
  if not itemID then return end

  local picked = ns.chardb.lureID
  if picked and itemID ~= picked then
    if self.swappedTo ~= itemID then
      self.swappedTo = itemID
      -- The swap message says what the next press does, so the expiry
      -- warning for the old lure would only repeat it.
      self.warned, self.expiredSaid = nil, nil
      local name, link = Compat.GetItemInfo(itemID)
      ns.Alerts:Fire("lure", string.format(L["Out of your lure. Switched to %s; the next press applies it."],
        link or name or ("item:" .. itemID)), true)
    end
  else
    self.swappedTo = nil
  end

  if Compat.GetItemCount(itemID) == 0 then
    -- Auto-swap has a spare waiting for the current lure to wear off.
    if ns.chardb.lureAutoSwap and NextOwned(itemID) then return end
    if not self.emptySaid then
      self.emptySaid = true
      -- With always-on the mode runs all day, so an empty lure stack is
      -- ordinary news: a text popup, not the raid warning sound.
      ns.Alerts:Fire("lure", L["Out of lures!"], ns.db.alwaysOn)
    end
    return
  end
  self.emptySaid = nil

  local remaining = self:Remaining(itemID)
  if not remaining then
    if self.warned and not self.expiredSaid then
      self.expiredSaid = true
      ns.Alerts:Fire("lure", L["Lure expired. Next press applies a new one."])
    end
  elseif remaining <= ns.db.lureWarn then
    if not self.warned then
      self.warned = true
      ns.Alerts:Fire("lure", string.format(L["Lure expires in %d seconds."], math.floor(remaining)))
    end
  else
    self.warned, self.expiredSaid = nil, nil
  end
end

ns:OnModeEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
  if Compat.IsSecret(spellID) then return end
  local itemID = Lures:Current()
  if not itemID then return end
  local _, lureSpellID = Compat.GetItemSpell(itemID)
  if lureSpellID and lureSpellID == spellID then
    Lures.appliedAt[itemID] = GetTime()
  end
end)
