-- Every Retail/Classic difference lives here. The rest of the addon calls
-- Compat.* and never checks the game version itself.
local _, ns = ...

local Compat = {}
ns.Compat = Compat

Compat.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
Compat.isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

-- Retail poles sit in the profession tool slot and are used automatically.
-- Everywhere else the pole has to be in the main hand.
Compat.needsPole = not Compat.isRetail

-- Soft interact is reliable on Retail; Classic reels through mouseover.
Compat.INTERACT = Compat.isRetail and "INTERACTTARGET" or "INTERACTMOUSEOVER"

local MAINHAND = INVSLOT_MAINHAND or 16
Compat.MAINHAND = MAINHAND

---------------------------------------------------------------------------
-- 12.x secret values
---------------------------------------------------------------------------

local issecretvalue = issecretvalue

function Compat.IsSecret(value)
  return issecretvalue ~= nil and issecretvalue(value) or false
end

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------

function Compat.GetSpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(spellID)
  end
  if GetSpellInfo then
    return (GetSpellInfo(spellID))
  end
end

-- 131474 is the castable spell, 131476 the channel. The rest are Classic ranks.
local FISHING_IDS = {
  [131474] = true, [131476] = true,
  [7620] = true, [7731] = true, [7732] = true, [18248] = true,
  [33095] = true, [51294] = true, [88868] = true, [110410] = true,
}

local fishingName
function Compat.FishingName()
  if not fishingName then
    fishingName = Compat.GetSpellName(131474) or Compat.GetSpellName(7620)
  end
  return fishingName
end

function Compat.IsFishingSpell(spellID)
  if Compat.IsSecret(spellID) or not spellID then return false end
  if FISHING_IDS[spellID] then return true end
  local name = Compat.GetSpellName(spellID)
  return name ~= nil and name == Compat.FishingName()
end

function Compat.IsFishingChannelActive()
  local name = UnitChannelInfo and UnitChannelInfo("player")
  if not name or Compat.IsSecret(name) then return false end
  return name == Compat.FishingName()
end

---------------------------------------------------------------------------
-- Items, toys, cooldowns
---------------------------------------------------------------------------

Compat.GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
Compat.GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
Compat.GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount
Compat.GetItemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
Compat.EquipItemByName = C_Item and C_Item.EquipItemByName or EquipItemByName

function Compat.HasToy(itemID)
  return PlayerHasToy ~= nil and PlayerHasToy(itemID) or false
end

function Compat.ItemReady(itemID)
  local getCooldown = C_Container and C_Container.GetItemCooldown or GetItemCooldown
  if not getCooldown then return true end
  local start, duration = getCooldown(itemID)
  if Compat.IsSecret(start) or Compat.IsSecret(duration) then return false end
  if not start or start == 0 or not duration or duration == 0 then return true end
  return (start + duration - GetTime()) <= 0
end

function Compat.IsFishingPole(itemID)
  if not itemID then return false end
  local _, _, _, _, _, classID, subClassID = Compat.GetItemInfoInstant(itemID)
  return classID == 2 and subClassID == 20
end

function Compat.BagSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag)
  end
  return GetContainerNumSlots(bag)
end

function Compat.BagItemID(bag, slot)
  if C_Container and C_Container.GetContainerItemID then
    return C_Container.GetContainerItemID(bag, slot)
  end
  return GetContainerItemID(bag, slot)
end

---------------------------------------------------------------------------
-- Auras
---------------------------------------------------------------------------

-- Seconds left on a player buff, math.huge for a buff with no timer,
-- nil when the buff is missing (or unreadable).
function Compat.AuraRemaining(spellID, spellName)
  -- Aura fields can be secret in combat, where even testing them errors.
  -- Nothing here needs buffs in combat, so don't look.
  if InCombatLockdown() then return nil end
  local expiration
  if spellID and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if aura then expiration = aura.expirationTime end
  end
  if expiration == nil and spellName and AuraUtil and AuraUtil.FindAuraByName then
    local name, _, _, _, _, expires = AuraUtil.FindAuraByName(spellName, "player", "HELPFUL")
    if name then expiration = expires end
  end
  if expiration == nil or Compat.IsSecret(expiration) then return nil end
  if expiration == 0 then return math.huge end
  return math.max(0, expiration - GetTime())
end

---------------------------------------------------------------------------
-- Loot, CVars, money
---------------------------------------------------------------------------

-- IsFishingLoot is missing from the 12.x docs, so fall back to "a fishing
-- channel ended a moment ago" when it isn't there.
function Compat.IsFishingLoot(recentlyFished)
  if IsFishingLoot then
    return IsFishingLoot() and true or false
  end
  return recentlyFished
end

function Compat.GetCVar(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  return GetCVar(name)
end

function Compat.SetCVar(name, value)
  if C_CVar and C_CVar.SetCVar then return C_CVar.SetCVar(name, value) end
  return SetCVar(name, value)
end

function Compat.CoinString(copper)
  copper = math.floor(copper or 0)
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
    return C_CurrencyInfo.GetCoinTextureString(copper)
  end
  return GetCoinTextureString(copper)
end
