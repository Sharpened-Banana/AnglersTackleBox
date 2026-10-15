-- Lure manager: keeps a lure up via the one-key queue; warns on expiry or empty bags.
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
    -- Auto-swap keeps the saved pick (restocking switches back) and waits for
    -- the running lure to wear off rather than overwrite it.
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
    return Compat.WeaponEnchantRemaining()
  end

  -- Retail: usually a buff named after the item's use spell.
  local spellName, spellID = Compat.GetItemSpell(itemID)
  local remaining = Compat.AuraRemaining(spellID, spellName)
  if remaining then
    self.auraSeen[itemID] = true
    return remaining
  end

  -- Unreadable buffs fall back to time since the use spell succeeded.
  -- A readable buff that is gone is simply gone.
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
      -- The swap message already says it; skip the old lure's expiry warning.
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
    if not self.emptySaid and ns.db.lureEmptyWarn then
      self.emptySaid = true
      -- Always-on runs all day, so running out gets a silent popup, not a raid warning.
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

-- First cast of a session with no lure up: the key applies an owned lure before casting, so a
-- cast without one means none is picked or none is left. Ask once, with a way to pick one.
local PROMPT = "ANGLERS_TACKLEBOX_NO_LURE"

function Lures:Prompt(text)
  if not StaticPopupDialogs or not StaticPopup_Show then return end
  StaticPopupDialogs[PROMPT] = StaticPopupDialogs[PROMPT] or {
    text = "%s",
    button1 = L["Pick a lure"],
    button2 = L["Not now"],
    button3 = L["Don't ask again"],
    OnAccept = function() ns.Menu:Open("lures") end,
    OnAlt = function()
      ns.db.lurePrompt = false
      ns:Print(L["Won't ask about lures again. Turn it back on in the Lures compartment or the settings."])
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show(PROMPT, text)
end

ns:On("CAST_START", function()
  if Lures.prompted or not ns.db.lurePrompt or not ns.chardb.lureEnabled then return end
  Lures.prompted = true
  local itemID = Lures:Current()
  if itemID and (Lures:Remaining(itemID) or 0) > 0 then return end
  local name = itemID and Compat.GetItemInfo(itemID)
  if itemID and Compat.GetItemCount(itemID) == 0 then
    Lures:Prompt(string.format(L["You're fishing without a lure: you're out of %s. Pick another?"],
      name or ("item:" .. itemID)))
  elseif not itemID then
    Lures:Prompt(L["You're fishing without a lure. Pick one and your fishing key keeps it up for you."])
  end
end)

ns:On("SESSION_START", function() Lures.prompted = nil end)

ns:OnModeEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, _, spellID)
  if Compat.IsSecret(spellID) then return end
  local itemID = Lures:Current()
  if not itemID then return end
  local _, lureSpellID = Compat.GetItemSpell(itemID)
  if lureSpellID and lureSpellID == spellID then
    Lures.appliedAt[itemID] = GetTime()
  end
end)
