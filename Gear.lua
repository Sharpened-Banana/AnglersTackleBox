-- Gear Swap: put fishing gear on when the mode starts and the normal gear
-- back when it ends. Never runs in combat. The snapshot lives in the
-- per-character saved variables so it survives a logout or crash.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Gear = ns:NewModule("Gear")

local FIRST_SLOT, LAST_SLOT = 1, 19

function Gear:PoleEquipped()
  return Compat.IsFishingPole(GetInventoryItemID("player", Compat.MAINHAND))
end

-- Item ID of a fishing pole the player owns, equipped or in bags.
function Gear:FindPole()
  if not Compat.needsPole then return nil end
  local equipped = GetInventoryItemID("player", Compat.MAINHAND)
  if Compat.IsFishingPole(equipped) then return equipped end

  local preferred = ns.chardb.poleID
  if preferred and Compat.GetItemCount(preferred) > 0 then return preferred end

  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, Compat.BagSlots(bag) or 0 do
      local itemID = Compat.BagItemID(bag, slot)
      if Compat.IsFishingPole(itemID) then return itemID end
    end
  end
end

-- One-key fallback: if the pole isn't in hand, the next press equips it.
function Gear:PoleAction()
  if not Compat.needsPole or self:PoleEquipped() then return nil end
  local pole = self:FindPole()
  if not pole then return nil end
  return { id = "pole", type = "item", value = "item:" .. pole, label = L["Equip pole"] }
end

local function FishingSetID()
  local name = ns.chardb.fishingSet
  if not name or not C_EquipmentSet then return nil end
  return C_EquipmentSet.GetEquipmentSetID(name)
end

function Gear:Enable()
  -- Always-on would mean wearing fishing gear all day, so it skips the swap.
  if ns.db.alwaysOn then return end
  if self.applied or not ns.chardb.gearSwap or InCombatLockdown() then return end
  local setID = FishingSetID()
  local pole = self:FindPole()
  if not setID and not pole then return end

  if not ns.chardb.gearBackup then
    local backup = {}
    for slot = FIRST_SLOT, LAST_SLOT do
      backup[slot] = GetInventoryItemLink("player", slot)
    end
    ns.chardb.gearBackup = backup
  end

  self.lastSwap = GetTime()
  if setID then
    C_EquipmentSet.UseEquipmentSet(setID)
  elseif not self:PoleEquipped() then
    Compat.EquipItemByName(pole)
  end
  self.applied = true
end

function Gear:Restore()
  local backup = ns.chardb.gearBackup
  if not backup then self.applied = false return end
  if InCombatLockdown() then return end

  self.lastSwap = GetTime()
  for slot = FIRST_SLOT, LAST_SLOT do
    local link = backup[slot]
    if link and GetInventoryItemLink("player", slot) ~= link then
      Compat.EquipItemByName(link, slot)
    end
  end
  ns.chardb.gearBackup = nil
  self.applied = false
end

function Gear:Disable()
  -- Equipping fails during logout; keep the backup and restore at next login.
  if ns.Core.loggingOut then return end
  self:Restore()
end

function Gear:Suspend()
  if ns.chardb.gearCombatRestore then self:Restore() end
end

Gear.Resume = Gear.Enable
