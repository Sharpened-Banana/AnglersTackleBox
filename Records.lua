-- Personal records and the shareable session summary.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Records = {}
ns.Records = Records

local MIN_SESSION_SECONDS = 300

local function ZoneName(mapID)
  local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or (GetZoneText() or "?")
end

-- Plain "1,204g" text: chat can't show the coin icons.
local function GoldText(copper)
  local gold = math.floor((copper or 0) / 10000 + 0.5)
  local text = tostring(gold)
  while true do
    local replaced
    text, replaced = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if replaced == 0 then break end
  end
  return text .. "g"
end
Records.GoldText = GoldText

-- Replaces a record when beaten. The first value ever set is not a "new
-- record", so a first session doesn't spray toasts.
local function Beat(key, value, detail, announce)
  local records = ns.chardb.records
  local old = records[key]
  if old and value <= old.value then return end
  records[key] = { value = value, at = time(), detail = detail }
  if old and announce then
    ns.Alerts:Fire("record", string.format(L["New personal record! %s"], announce))
  end
end

ns:On("CATCH", function(_, name, quantity, _, unit)
  local worth = unit * quantity
  if worth > 0 then
    Beat("catch", worth, name, string.format(L["Most valuable catch: %s, %s."], name, GoldText(worth)))
  end
end)

-- Longest run of casts without a rare, measured when the run ends.
ns:On("CAST_LOOTED", function()
  local session = ns.Log.session
  if not session then return end
  if session.sinceRare == 0 and (Records.run or 0) > 0 then
    Beat("dry", Records.run, ZoneName(C_Map and C_Map.GetBestMapForUnit("player")),
      string.format(L["Longest dry streak: %d casts without a rare."], Records.run))
  end
  Records.run = session.sinceRare
end)

ns:On("SESSION_END", function(summary)
  local seconds = math.max(0, summary.stop - summary.start)
  local zone = ZoneName(summary.mapID)
  Beat("sessionValue", summary.value, zone,
    string.format(L["Richest session: %s in %s."], GoldText(summary.value), zone))
  Beat("sessionCatches", summary.catches, zone,
    string.format(L["Most catches in a session: %d in %s."], summary.catches, zone))
  if seconds >= MIN_SESSION_SECONDS then
    local perHour = summary.value / seconds * 3600
    Beat("perHour", perHour, zone,
      string.format(L["Best gold per hour: %s/hr in %s."], GoldText(perHour), zone))
  end
  Records.run = nil
end)

-- Clears the records (all, or just the gold ones that prices can distort).
function Records:Reset(goldOnly)
  local records = ns.chardb.records
  for key in pairs(records) do
    if not goldOnly or key == "sessionValue" or key == "perHour" or key == "catch" then
      records[key] = nil
    end
  end
end

function Records:Lines()
  local records = ns.chardb.records
  local lines = { { text = L["Personal records"], header = true } }
  local function Add(key, format, asGold)
    local record = records[key]
    if record then
      local value = asGold and Compat.CoinString(record.value) or tostring(record.value)
      lines[#lines + 1] = { text = string.format(format, value, record.detail or "?", date("%Y-%m-%d", record.at)) }
    end
  end
  Add("sessionValue", L["Richest session: %s in %s  (%s)"], true)
  Add("perHour", L["Best gold per hour: %s in %s  (%s)"], true)
  Add("sessionCatches", L["Most catches in a session: %s in %s  (%s)"])
  Add("catch", L["Most valuable catch: %s, %s  (%s)"], true)
  Add("dry", L["Longest dry streak: %s casts in %s  (%s)"])
  if #lines == 1 then
    lines[2] = { text = L["Nothing yet - records are set when a session ends."] }
  end
  return lines
end

---------------------------------------------------------------------------
-- Share: post the session to chat. Always from a click or slash command,
-- which is what the game requires for sending chat.
---------------------------------------------------------------------------

function Records:Summary()
  local stats = ns.Log:Stats()
  if not stats or stats.casts == 0 then return nil end
  local text = string.format(L["Angler's TackleBox: %d casts, %d catches, %s"], stats.casts, stats.catches,
    GoldText(stats.value))
  if stats.perHour > 0 then
    text = text .. string.format(L[" (%s/hr)"], GoldText(stats.perHour))
  end
  return text .. string.format(L[" in %s."], GetZoneText() or "?")
end

function Records:Share(channel)
  local text = self:Summary()
  if not text then
    ns:Print(L["Nothing to share yet - fish first."])
    return
  end
  channel = channel and channel:upper() or ""
  if channel == "" then
    channel = IsInGroup() and "PARTY" or (IsInGuild() and "GUILD" or "SAY")
  elseif channel == "P" then channel = "PARTY"
  elseif channel == "G" then channel = "GUILD"
  elseif channel == "S" then channel = "SAY"
  end
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  send(text, channel)
end
