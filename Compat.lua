-- Every difference between Retail and WoW Forever (the Classic-style client,
-- TOC suffix _Camelot) lives here. The rest of the addon calls
-- Compat.* and never checks the game version itself.
local _, ns = ...

local Compat = {}
ns.Compat = Compat

Compat.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
Compat.isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

-- Retail poles sit in the profession tool slot and are used automatically.
-- Everywhere else the pole has to be in the main hand.
Compat.needsPole = not Compat.isRetail

-- Soft interact is reliable on Retail. WoW Forever reels through mouseover
-- unless the player opts into soft interact there too.
function Compat.Interact()
  if Compat.isRetail or (ns.db and ns.db.classicSoftInteract) then return "INTERACTTARGET" end
  return "INTERACTMOUSEOVER"
end

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

---------------------------------------------------------------------------
-- Cooking reagents (Shopping.lua). Retail's trade skill window is read
-- through C_TradeSkillUI; WoW Forever still uses the classic global API.
-- Both only expose the currently open profession's recipes.
---------------------------------------------------------------------------

function Compat.OpenTradeSkillName()
  if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
    local ok, name = pcall(C_TradeSkillUI.GetTradeSkillLine)
    return ok and name or nil
  end
  if GetTradeSkillLine then
    local ok, name = pcall(GetTradeSkillLine)
    return ok and name or nil
  end
  return nil
end

local COOKING_SKILL_LINE = 185

-- Retail (Dragonflight on) dropped GetTradeSkillLine; the open profession
-- comes from GetBaseProfessionInfo, matched by skill line so it works in
-- every client language. Another player's linked book, a guild view or an
-- NPC crafting order is not the player's own recipe list, so it is skipped.
function Compat.IsCookingWindowOpen()
  local ui = C_TradeSkillUI
  if ui and ui.GetBaseProfessionInfo then
    for _, check in ipairs({ ui.IsTradeSkillLinked, ui.IsTradeSkillGuild, ui.IsNPCCrafting }) do
      local ok, yes = pcall(check or function() end)
      if ok and yes then return false end
    end
    local ok, info = pcall(ui.GetBaseProfessionInfo)
    if not ok or type(info) ~= "table" then return false end
    if info.professionID == COOKING_SKILL_LINE then return true end
    local cooking = Enum and Enum.Profession and Enum.Profession.Cooking
    return cooking ~= nil and info.profession == cooking
  end
  local name = Compat.OpenTradeSkillName()
  return name ~= nil and name == (PROFESSIONS_COOKING or "Cooking")
end

-- Every reagent item used by the open trade skill window's known recipes,
-- as { [itemID] = { { recipe = name, need = count }, ... } }. Empty (not
-- nil) when nothing is open or the API doesn't behave as expected.
function Compat.TradeSkillReagentUses()
  local uses = {}
  local function AddUse(itemID, recipeName, need)
    if not itemID or not recipeName then return end
    local list = uses[itemID]
    if not list then list = {} uses[itemID] = list end
    list[#list + 1] = { recipe = recipeName, need = need or 1 }
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeSchematic then
    local ok, recipeIDs = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if ok and recipeIDs then
      -- GetAllRecipeIDs lists unlearned recipes too; only known ones count.
      -- Optional and finishing slots are extras, not what a recipe needs.
      local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
      for _, recipeID in ipairs(recipeIDs) do
        local learned = true
        if C_TradeSkillUI.GetRecipeInfo then
          local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
          learned = okInfo and info and info.learned
        end
        local okSchem, schematic = false, nil
        if learned then okSchem, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false) end
        if okSchem and schematic and schematic.reagentSlotSchematics then
          for _, slot in ipairs(schematic.reagentSlotSchematics) do
            if not basic or slot.reagentType == nil or slot.reagentType == basic then
              for _, reagent in ipairs(slot.reagents or {}) do
                AddUse(reagent.itemID, schematic.name, slot.quantityRequired)
              end
            end
          end
        end
      end
    end
    return uses
  end

  if GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillReagentInfo then
    local ok, count = pcall(GetNumTradeSkills)
    if ok and count then
      for index = 1, count do
        local okInfo, name, kind = pcall(GetTradeSkillInfo, index)
        if okInfo and name and kind ~= "header" and kind ~= "subheader" then
          local numReagents = 0
          if GetTradeSkillNumReagents then
            local okNum, n = pcall(GetTradeSkillNumReagents, index)
            numReagents = okNum and n or 0
          end
          for reagentIndex = 1, numReagents do
            local okReagent, _, _, reagentCount = pcall(GetTradeSkillReagentInfo, index, reagentIndex)
            local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(index, reagentIndex)
            local itemID = link and tonumber(link:match("item:(%d+)"))
            if okReagent and itemID then AddUse(itemID, name, reagentCount) end
          end
        end
      end
    end
  end
  return uses
end
