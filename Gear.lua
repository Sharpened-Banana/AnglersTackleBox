-- Gear swap on mode start/end, never in combat. The snapshot is in per-character
-- saved variables so it survives a logout or crash.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Gear = ns:NewModule("Gear")

local FIRST_SLOT, LAST_SLOT = 1, 19
local AdoptPole
local WALK_AWAY = 1.5 -- seconds after you start moving, without casting, before your normal gear goes back on

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
  local label = ns.db.holdToCast and L["Equip pole (hold to cast too)"] or L["Equip pole"]
  return { id = "pole", type = "item", value = "item:" .. pole, label = label }
end

local function FishingSetID()
  local name = ns.chardb.fishingSet
  if not name or not C_EquipmentSet then return nil end
  return C_EquipmentSet.GetEquipmentSetID(name)
end

-- The weapon last seen in hand, kept across sessions: it is what walking away goes back to when
-- the pole was already on (a login or /reload with it equipped) and nothing was snapshotted.
local OFFHAND = 17

local function RememberWeapon()
  if not Compat.needsPole then return end
  local link = GetInventoryItemLink("player", Compat.MAINHAND)
  if not link or Gear:PoleEquipped() then return end
  ns.chardb.lastWeapon = {
    [Compat.MAINHAND] = link,
    [OFFHAND] = GetInventoryItemLink("player", OFFHAND),
  }
end

local function Snapshot()
  if ns.chardb.gearBackup then return end
  RememberWeapon()
  local backup = {}
  for slot = FIRST_SLOT, LAST_SLOT do
    backup[slot] = GetInventoryItemLink("player", slot)
  end
  ns.chardb.gearBackup = backup
end

-- The key is about to equip the pole: remember what it replaces, for when the mode ends.
function Gear:BeforePolePress()
  if not ns.chardb.gearSwap then return end
  -- Always-on never ends the mode, so the weapon only comes back if walking away restores it.
  if ns.db.alwaysOn and not ns.chardb.gearWalkAway then return end
  Snapshot()
  self.lastSwap = GetTime()
  self.applied = true
  -- You pressed the key at the water, so walking off counts even if no cast followed.
  self.fished, self.movedAt = true, nil
end

-- The key is about to cast with your normal gear on, after walking away from the last spot:
-- a fishing set goes back on. A pole comes back through the key's own "Equip pole" step.
function Gear:BeforeCastPress()
  if not self.applied and FishingSetID() then self:Enable() end
end

function Gear:Enable()
  -- Always-on would mean fishing gear all day, so no swap.
  if ns.db.alwaysOn then return end
  if self.applied or not ns.chardb.gearSwap or InCombatLockdown() then return end
  local setID = FishingSetID()
  local pole = self:FindPole()
  if not setID and not pole then return end

  Snapshot()

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
  self.fished, self.movedAt = nil, nil
end

function Gear:Disable()
  self.combatWeapon = nil
  -- Equipping fails during logout; keep the backup and restore at next login.
  if ns.Core.loggingOut then return end
  self:Restore()
end

-- The weapon to put back when combat starts with the pole on, as slot -> link. Asked for by both
-- Gear and Engine, whichever is suspended first.
function Gear:CombatWeapon()
  if self.combatWeapon ~= nil then return self.combatWeapon or nil end
  self.combatWeapon = false
  if not Compat.needsPole or not ns.chardb.gearCombatRestore then return nil end
  AdoptPole() -- a pole that was already on at login has no snapshot; the remembered weapon stands in
  local backup = ns.chardb.gearBackup
  if not backup or not self:PoleEquipped() or not backup[Compat.MAINHAND] then return nil end
  self.combatWeapon = { [Compat.MAINHAND] = backup[Compat.MAINHAND], [OFFHAND] = backup[OFFHAND] }
  return self.combatWeapon
end

-- The game can refuse the swap at the moment combat starts (mid-cast, for one), and once the fight
-- is on an addon may not equip anything: only a key press can. This is the macro for that press.
function Gear:CombatWeaponMacro()
  local weapon = self:CombatWeapon()
  if not weapon then return nil end
  local lines = {}
  for _, slot in ipairs({ Compat.MAINHAND, OFFHAND }) do
    local link = weapon[slot]
    local item = link and (link:match("%[(.-)%]") or link:match("item:%d+") or link)
    if item then lines[#lines + 1] = "/equipslot " .. slot .. " " .. item end
  end
  return lines[1] and table.concat(lines, "\n") or nil
end

function Gear:Suspend()
  if not ns.chardb.gearCombatRestore then return end
  self:CombatWeapon()
  self:Restore()
end

-- After combat the pole waits for the fishing key (Planner), or the next pull would start with it
-- in hand. A fishing set has no key action, so it still comes back by itself.
function Gear:Resume()
  -- The swap was refused and the key never pressed: the fight is over, so it is allowed again.
  local weapon = self.combatWeapon
  self.combatWeapon = nil
  if weapon and self:PoleEquipped() and not InCombatLockdown() then
    self.lastSwap = GetTime()
    for slot, link in pairs(weapon) do Compat.EquipItemByName(link, slot) end
  end
  if Compat.needsPole and not FishingSetID() then return end
  self:Enable()
end

function Gear:Tick()
  RememberWeapon()
end

-- A cast with the pole on but nothing to go back to: use the snapshot a /reload left, or the
-- remembered weapon.
AdoptPole = function()
  if Gear.applied or not ns.chardb.gearSwap then return end
  if not Compat.needsPole or not Gear:PoleEquipped() then return end
  local last = ns.chardb.lastWeapon
  if not ns.chardb.gearBackup then
    if not last then Gear.unknownWeapon = true return end
    ns.chardb.gearBackup = { [Compat.MAINHAND] = last[Compat.MAINHAND], [OFFHAND] = last[OFFHAND] }
  end
  Gear.applied = true
end

-- Walking away from the water puts your normal gear back without leaving fishing mode: after a
-- cast with the gear on, moving and not casting again for WALK_AWAY seconds.
ns:On("CAST_START", function()
  if ns.chardb.gearWalkAway then AdoptPole() end
  if Gear.applied then Gear.fished, Gear.movedAt = true, nil end
end)

ns:OnModeEvent("PLAYER_STARTED_MOVING", function()
  if not ns.chardb.gearWalkAway then return end
  if Gear.unknownWeapon and not Gear.applied then
    Gear.unknownWeapon = nil
    ns:Print(L["TackleBox doesn't know your weapon yet. Equip it once and it will come back by itself from then on."])
    return
  end
  -- Each new key press fires this again; the countdown runs from the first one after a cast.
  if not Gear.applied or not Gear.fished or Gear.movedAt then return end
  local movedAt = GetTime()
  Gear.movedAt = movedAt
  C_Timer.After(WALK_AWAY, function()
    if Gear.movedAt ~= movedAt then return end
    Gear.movedAt = nil
    if not Gear.applied or InCombatLockdown() then return end
    if not ns.Core.mode or ns.Core.suspended or ns.Engine.state == "CHANNELING" then return end
    Gear:Restore()
  end)
end)
