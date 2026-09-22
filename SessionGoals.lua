-- Session goals: targets for catches, gold and minutes fished that the
-- player sets in the box. Each one alerts once per session when reached.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local SessionGoals = ns:NewModule("SessionGoals")

local COPPER_PER_GOLD = 10000

-- In display order. current() reads the live session stats.
local GOALS = {
  { key = "catches", label = L["Catches"],
    current = function(stats) return stats.catches end,
    reached = function(n) return string.format(L["%d catches"], n) end },
  { key = "gold", label = L["Gold"],
    current = function(stats) return math.floor(stats.value / COPPER_PER_GOLD) end,
    reached = function(n) return Compat.CoinString(n * COPPER_PER_GOLD) end },
  { key = "minutes", label = L["Minutes fished"],
    current = function(stats) return math.floor(stats.elapsed / 60) end,
    reached = function(n) return string.format(L["%d minutes fished"], n) end },
}
SessionGoals.goals = GOALS

-- Fired state belongs to one session table. Log makes a new table for every
-- session (mode on, first always-on cast, Reset session), so comparing
-- against it resets the state without hooking each of those paths.
local fired, firedFor = {}, nil

local function Target(key)
  local targets = ns.db.sessionGoals
  return math.max(0, math.floor(tonumber(targets and targets[key]) or 0))
end

local function SyncSession()
  local session = ns.Log.session
  if session ~= firedFor then
    wipe(fired)
    firedFor = session
  end
end

function SessionGoals:Check()
  local stats = ns.Log:Stats()
  if not stats then return end
  SyncSession()
  for _, goal in ipairs(GOALS) do
    local target = Target(goal.key)
    if target > 0 and not fired[goal.key] and goal.current(stats) >= target then
      fired[goal.key] = true
      ns.Alerts:Fire("goal", string.format(L["Session goal reached: %s!"], goal.reached(target)))
    end
  end
end

function SessionGoals:Fired(key)
  SyncSession()
  return fired[key] == true
end

-- One row per active goal: { label, current, target, done }.
function SessionGoals:Progress()
  local stats = ns.Log:Stats()
  local rows = {}
  for _, goal in ipairs(GOALS) do
    local target = Target(goal.key)
    if target > 0 then
      local current = stats and goal.current(stats) or 0
      rows[#rows + 1] = { key = goal.key, label = goal.label, current = current, target = target,
        done = current >= target }
    end
  end
  return rows
end

-- "Catches 34 / 50", green once reached; bare drops the label for rows
-- that already show one.
function SessionGoals:Text(key, bare)
  local target = Target(key)
  if target == 0 then return "|cff808080" .. L["off"] .. "|r" end
  for _, row in ipairs(self:Progress()) do
    if row.key == key then
      local text = string.format("%d / %d", math.min(row.current, row.target), row.target)
      if not bare then text = row.label .. " " .. text end
      return row.done and ("|cff40ff40" .. text .. "|r") or text
    end
  end
end

-- Catches and gold change on loot; minutes only move with the clock.
ns:On("CAST_LOOTED", function() SessionGoals:Check() end)

function SessionGoals:Tick()
  self:Check()
end
