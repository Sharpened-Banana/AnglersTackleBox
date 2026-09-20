-- Catch log window: what you have caught in each zone, with share of the
-- zone's catch, current value and the pools it came from. Built the first
-- time it is opened (/tb log).
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Window = {}
ns.LogWindow = Window

local WIDTH, HEIGHT, ROW_HEIGHT = 480, 440, 16
local COLUMNS = {
  { key = "name", x = 8, width = 230, justify = "LEFT" },
  { key = "count", x = 245, width = 55, justify = "RIGHT" },
  { key = "share", x = 305, width = 50, justify = "RIGHT" },
  { key = "value", x = 360, width = 90, justify = "RIGHT" },
}

local function MapName(mapID)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or string.format(L["Map %d"], mapID)
end

-- Zones with catches, by name.
local function Zones()
  local zones = {}
  for mapID in pairs(ns.chardb.log) do
    zones[#zones + 1] = { mapID = mapID, name = MapName(mapID) }
  end
  table.sort(zones, function(a, b) return a.name < b.name end)
  return zones
end

local function AllTime()
  local casts, catches, value, seconds = 0, 0, 0, 0
  for _, day in pairs(ns.chardb.daily) do
    casts, catches = casts + day.casts, catches + day.catches
    value, seconds = value + day.value, seconds + (day.seconds or 0)
  end
  for _, session in ipairs(ns.chardb.sessions) do
    casts, catches = casts + session.casts, catches + session.catches
    value, seconds = value + session.value, seconds + math.max(0, session.stop - session.start)
  end
  return casts, catches, value, seconds
end

local function Row(frame, index)
  local row = frame.rows[index]
  if row then return row end
  row = {}
  for _, column in ipairs(COLUMNS) do
    local text = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", column.x, -(index - 1) * ROW_HEIGHT)
    text:SetWidth(column.width)
    text:SetJustifyH(column.justify)
    text:SetWordWrap(false)
    row[column.key] = text
  end
  frame.rows[index] = row
  return row
end

local function SetRow(row, name, count, share, value)
  row.name:SetText(name or "")
  row.count:SetText(count or "")
  row.share:SetText(share or "")
  row.value:SetText(value or "")
end

local function Build()
  local frame = CreateFrame("Frame", "TackleboxLogWindow", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  table.insert(UISpecialFrames, "TackleboxLogWindow") -- Escape closes it

  local title = frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText)
  if type(title) == "table" then title:SetText(L["Tacklebox catch log"]) end

  frame.zone = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.zone:SetPoint("TOP", 0, -34)

  local function Arrow(text, point, x, step)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(28, 22)
    button:SetPoint(point, x, -30)
    button:SetText(text)
    button:SetScript("OnClick", function()
      Window.index = (Window.index or 1) + step
      Window:Refresh()
    end)
    return button
  end
  frame.prev = Arrow("<", "TOPLEFT", 14, -1)
  frame.next = Arrow(">", "TOPRIGHT", -14, 1)

  local headers = { name = L["Catch"], count = L["Count"], share = L["Share"], value = L["Value"] }
  for _, column in ipairs(COLUMNS) do
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", 12 + column.x, -62)
    text:SetWidth(column.width)
    text:SetJustifyH(column.justify)
    text:SetText(headers[column.key])
  end

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 12, -80)
  frame.scroll:SetPoint("BOTTOMRIGHT", -32, 50)
  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(WIDTH - 50, ROW_HEIGHT)
  frame.scroll:SetScrollChild(frame.content)
  frame.rows = {}

  frame.total = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.total:SetPoint("BOTTOMLEFT", 14, 30)
  frame.allTime = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.allTime:SetPoint("BOTTOMLEFT", 14, 14)
  frame:Hide() -- new frames start shown; Toggle decides
  return frame
end

function Window:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then return end

  local zones = Zones()
  local used = 0
  if #zones == 0 then
    frame.zone:SetText(L["Nothing caught yet"])
    frame.total:SetText("")
  else
    self.index = ((self.index or 1) - 1) % #zones + 1
    local zone = zones[self.index]
    frame.zone:SetText(string.format("%s  (%d/%d)", zone.name, self.index, #zones))

    local items, zoneCount, zoneValue = {}, 0, 0
    for itemID, entry in pairs(ns.chardb.log[zone.mapID]) do
      local value = ns.Log.UnitValue(itemID) * entry.count
      items[#items + 1] = { id = itemID, entry = entry, value = value }
      zoneCount, zoneValue = zoneCount + entry.count, zoneValue + value
    end
    table.sort(items, function(a, b) return a.entry.count > b.entry.count end)

    for _, item in ipairs(items) do
      local entry = item.entry
      used = used + 1
      SetRow(Row(frame, used), entry.name or ("item:" .. item.id), tostring(entry.count),
        string.format("%.1f%%", entry.count / zoneCount * 100), Compat.CoinString(item.value))
      if entry.pools then
        local parts = {}
        for pool, count in pairs(entry.pools) do parts[#parts + 1] = string.format("%s %d", pool, count) end
        table.sort(parts)
        used = used + 1
        SetRow(Row(frame, used), "|cff808080   " .. table.concat(parts, ", ") .. "|r")
      end
    end
    frame.total:SetText(string.format(L["This zone: %d fish of %d kinds, worth %s now."],
      zoneCount, #items, Compat.CoinString(zoneValue)))
  end

  for index = used + 1, #frame.rows do SetRow(frame.rows[index]) end
  frame.content:SetHeight(math.max(ROW_HEIGHT, used * ROW_HEIGHT))
  frame.prev:SetEnabled(#zones > 1)
  frame.next:SetEnabled(#zones > 1)

  local casts, catches, value, seconds = AllTime()
  frame.allTime:SetText(string.format(L["All saved sessions: %d casts, %d catches, %s in %s."],
    casts, catches, Compat.CoinString(value), ns.FormatTime(seconds)))
end

function Window:Toggle()
  if not self.frame then self.frame = Build() end
  if self.frame:IsShown() then
    self.frame:Hide()
    return
  end
  -- Open on the zone the player is standing in, when it has catches.
  local here = C_Map and C_Map.GetBestMapForUnit("player")
  for index, zone in ipairs(Zones()) do
    if zone.mapID == here then self.index = index end
  end
  self.frame:Show()
  self:Refresh()
end
