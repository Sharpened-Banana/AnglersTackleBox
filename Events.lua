-- Events Clock: countdowns to the fishing contests and, on Classic Era, the
-- time-of-day fish windows. All times are realm time. Nothing here runs
-- unless fishing mode is on or the player asks with /tb events.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Events = ns:NewModule("Events")

local DAY, WEEK = 1440, 10080
local REMIND_BEFORE = 15 -- minutes

-- weekday: 1 = Sunday ... 7 = Saturday, nil = every day. Minutes from midnight.
local SCHEDULE = {
  { name = L["Stranglethorn Fishing Extravaganza"], weekday = 1, start = 14 * 60, stop = 16 * 60 },
}
if Compat.isRetail then
  table.insert(SCHEDULE, { name = L["Hallowfall Fishing Derby"], weekday = 7, start = 0, stop = DAY })
end
if Compat.isClassicEra then
  table.insert(SCHEDULE, { name = L["Sunscale Salmon window"], start = 6 * 60, stop = 12 * 60, quiet = true })
  table.insert(SCHEDULE, { name = L["Nightfin Snapper window"], start = 18 * 60, stop = DAY, quiet = true })
end

local function RealmNow()
  local hour, minute = GetGameTime()
  local weekday
  if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    weekday = C_DateAndTime.GetCurrentCalendarTime().weekday
  else
    weekday = tonumber(date("%w")) + 1
  end
  return weekday, hour * 60 + minute
end

-- Returns active (bool) and minutes: left when active, until start otherwise.
local function Status(event, weekday, minute)
  local period = event.weekday and WEEK or DAY
  local daysAhead = event.weekday and ((event.weekday - weekday) % 7) or 0
  local untilStart = daysAhead * DAY + event.start - minute
  if untilStart <= 0 then
    if daysAhead == 0 and minute < event.stop then
      return true, event.stop - minute
    end
    untilStart = untilStart + period
  end
  return false, untilStart
end

local function Duration(minutes)
  if minutes >= DAY then
    return string.format(L["%dd %dh"], math.floor(minutes / DAY), math.floor(minutes % DAY / 60))
  elseif minutes >= 60 then
    return string.format(L["%dh %dm"], math.floor(minutes / 60), minutes % 60)
  end
  return string.format(L["%dm"], minutes)
end

-- The event worth showing: whatever is running, else whatever starts next.
function Events:Headline()
  local weekday, minute = RealmNow()
  local best, bestActive, bestMinutes
  for _, event in ipairs(SCHEDULE) do
    local active, minutes = Status(event, weekday, minute)
    local better = best == nil
      or (active and not bestActive)
      or (active == bestActive and minutes < bestMinutes)
    if better then best, bestActive, bestMinutes = event, active, minutes end
  end
  if not best then return nil end
  if bestActive then
    return string.format(L["%s: %s left"], best.name, Duration(bestMinutes))
  end
  return string.format(L["%s in %s"], best.name, Duration(bestMinutes))
end

function Events:Print()
  local weekday, minute = RealmNow()
  ns:Print(L["Fishing events (realm time):"])
  for _, event in ipairs(SCHEDULE) do
    local active, minutes = Status(event, weekday, minute)
    if active then
      print(string.format("   |cff40ff40%s|r - " .. L["on now, %s left"], event.name, Duration(minutes)))
    else
      print(string.format("   %s - " .. L["starts in %s"], event.name, Duration(minutes)))
    end
  end
end

function Events:Enable()
  self.said = {}
  self.nextCheck = 0
end

-- Reminders while fishing: once shortly before a contest and once at its start.
function Events:Tick()
  if not ns.db.eventAlerts then return end
  local now = GetTime()
  if now < (self.nextCheck or 0) then return end
  self.nextCheck = now + 30

  local weekday, minute = RealmNow()
  for index, event in ipairs(SCHEDULE) do
    if not event.quiet then
      local active, minutes = Status(event, weekday, minute)
      if active then
        if not self.said[index .. "start"] then
          self.said[index .. "start"] = true
          ns.HUD:Alert(string.format(L["%s is on!"], event.name))
        end
      elseif minutes <= REMIND_BEFORE then
        if not self.said[index .. "soon"] then
          self.said[index .. "soon"] = true
          ns.HUD:Alert(string.format(L["%s starts in %s."], event.name, Duration(minutes)))
        end
      else
        self.said[index .. "start"], self.said[index .. "soon"] = nil, nil
      end
    end
  end
end
