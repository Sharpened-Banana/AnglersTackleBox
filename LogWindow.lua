-- Catch log view (/tb log, the menu's Catch Log compartment): catches per zone
-- with share of the zone's catch, current value and source pools.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Window = {}
ns.LogWindow = Window

local ROW_HEIGHT = 16
local COLUMNS = {
  { key = "name", x = 4, width = 200, justify = "LEFT" },
  { key = "count", x = 208, width = 50, justify = "RIGHT" },
  { key = "share", x = 262, width = 50, justify = "RIGHT" },
  { key = "value", x = 316, width = 90, justify = "RIGHT" },
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

-- Builds the view inside a menu panel.
function Window:Attach(frame)
  self.frame = frame
  frame.zone = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.zone:SetPoint("TOP", 0, -6)

  local function Arrow(text, point, x, step)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(28, 22)
    button:SetPoint(point, x, 0)
    button:SetText(text)
    button:SetScript("OnClick", function()
      Window.index = (Window.index or 1) + step
      Window:Refresh()
    end)
    return button
  end
  frame.prev = Arrow("<", "TOPLEFT", 0, -1)
  frame.next = Arrow(">", "TOPRIGHT", 0, 1)

  local headers = { name = L["Catch"], count = L["Count"], share = L["Share"], value = L["Value"] }
  for _, column in ipairs(COLUMNS) do
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", column.x, -30)
    text:SetWidth(column.width)
    text:SetJustifyH(column.justify)
    text:SetText(headers[column.key])
  end

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 0, -46)
  frame.scroll:SetPoint("BOTTOMRIGHT", -24, 36)
  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(410, ROW_HEIGHT)
  frame.scroll:SetScrollChild(frame.content)
  frame.rows = {}

  frame.total = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  local export = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  export:SetSize(90, 20)
  export:SetPoint("BOTTOMRIGHT", -2, 14)
  export:SetText(L["Export CSV"])
  export:SetScript("OnClick", function() Window:ShowExport() end)

  -- Forget confirms with a second click, not a popup.
  local forget = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  forget:SetSize(110, 20)
  forget:SetPoint("RIGHT", export, "LEFT", -4, 0)
  forget:SetScript("OnClick", function(button)
    local zone = Zones()[Window.index or 1]
    if not zone then return end
    if button.armedFor == zone.mapID and GetTime() < (button.armedUntil or 0) then
      ns.Log:ForgetZone(zone.mapID)
      button.armedFor = nil
    else
      button.armedFor, button.armedUntil = zone.mapID, GetTime() + 5
    end
    Window:Refresh()
  end)
  frame.forget = forget

  frame.total:SetPoint("BOTTOMLEFT", 4, 16)
  frame.allTime = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.allTime:SetPoint("BOTTOMLEFT", 4, 0)
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

  local forget = frame.forget
  local current = zones[self.index or 1]
  local armed = current and forget.armedFor == current.mapID and GetTime() < (forget.armedUntil or 0)
  forget:SetText(armed and L["Really forget?"] or L["Forget zone"])
  forget:SetEnabled(current ~= nil)

  for index = used + 1, #frame.rows do SetRow(frame.rows[index]) end
  frame.content:SetHeight(math.max(ROW_HEIGHT, used * ROW_HEIGHT))
  frame.prev:SetEnabled(#zones > 1)
  frame.next:SetEnabled(#zones > 1)

  local casts, catches, value, seconds = AllTime()
  frame.allTime:SetText(string.format(L["All saved sessions: %d casts, %d catches, %s in %s."],
    casts, catches, Compat.CoinString(value), ns.FormatTime(seconds)))
end

-- Addons can't write files, so the CSV export is a selectable text box to copy from.
function Window:ShowExport()
  local box = self.export
  if not box then
    box = CreateFrame("Frame", "AnglersTackleBoxExport", UIParent, "BackdropTemplate")
    box:SetSize(520, 320)
    box:SetPoint("CENTER")
    box:SetFrameStrata("DIALOG")
    box:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0.04, 0.08, 0.06, 0.97)
    table.insert(UISpecialFrames, "AnglersTackleBoxExport")
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.title:SetPoint("TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, box, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    box.edit = CreateFrame("EditBox", nil, scroll)
    box.edit:SetMultiLine(true)
    box.edit:SetAutoFocus(false)
    box.edit:SetFontObject("ChatFontSmall")
    box.edit:SetWidth(470)
    box.edit:SetScript("OnEscapePressed", function() box:Hide() end)
    scroll:SetScrollChild(box.edit)
    self.export = box
  end
  local text, count = ns.Log:ExportCSV()
  box.title:SetText(string.format(L["%d rows - press Ctrl+C (Cmd+C on a Mac) to copy"], count))
  box.edit:SetText(text)
  box:Show()
  box.edit:SetFocus()
  box.edit:HighlightText()
end

-- Start on the zone the player is standing in, when it has catches.
function Window:ShowHere()
  local here = C_Map and C_Map.GetBestMapForUnit("player")
  for index, zone in ipairs(Zones()) do
    if zone.mapID == here then self.index = index end
  end
  self:Refresh()
end
