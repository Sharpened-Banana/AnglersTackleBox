-- Events Clock: countdowns to the fishing contests, the Derby Dasher timer
-- and, on Classic Era, the time-of-day and seasonal fish. All times are realm time. Nothing here runs
-- unless fishing mode is on or the player asks with /tb events.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Events = ns:NewModule("Events")

local DAY, WEEK = 1440, 10080
local REMIND_BEFORE = 15 -- minutes
local DASHER_WARNING = 300 -- seconds

-- weekday: 1 = Sunday ... 7 = Saturday, nil = every day. Minutes from midnight.
local SCHEDULE = {
  { name = L["Stranglethorn Fishing Extravaganza"], weekday = 1, start = 14 * 60, stop = 16 * 60 },
}
if Compat.isRetail then
  table.insert(SCHEDULE, { name = L["Hallowfall Fishing Derby"], weekday = 7, start = 0, stop = DAY })
end
if Compat.isClassicEra then
  -- Best hours. Nightfin never drops 12:00-18:00, Sunscale never 00:00-06:00.
  table.insert(SCHEDULE, { name = L["Nightfin Snapper peak"], start = 0, stop = 6 * 60, quiet = true })
  table.insert(SCHEDULE, { name = L["Sunscale Salmon peak"], start = 12 * 60, stop = 18 * 60, quiet = true })
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

-- Seconds left on the Hallowfall derby's one-hour buff, nil without it.
local function DasherRemaining()
  local spellID = Data.spells.derbyDasher
  local remaining = spellID and Compat.AuraRemaining(spellID)
  if remaining and remaining ~= math.huge then return remaining end
end

-- The event worth showing: a running derby timer first, then whatever is
-- on, else whatever starts next.
function Events:Headline()
  local dasher = DasherRemaining()
  if dasher then
    return string.format(L["Derby Dasher: %s left"], ns.FormatTime(dasher))
  end
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

function Events:Lines()
  local weekday, minute = RealmNow()
  local lines = { { text = L["Fishing events (realm time):"], header = true } }
  local dasher = DasherRemaining()
  if dasher then
    lines[#lines + 1] = {
      text = string.format("|cff40ff40" .. L["Derby Dasher: %s left"] .. "|r", ns.FormatTime(dasher)),
    }
  end
  for _, event in ipairs(SCHEDULE) do
    local active, minutes = Status(event, weekday, minute)
    if active then
      lines[#lines + 1] = {
        text = string.format("|cff40ff40%s|r - " .. L["on now, %s left"], event.name, Duration(minutes)),
      }
    else
      lines[#lines + 1] = { text = string.format("%s - " .. L["starts in %s"], event.name, Duration(minutes)) }
    end
  end
  if Compat.isClassicEra then
    local month = tonumber(date("%m"))
    local inSeason = (month >= 9 or month <= 3) and L["Winter Squid (September to March)"]
      or L["Raw Summer Bass (April to August)"]
    lines[#lines + 1] = { text = string.format(L["In season: %s"], inSeason) }
  end
  return lines
end

function Events:Print()
  ns:PrintLines(self:Lines())
end

function Events:Enable()
  self.said = {}
  self.nextCheck = 0
end

-- Reminders while fishing: once shortly before a contest and once at its start.
function Events:Tick()
  if not ns.db.eventAlerts then return end

  local dasher = DasherRemaining()
  if not dasher then
    self.dasherWarned = nil
  elseif dasher <= DASHER_WARNING and not self.dasherWarned then
    self.dasherWarned = true
    ns.Alerts:Fire("event", string.format(L["Derby Dasher runs out in %s!"], ns.FormatTime(dasher)))
  end

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
          ns.Alerts:Fire("event", string.format(L["%s is on!"], event.name))
        end
      elseif minutes <= REMIND_BEFORE then
        if not self.said[index .. "soon"] then
          self.said[index .. "soon"] = true
          ns.Alerts:Fire("event", string.format(L["%s starts in %s."], event.name, Duration(minutes)))
        end
      else
        self.said[index .. "start"], self.said[index .. "soon"] = nil, nil
      end
    end
  end
end
