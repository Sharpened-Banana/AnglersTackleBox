-- Session goals (catches, gold, minutes): each alerts once per session when reached.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local SessionGoals = ns:NewModule("SessionGoals")

local COPPER_PER_GOLD = 10000

-- In display order. current() reads the live session stats.
local GOALS = {
  { key = "catches", label = L["Catches"],
    current = function(stats) return stats.catches end,
    reached = function(n) return string.format(L["%d catches"], n) end },
  { key = "gold", label = L["Gold"], money = true, -- saved in gold, possibly a fraction; compared in copper
    current = function(stats) return math.floor(stats.value) end,
    reached = function(n) return Compat.CoinString(n) end,
    show = function(n) return ns.Records.GoldText(n) end },
  { key = "minutes", label = L["Minutes fished"],
    current = function(stats) return math.floor(stats.elapsed / 60) end,
    reached = function(n) return string.format(L["%d minutes fished"], n) end },
}
SessionGoals.goals = GOALS

-- Fired state lives on the session, so a new session starts clean and a
-- /reload remembers which goals already alerted.
local fired = {}

local function Target(goal)
  local targets = ns.db.sessionGoals
  local target = tonumber(targets and targets[goal.key]) or 0
  if goal.money then target = target * COPPER_PER_GOLD + 0.5 end
  return math.max(0, math.floor(target))
end

local function SyncSession()
  local session = ns.Log.session
  if session then
    session.goalsFired = session.goalsFired or {}
    fired = session.goalsFired
  else
    fired = {}
  end
end

function SessionGoals:Check()
  local stats = ns.Log:Stats()
  if not stats then return end
  SyncSession()
  for _, goal in ipairs(GOALS) do
    local target = Target(goal)
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
    local target = Target(goal)
    if target > 0 then
      local current = stats and goal.current(stats) or 0
      rows[#rows + 1] = { key = goal.key, label = goal.label, current = current, target = target,
        done = current >= target, show = goal.show or tostring }
    end
  end
  return rows
end

-- "Catches 34 / 50", green once reached; bare omits the label.
function SessionGoals:Text(key, bare)
  for _, row in ipairs(self:Progress()) do
    if row.key == key then
      local text = row.show(math.min(row.current, row.target)) .. " / " .. row.show(row.target)
      if not bare then text = row.label .. " " .. text end
      return row.done and ("|cff40ff40" .. text .. "|r") or text
    end
  end
  return "|cff808080" .. L["off"] .. "|r"
end

-- Catches and gold change on loot; minutes only move with the clock.
ns:On("CAST_LOOTED", function() SessionGoals:Check() end)

function SessionGoals:Tick()
  self:Check()
end
