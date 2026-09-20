-- Decides what the next keypress should do. It only ever describes one
-- action; the Engine points the key at it and the player's press does it.
-- Combat, death and mounts are handled by the Engine before this is asked.
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

-- A prep action that keeps being pressed without taking effect would block
-- casting forever, so it gets set aside for a while instead.
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
  -- Start the raft when swimming; otherwise only keep a running raft alive,
  -- so fishing from the shore never burns it.
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

function Planner:Next()
  local action = ns.Gear:PoleAction()
  if action and not Snoozed(action.id) then return action end

  action = RaftAction()
  if action and not Snoozed(action.id) then return action end

  action = ns.Lures:Action()
  if action and not Snoozed(action.id) then return action end

  action = ExtraAction()
  if action then return action end

  return { id = "cast", type = "spell", value = Compat.FishingName(), label = L["Cast"] }
end
