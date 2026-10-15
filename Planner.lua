-- Picks the one action the next keypress performs; the Engine binds it and
-- handles combat, death and mounts before asking.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Planner = {}
ns.Planner = Planner

Planner.attempts = {}
Planner.snoozed = {} -- [action id] = GetTime() when it may be tried again

local MAX_ATTEMPTS = 3
local SNOOZE = 60
local EXTRA_SNOOZE = 600
local RAFT_REFRESH = 60

local function Snoozed(id)
  local untilTime = Planner.snoozed[id]
  return untilTime ~= nil and GetTime() < untilTime
end

-- Snooze a prep action that keeps failing, or it would block casting forever.
function Planner:NoteAttempt(action)
  if not action or action.id == "cast" then return end
  local id = action.id
  self.attempts[id] = (self.attempts[id] or 0) + 1
  if self.attempts[id] >= MAX_ATTEMPTS then
    self.attempts[id] = nil
    self.snoozed[id] = GetTime() + (action.extra and EXTRA_SNOOZE or SNOOZE)
    ns:Print(string.format(L["%s isn't taking effect; skipping it for now."], action.label))
  end
end

function Planner:ClearAttempts(id)
  if id then self.attempts[id] = nil end
end

function Planner:Reset()
  wipe(self.attempts)
  wipe(self.snoozed)
end

-- Toy when the player has it as one, item when it's in the bags.
local function UseAction(itemID)
  if Compat.HasToy(itemID) then
    return "toy", itemID
  elseif Compat.GetItemCount(itemID) > 0 then
    return "item", "item:" .. itemID
  end
end

local function RaftAction()
  if not ns.db.useRaft then return nil end
  local raft = Data.raft
  local actionType, value = UseAction(raft.item)
  if not actionType or not Compat.ItemReady(raft.item) then return nil end
  -- Start the raft only when swimming (else just keep it alive), so shore
  -- fishing never burns it.
  local remaining = Compat.AuraRemaining(raft.spell)
  if IsSwimming() or (remaining and remaining < RAFT_REFRESH) then
    return { id = "raft", type = actionType, value = value, label = L["Fishing raft"] }
  end
end

local function ExtraAction()
  for _, itemID in ipairs(ns.chardb.extras) do
    local id = "extra:" .. itemID
    if not Snoozed(id) then
      local actionType, value = UseAction(itemID)
      if actionType and Compat.ItemReady(itemID) then
        local spellName, spellID = Compat.GetItemSpell(itemID)
        if not Compat.AuraRemaining(spellID, spellName) then
          local name = Compat.GetItemInfo(itemID)
          return { id = id, type = actionType, value = value, extra = true,
            label = name or L["Extra item"] }
        end
      end
    end
  end
end

-- /tb prep: what each upkeep step sees right now and why it is or isn't next, for working out
-- why something isn't being kept up in a particular place (an Oceanic Vortex, say).
function Planner:Diagnose()
  local function Seconds(value)
    if value == math.huge then return "up, no timer" end
    return value and string.format("%d s left", math.floor(value)) or "not up"
  end
  local function Snooze(id)
    local untilTime = self.snoozed[id]
    if untilTime and GetTime() < untilTime then
      return string.format(", SNOOZED %d s (it didn't take effect 3 times)", math.floor(untilTime - GetTime()))
    end
    return ""
  end
  local engine = ns.Engine
  ns:Print(string.format("Prep: state %s, key does %s, next press: %s", tostring(engine.state),
    tostring(engine.armed), tostring(engine.nextLabel)))

  local lureID = ns.Lures:Current()
  if not ns.chardb.lureEnabled then
    print("   lure: off in settings")
  elseif not lureID then
    print("   lure: none chosen and none known in the bags")
  else
    local spellName, spellID = Compat.GetItemSpell(lureID)
    print(string.format("   lure: %s x%d, buff %s (%s / %s), ready %s%s",
      Compat.GetItemInfo(lureID) or lureID, Compat.GetItemCount(lureID), Seconds(ns.Lures:Remaining(lureID)),
      tostring(spellName), tostring(spellID), tostring(Compat.ItemReady(lureID)), Snooze("lure:" .. lureID)))
  end

  local oversized = Data.oversizedBobber
  if oversized then
    print(string.format("   oversized bobber: setting %s, owned %s, buff %s, ready %s%s",
      tostring(ns.db.oversizedBobber), tostring(Compat.HasToy(oversized.item)),
      Seconds(Compat.AuraRemaining(oversized.spell)), tostring(Compat.ItemReady(oversized.item)),
      Snooze("oversized")))
  end

  local active, remaining = ns.Bobbers:Active()
  local choice = ns.db.bobber
  local chosen = type(choice) == "number"
    and (", ready " .. tostring(Compat.ItemReady(choice)) .. Snooze("bobber:" .. choice)) or ""
  print(string.format("   bobber toy: choice %s, active %s (%s)%s", tostring(choice),
    active and (Compat.GetItemInfo(active) or active) or "none", Seconds(remaining), chosen))

  local next = self:Next()
  print(string.format("   so the next press: %s (%s %s)", tostring(next.label), tostring(next.type),
    tostring(next.value)))
end

function Planner:Next()
  local action = ns.Gear:PoleAction()
  if action and not Snoozed(action.id) then return action end

  action = RaftAction()
  if action and not Snoozed(action.id) then return action end

  action = ns.Lures:Action()
  if action and not Snoozed(action.id) then return action end

  action = ns.Bobbers:OversizedAction()
  if action and not Snoozed(action.id) then return action end

  action = ns.Bobbers:ToyAction()
  if action and not Snoozed(action.id) then return action end

  action = ExtraAction()
  if action then return action end

  return { id = "cast", type = "spell", value = Compat.FishingName(), label = L["Cast"] }
end
