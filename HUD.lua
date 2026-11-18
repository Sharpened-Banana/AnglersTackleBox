-- The Fishing Companion (the session window): Session tab first, then the player's picks from HUD.catalog.
-- Built on first use, so a character that never fishes never pays for it.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local HUD = ns:NewModule("HUD")

local WIDTH, ROW_COUNT, ROW_HEIGHT = 250, 6, 16
local TAB_HEIGHT, FOOTER_HEIGHT = 18, 16
local HEADER, CAST_BAR, NEXT_HEIGHT, PAD = 24, 3, 18, 4
local TABS_TOP = PAD + HEADER + CAST_BAR + 4
local ROWS_TOP = TABS_TOP + TAB_HEIGHT + 4
local FULL_HEIGHT = ROWS_TOP + ROW_COUNT * ROW_HEIGHT + 4 + NEXT_HEIGHT + 2 + FOOTER_HEIGHT + 6
local COMPACT_HEIGHT = PAD + HEADER + CAST_BAR + 4 + NEXT_HEIGHT + 6
local SOLID = "Interface\\Buttons\\WHITE8x8"
local FADE_IN, PULSE = 0.25, 0.6
local MAX_TABS = 5 -- Session plus four
HUD.MAX_TABS = MAX_TABS

-- The state pill's colour: what the key is doing, at a glance.
local STATE_COLOR = {
  READY = ns.Theme.C.brass,
  PREP = { 1, 0.6, 0.1 },
  CHANNELING = { 0.25, 0.8, 0.35 },
  LOOTING = { 0.3, 0.6, 1 },
  PAUSED = { 0.5, 0.5, 0.5 },
}

local STATE_TEXT = {
  READY = L["Ready"],
  PREP = L["Prep"],
  CHANNELING = L["Fishing"],
  LOOTING = L["Looting"],
  PAUSED = L["Paused"],
}

local function SavePosition(frame)
  local point, _, relativePoint, x, y = frame:GetPoint()
  ns.db.hud.pos = { point, relativePoint, x, y }
end

local function Solid(parent, layer)
  local texture = parent:CreateTexture(nil, layer)
  texture:SetTexture(SOLID)
  return texture
end

local function Build()
  local Theme, C = ns.Theme, ns.Theme.C
  local frame = CreateFrame("Frame", "AnglersTackleBoxHUD", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, FULL_HEIGHT)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(C.hud[1], C.hud[2], C.hud[3], ns.db.hud.alpha or 0.7)
  Theme:Paint(frame, "SetBackdropBorderColor", C.brass, 0.8)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not ns.db.hud.locked then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
  end)

  local pos = ns.db.hud.pos
  if pos then
    frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 320, -120)
  end

  -- Header strip: icon, title, the state as a pill, the X.
  local header = Solid(frame, "BORDER")
  Theme:Paint(header, "SetVertexColor", C.lid, 0.9)
  header:SetPoint("TOPLEFT", PAD, -PAD)
  header:SetPoint("TOPRIGHT", -PAD, -PAD)
  header:SetHeight(HEADER)
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\Trade_Fishing")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetSize(16, 16)
  icon:SetPoint("TOPLEFT", PAD + 4, -PAD - 4)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  frame.title:SetText(L["Fishing Companion"])
  Theme:Paint(frame.title, "SetTextColor", C.title)

  -- The X hides the window until the next cast; /tb hud hides it for good.
  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetSize(22, 22)
  frame.close:SetPoint("TOPRIGHT", -2, -PAD - 1)
  frame.close:SetScript("OnClick", function() HUD:Dismiss() end)
  frame.close:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Hide until your next cast"])
    GameTooltip:Show()
  end)
  frame.close:SetScript("OnLeave", function() GameTooltip:Hide() end)

  frame.pill = Solid(frame, "ARTWORK")
  frame.pill:SetSize(58, 14)
  frame.pill:SetPoint("TOPRIGHT", -26, -PAD - 5)
  frame.state = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.state:SetPoint("CENTER", frame.pill, "CENTER", 0, 0)

  -- Cast bar: drains while the line is out.
  local groove = Solid(frame, "BORDER")
  groove:SetVertexColor(0, 0, 0, 0.5)
  groove:SetPoint("TOPLEFT", PAD, -PAD - HEADER)
  groove:SetPoint("TOPRIGHT", -PAD, -PAD - HEADER)
  groove:SetHeight(CAST_BAR)
  frame.cast = Solid(frame, "ARTWORK")
  Theme:Paint(frame.cast, "SetVertexColor", C.brass)
  frame.cast:SetPoint("TOPLEFT", PAD, -PAD - HEADER)
  frame.cast:SetHeight(CAST_BAR)
  frame.cast:Hide()

  -- Tab button pool; Refresh lays out however many tabs are chosen.
  frame.tabs = {}
  for index = 1, MAX_TABS do
    local button = CreateFrame("Button", nil, frame)
    button.back = Solid(button, "BACKGROUND")
    button.back:SetPoint("TOPLEFT", 1, 0)
    button.back:SetPoint("BOTTOMRIGHT", -1, 0)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", 2, 0)
    button.text:SetPoint("RIGHT", -2, 0)
    button.text:SetWordWrap(false)
    button.line = Solid(button, "ARTWORK")
    Theme:Paint(button.line, "SetVertexColor", C.brass)
    button.line:SetPoint("TOPLEFT", 1, 0)
    button.line:SetPoint("TOPRIGHT", -1, 0)
    button.line:SetHeight(2)
    button:SetScript("OnClick", function(self)
      ns.db.hud.tab = self.key
      HUD:Refresh()
    end)
    frame.tabs[index] = button
  end

  -- Session's two headline numbers, standing where rows 1 and 2 are on other tabs.
  frame.hero = CreateFrame("Frame", nil, frame)
  frame.hero:SetPoint("TOPLEFT", 10, -ROWS_TOP)
  frame.hero:SetSize(WIDTH - 20, ROW_HEIGHT * 2)
  frame.hero.cells = {}
  for index = 1, 2 do
    local cell = {}
    cell.value = frame.hero:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cell.value:SetPoint("TOPLEFT", (index - 1) * (WIDTH - 20) / 2, 0)
    cell.value:SetWidth((WIDTH - 20) / 2)
    cell.value:SetJustifyH("LEFT")
    cell.value:SetWordWrap(false)
    cell.value:SetTextColor(1, 1, 1)
    cell.caption = frame.hero:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cell.caption:SetPoint("TOPLEFT", cell.value, "BOTTOMLEFT", 0, -1)
    cell.caption:SetWidth((WIDTH - 20) / 2)
    cell.caption:SetJustifyH("LEFT")
    cell.caption:SetWordWrap(false)
    Theme:Paint(cell.caption, "SetTextColor", C.label)
    frame.hero.cells[index] = cell
  end
  frame.hero:Hide()

  -- Rows are buttons so a tab can make them clickable (picking a lure).
  frame.rows = {}
  for index = 1, ROW_COUNT do
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(WIDTH - 20, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 10, -ROWS_TOP - (index - 1) * ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 3, ROW_HEIGHT - 3)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:Hide()
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.left:SetPoint("LEFT")
    row.left:SetWidth(WIDTH - 90)
    row.left:SetJustifyH("LEFT")
    row.left:SetWordWrap(false)
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT")
    -- A thin gauge along the row's foot, for a timer running down.
    row.bar = Solid(row, "BACKGROUND")
    Theme:Paint(row.bar, "SetVertexColor", C.brass, 0.7)
    row.bar:SetPoint("BOTTOMLEFT")
    row.bar:SetHeight(2)
    row.bar:Hide()
    row:SetHighlightTexture(SOLID)
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
    row:SetScript("OnClick", function(self)
      if self.onClick then
        self.onClick()
        HUD:Refresh()
      end
    end)
    row:SetScript("OnEnter", function(self)
      if not self.tooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      self.tooltip(GameTooltip)
      if (GameTooltip:NumLines() or 0) > 0 then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.rows[index] = row
  end

  -- What the fishing key does next: the line that matters most, on every tab.
  frame.next = CreateFrame("Frame", nil, frame)
  frame.next:SetHeight(NEXT_HEIGHT)
  local wash = Solid(frame.next, "BACKGROUND")
  Theme:Paint(wash, "SetVertexColor", C.brass, 0.15)
  wash:SetAllPoints()
  local edge = Solid(frame.next, "BORDER")
  Theme:Paint(edge, "SetVertexColor", C.brass)
  edge:SetPoint("TOPLEFT")
  edge:SetPoint("BOTTOMLEFT")
  edge:SetWidth(2)
  frame.next.label = frame.next:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.next.label:SetPoint("LEFT", 8, 0)
  frame.next.label:SetText(L["Next press"])
  Theme:Paint(frame.next.label, "SetTextColor", C.label)
  frame.next.value = frame.next:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.next.value:SetPoint("RIGHT", -6, 0)

  -- Footer: the event line on Session, a link into the box elsewhere.
  frame.footer = CreateFrame("Button", nil, frame)
  frame.footer:SetPoint("BOTTOMLEFT", 10, 6)
  frame.footer:SetPoint("BOTTOMRIGHT", -10, 6)
  frame.footer:SetHeight(FOOTER_HEIGHT)
  frame.footer.text = frame.footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.footer.text:SetPoint("LEFT")
  frame.footer.text:SetPoint("RIGHT")
  frame.footer.text:SetJustifyH("LEFT")
  frame.footer.text:SetWordWrap(false)
  frame.footer:SetScript("OnClick", function(self)
    if self.compartment then ns.Menu:Open(self.compartment) end
  end)

  -- A wash over the whole window that flares on a catch and dies away.
  frame.pulse = Solid(frame, "OVERLAY")
  Theme:Paint(frame.pulse, "SetVertexColor", C.brass, 0)
  frame.pulse:SetPoint("TOPLEFT", PAD, -PAD)
  frame.pulse:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  frame.pulse:Hide()

  frame:SetScript("OnUpdate", function(self) ns.Safe(HUD.Animate, HUD, self) end)
  return frame
end

local ROW_COLORS = { gold = ns.Theme.C.label, green = { 0.25, 1, 0.25 }, white = { 1, 1, 1 } }

-- "style" is true/"green", "white", or nil for the default gold. "tooltip" fills GameTooltip on hover.
local function SetRow(row, left, right, onClick, style, tooltip)
  row.left:SetText(left or "")
  row.right:SetText(right or "")
  row.left:SetWidth((right == nil or right == "") and (WIDTH - 20) or (WIDTH - 90))
  row.onClick, row.tooltip = onClick, tooltip
  row:EnableMouse(onClick ~= nil or tooltip ~= nil)
  local color = ROW_COLORS[style == true and "green" or style or "gold"] or ROW_COLORS.gold
  row.left:SetTextColor(color[1], color[2], color[3])
  -- Icon and gauge are per fill: cleared here, set again by RowIcon and RowGauge.
  row.icon:Hide()
  row.bar:Hide()
  row.left:SetPoint("LEFT", 0, 0)
end

local function RowIcon(row, texture)
  if not texture then return end
  row.icon:SetTexture(texture)
  row.icon:Show()
  row.left:SetPoint("LEFT", ROW_HEIGHT, 0)
end

-- fraction is 0..1 of the row's width; nil hides the gauge.
local function RowGauge(row, fraction)
  if not fraction then return end
  row.bar:SetWidth(math.max(1, (WIDTH - 20) * math.max(0, math.min(1, fraction))))
  row.bar:Show()
end

local function ItemIcon(itemID)
  return itemID and Compat.ItemIcon(itemID) or nil
end

-- What the key does next, for the strip under the rows.
local function NextPress()
  if not ns.db.key and not ns.db.doubleClick then return "|cffff5555/tb bind|r" end
  return ns.Engine.nextLabel or ""
end

local function ItemName(itemID)
  return (Compat.GetItemInfo(itemID)) or ("item:" .. itemID)
end

local function LureStatus(itemID)
  local remaining = ns.Lures:Remaining(itemID)
  if remaining == math.huge then return L["Active"] end
  if remaining then return ns.FormatTime(remaining) end
  return L["Not applied"]
end

local fill = {}

function fill.session(frame)
  local rows = frame.rows
  local stats = ns.Log:Stats()
  local cells = frame.hero.cells
  frame.hero:Show()
  SetRow(rows[1])
  SetRow(rows[2])
  if stats then
    cells[1].value:SetText(string.format("%d / %d", stats.catches, stats.casts))
    cells[1].caption:SetText(string.format(L["Catches (%d%%)"], math.floor(stats.rate * 100 + 0.5)))
    -- The hourly rate is noise until a minute of fishing is behind it.
    cells[2].value:SetText(stats.perHour > 0 and Compat.CoinString(stats.perHour) or "-")
    cells[2].caption:SetText(L["Gold per hour"])
    SetRow(rows[3], L["Session gold"], Compat.CoinString(stats.value))
    SetRow(rows[4], L["Since rare"], string.format(L["%d casts"], stats.sinceRare))
    SetRow(rows[6], L["Time fishing"], ns.FormatTime(stats.elapsed))
  else
    for index = 1, 2 do
      cells[index].value:SetText("-")
      cells[index].caption:SetText(index == 1 and L["Catches"] or L["Gold per hour"])
    end
    SetRow(rows[3]); SetRow(rows[4]); SetRow(rows[6])
  end

  local lureID = ns.chardb.lureEnabled and ns.Lures:Current()
  SetRow(rows[5], L["Lure"], lureID and LureStatus(lureID) or L["None"])
  if lureID then
    RowIcon(rows[5], ItemIcon(lureID))
    local remaining = ns.Lures:Remaining(lureID)
    if remaining and remaining ~= math.huge and (Data.lureDuration or 0) > 0 then
      RowGauge(rows[5], remaining / Data.lureDuration)
    end
  end
  -- Footer: the event headline, else the catch-rate trend.
  return ns.Events:Headline(true) or ns.Stats.RateText(ns.Log:CatchTrend()) or "", nil
end

-- The lure in use, then the lures in the bags: click one to switch to it.
function fill.lures(frame)
  local rows = frame.rows
  local current = ns.chardb.lureEnabled and ns.Lures:Current() or nil
  if current then
    SetRow(rows[1], ItemName(current), LureStatus(current), nil, true)
    RowIcon(rows[1], ItemIcon(current))
  else
    SetRow(rows[1], ns.chardb.lureEnabled and L["No lure chosen"] or L["Lures are off"])
  end

  local owned, seen = {}, { [current or 0] = true }
  for _, itemID in ipairs(Data.knownLures) do
    if not seen[itemID] and Compat.GetItemCount(itemID) > 0 then
      seen[itemID] = true
      owned[#owned + 1] = itemID
    end
  end
  for index = 2, ROW_COUNT do
    local itemID = owned[index - 1]
    if itemID then
      SetRow(rows[index], ItemName(itemID), "x" .. Compat.GetItemCount(itemID), function()
        ns.chardb.lureID, ns.chardb.lureEnabled = itemID, true
      end)
      RowIcon(rows[index], ItemIcon(itemID))
    elseif index == 2 and #owned == 0 then
      SetRow(rows[index], "|cff808080" .. L["No other lures in your bags"] .. "|r")
    else
      SetRow(rows[index])
    end
  end
  return L["More lure options..."], "lures"
end

-- This session's catches, most caught first.
function fill.log(frame)
  local rows = frame.rows
  local session = ns.Log.session
  local items = {}
  if session then
    for itemID, count in pairs(session.items) do
      items[#items + 1] = { id = itemID, count = count }
    end
    table.sort(items, function(a, b)
      if a.count ~= b.count then return a.count > b.count end
      return a.id < b.id
    end)
  end
  for index = 1, ROW_COUNT do
    local item = items[index]
    if item then
      SetRow(rows[index], ItemName(item.id), string.format("x%d   %s", item.count,
        Compat.CoinString(ns.Log.UnitValue(item.id) * item.count)))
      RowIcon(rows[index], ItemIcon(item.id))
    elseif index == 1 then
      SetRow(rows[index], "|cff808080" .. L["Nothing caught this session yet"] .. "|r")
    else
      SetRow(rows[index])
    end
  end
  if #items > ROW_COUNT then
    return string.format(L["+%d more - full catch log..."], #items - ROW_COUNT), "log"
  end
  return L["Full catch log..."], "log"
end

-- A tab showing the first rows of a report's lines.
local function FromLines(getLines, skipFirstHeader)
  return function(frame)
    local shown = 0
    for index, line in ipairs(getLines()) do
      if shown < ROW_COUNT and not (skipFirstHeader and index == 1 and line.header) then
        shown = shown + 1
        SetRow(frame.rows[shown], line.text, nil, nil, line.header and "gold" or "white")
      end
    end
    for index = shown + 1, ROW_COUNT do SetRow(frame.rows[index]) end
  end
end

function fill.bobbers(frame)
  local rows = frame.rows
  local active, remaining = ns.Bobbers:Active()
  if active then
    SetRow(rows[1], ItemName(active), remaining == math.huge and L["Active"] or ns.FormatTime(remaining), nil, true)
  else
    SetRow(rows[1], L["Plain bobber"], ns.db.bobber and L["Next press"] or "")
  end
  local choices = { { choice = "random", name = L["Random"] } }
  for _, itemID in ipairs(ns.Bobbers:Owned()) do
    choices[#choices + 1] = { choice = itemID, name = ItemName(itemID) }
  end
  for index = 2, ROW_COUNT do
    local entry = choices[index - 1]
    if entry and #choices > 1 then
      local chosen = ns.db.bobber == entry.choice
      SetRow(rows[index], entry.name, chosen and L["chosen"] or "", function()
        ns.db.bobber = (not chosen) and entry.choice or nil -- click again to clear
        ns.Bobbers.randomPick = nil
      end, chosen and "green" or "white")
    elseif index == 2 then
      SetRow(rows[index], "|cff808080" .. L["No bobber toys in your toy box"] .. "|r")
    else
      SetRow(rows[index])
    end
  end
end

function fill.gold(frame)
  local rows = frame.rows
  local stats = ns.Log:Stats()
  SetRow(rows[1], L["Session gold"], stats and Compat.CoinString(stats.value) or "-")
  SetRow(rows[2], L["Gold per hour"], stats and stats.perHour > 0 and Compat.CoinString(stats.perHour) or "-")

  local spot = ns.Spots.lastSpot
  local _, spotRate = nil, nil
  if spot then _, spotRate = ns.Spots.Value(spot) end
  SetRow(rows[3], L["This spot"], spotRate and (Compat.CoinString(spotRate) .. L["/hr"]) or "-")

  local best = ns.Gold:Zones()[1]
  if best then
    local info = C_Map.GetMapInfo(best.mapID)
    SetRow(rows[4], L["Best zone"], info and info.name or "?")
    SetRow(rows[5], "", Compat.CoinString(best.perHour) .. L["/hr"])
  else
    SetRow(rows[4], L["Best zone"], "-")
    SetRow(rows[5])
  end
  local record = ns.chardb.records.perHour
  SetRow(rows[6], L["Your record"], record and (Compat.CoinString(record.value) .. L["/hr"]) or "-")
end

-- The Briny Best: warband score, this zone's total against its maximum, then this session's journal
-- fish, newest catch first, with the points each has gained. Hover a fish for its rank progress and
-- where it bites best. Every zone and fish is in Goals.
function fill.briny(frame)
  local rows, Briny = frame.rows, ns.Briny
  SetRow(rows[1], L["Anglin' Score"], Briny:ScoreText())
  local here = Briny:Here()
  if here then
    SetRow(rows[2], here.name, Briny:ZoneText(here), nil, nil, function(tooltip)
      tooltip:AddLine(here.name)
      tooltip:AddLine(string.format(L["%d fish here, %d at Trophy. Most to gain:"], #here.fish, here.trophies), 1, 1, 1)
      for index = 1, math.min(5, #here.fish) do
        local fish = here.fish[index]
        if fish.score < 100 then tooltip:AddDoubleLine(fish.name, Briny:RankText(fish) .. " " .. Briny:Tags(fish)) end
      end
    end)
  else
    SetRow(rows[2], "|cff808080" .. L["Not in a Midnight fishing zone"] .. "|r")
  end
  for index = 3, ROW_COUNT do
    local entry = Briny.recent[index - 2]
    if entry then
      SetRow(rows[index], entry.name, Briny:RecentText(entry), nil, index == 3 and "green" or "white",
        function(tooltip) Briny:FillTooltip(tooltip, entry.name) end)
    elseif index == 3 then
      SetRow(rows[index], "|cff808080" .. L["Catch a Midnight fish to see its rank"] .. "|r")
    else
      SetRow(rows[index])
    end
  end
  local venom = Briny:Venom()
  if venom then return string.format(L["Venom %d - every fish's rank..."], venom), "goals" end
end

-- Every tab the window can show. Session is fixed in first place.
HUD.catalog = {
  { key = "session", name = L["Session"], fill = fill.session, fixed = true },
  { key = "lures", name = L["Lures"], fill = fill.lures },
  { key = "log", name = L["Log"], fill = fill.log },
  { key = "bobbers", name = L["Bobbers"], fill = fill.bobbers, footer = L["All bobber options..."],
    compartment = "bobbers", available = function() return Data.oversizedBobber ~= nil end },
  { key = "gold", name = L["Gold"], fill = fill.gold, footer = L["Rankings and history..."],
    compartment = "gold", available = function() return ns.Gold ~= nil end },
  { key = "goals", name = L["Goals"], fill = FromLines(function() return ns.Goals:ShortLines() end),
    footer = L["All goals..."], compartment = "goals" },
  { key = "events", name = L["Events"], fill = FromLines(function() return ns.Events:Lines() end, true),
    footer = L["All events..."], compartment = "events" },
  { key = "records", name = L["Records"], fill = FromLines(function() return ns.Records:Lines() end, true),
    footer = L["Records and sharing..."], compartment = "records" },
  { key = "midnight", name = L["Coiled Isle"], fill = FromLines(function() return ns.Midnight:Lines() end),
    footer = L["Coiled Isle..."], compartment = "midnight", available = function() return ns.Midnight ~= nil end },
  { key = "briny", name = L["Briny"], fill = fill.briny, footer = L["Every fish's rank..."], compartment = "goals",
    available = function() return ns.Briny ~= nil and ns.db.briny.enabled end },
}

function HUD:CatalogEntry(key)
  for _, entry in ipairs(self.catalog) do
    if entry.key == key and (not entry.available or entry.available()) then return entry end
  end
end

-- The tabs to show: Session, then the player's picks that still exist.
function HUD:Tabs()
  local tabs, seen = { self:CatalogEntry("session") }, { session = true }
  for _, key in ipairs(ns.db.hud.tabs) do
    local entry = not seen[key] and self:CatalogEntry(key)
    if entry and #tabs < MAX_TABS then
      seen[key] = true
      tabs[#tabs + 1] = entry
    end
  end
  return tabs
end

-- Adds or removes one of the optional tabs. Returns false when full.
function HUD:SetTab(key, enabled)
  local tabs = ns.db.hud.tabs
  for index = #tabs, 1, -1 do
    if tabs[index] == key then table.remove(tabs, index) end
  end
  if enabled then
    if #self:Tabs() >= MAX_TABS then return false end
    table.insert(tabs, key)
  end
  self:Refresh()
  return true
end

-- Moves an optional tab one place left (-1) or right (+1).
function HUD:MoveTab(key, direction)
  local tabs = ns.db.hud.tabs
  for index, existing in ipairs(tabs) do
    local target = index + direction
    if existing == key and tabs[target] then
      tabs[index], tabs[target] = tabs[target], tabs[index]
      break
    end
  end
  self:Refresh()
end

function HUD:ResetTabs()
  ns.db.hud.tabs = { "lures", "log" }
  ns.db.hud.tab = "session"
  self:Refresh()
end

function HUD:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then return end

  local state = ns.Engine.state
  frame.state:SetText(STATE_TEXT[state] or "")
  local pill = STATE_COLOR[state]
  frame.pill:SetShown(pill ~= nil)
  if pill then
    frame.pill:SetVertexColor(pill[1], pill[2], pill[3], 0.45)
  end
  frame.next.value:SetText(NextPress())

  -- Compact: the header, the cast bar and what the key does next, nothing else.
  local compact = ns.db.hud.compact and true or false
  frame:SetHeight(compact and COMPACT_HEIGHT or FULL_HEIGHT)
  frame.next:ClearAllPoints()
  if compact then
    frame.next:SetPoint("TOPLEFT", 10, -(PAD + HEADER + CAST_BAR + 4))
    frame.next:SetPoint("TOPRIGHT", -10, -(PAD + HEADER + CAST_BAR + 4))
  else
    frame.next:SetPoint("BOTTOMLEFT", 10, 6 + FOOTER_HEIGHT + 2)
    frame.next:SetPoint("BOTTOMRIGHT", -10, 6 + FOOTER_HEIGHT + 2)
  end
  frame.hero:Hide()
  frame.footer:SetShown(not compact)
  for _, row in ipairs(frame.rows) do row:SetShown(not compact) end
  if compact then
    for _, button in ipairs(frame.tabs) do button:Hide() end
    return
  end

  local tabs = self:Tabs()
  local current = tabs[1]
  for _, entry in ipairs(tabs) do
    if entry.key == ns.db.hud.tab then current = entry end
  end
  local tabWidth = (WIDTH - 20) / #tabs
  local brass = ns.Theme.C.brass
  for index, button in ipairs(frame.tabs) do
    local entry = tabs[index]
    button:SetShown(entry ~= nil)
    if entry then
      button.key = entry.key
      button:SetSize(tabWidth, TAB_HEIGHT)
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", 10 + (index - 1) * tabWidth, -TABS_TOP)
      button.text:SetText(entry.name)
      local open = entry == current
      button.line:SetShown(open)
      if open then
        button.back:SetVertexColor(brass[1], brass[2], brass[3], 0.28)
        button.text:SetTextColor(1, 1, 1)
      else
        button.back:SetVertexColor(1, 1, 1, 0.06)
        button.text:SetTextColor(0.6, 0.6, 0.6)
      end
    end
  end

  local footer, compartment = current.fill(frame)
  footer, compartment = footer or current.footer or "", compartment or current.compartment
  frame.footer.text:SetText(footer)
  frame.footer.compartment = compartment
  frame.footer:EnableMouse(compartment ~= nil)
  if compartment then
    frame.footer.text:SetTextColor(brass[1], brass[2], brass[3])
  else
    frame.footer.text:SetTextColor(0.5, 0.5, 0.5)
  end
end

-- Every frame while the window shows: the cast bar, the catch flare and the fade in.
function HUD:Animate(frame)
  local now = GetTime()
  local fraction = ns.Engine.state == "CHANNELING" and not ns.Core.suspended and Compat.ChannelFraction()
  if fraction then
    frame.cast:SetWidth(math.max(1, (WIDTH - PAD * 2) * fraction))
    frame.cast:Show()
  else
    frame.cast:Hide()
  end

  local motion = ns.db.hud.motion
  if self.pulseAt and motion then
    local left = 1 - (now - self.pulseAt) / PULSE
    if left > 0 then
      frame.pulse:SetAlpha(0.35 * left)
      frame.pulse:Show()
    else
      self.pulseAt = nil
      frame.pulse:Hide()
    end
  elseif frame.pulse:IsShown() then
    self.pulseAt = nil
    frame.pulse:Hide()
  end

  if self.fadeAt then
    local done = motion and (now - self.fadeAt) / FADE_IN or 1
    if done >= 1 then
      self.fadeAt = nil
      frame:SetAlpha(1)
    else
      frame:SetAlpha(done)
    end
  end
end

ns:On("CAST_LOOTED", function()
  if HUD.frame and ns.db.hud.motion then HUD.pulseAt = GetTime() end
end)

-- Shown while a session exists: all mode long normally, first cast to idle timeout with always-on.
function HUD:UpdateVisibility()
  local show = ns.Core.mode and ns.db.hud.shown and ns.Log.session ~= nil and not self.dismissed
  if show and not self.frame then self.frame = Build() end
  if not self.frame then return end
  self.frame:SetScale(ns.db.hud.scale)
  local hud = ns.Theme.C.hud
  self.frame:SetBackdropColor(hud[1], hud[2], hud[3], ns.db.hud.alpha or 0.7)
  if show and not self.frame:IsShown() and ns.db.hud.motion then
    self.fadeAt = GetTime()
    self.frame:SetAlpha(0)
  elseif not show or not self.fadeAt or not ns.db.hud.motion then
    -- Hidden, or shown with no fade under way: never leave it part-faded.
    self.fadeAt = nil
    self.frame:SetAlpha(1)
  end
  self.frame:SetShown(show)
  self:Refresh()
end

function HUD:Enable()
  self:UpdateVisibility()
end

function HUD:Disable()
  self.dismissed = nil
  if self.frame then self.frame:Hide() end
end

function HUD:Dismiss()
  self.dismissed = true
  self:UpdateVisibility()
end

ns:On("CAST_START", function()
  if not HUD.dismissed then return end
  HUD.dismissed = nil
  HUD:UpdateVisibility()
end)

function HUD:Toggle()
  HUD.dismissed = nil
  ns.db.hud.shown = not ns.db.hud.shown
  if ns.Core.mode then self:Enable() end
end

function HUD:Tick()
  self:Refresh()
end
