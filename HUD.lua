-- Session window. Session is always the first tab; the rest come from a
-- catalogue and are the player's choice (default: Lures and Log). The frame
-- is built the first time it is needed, so a character that never fishes
-- never pays for it.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local HUD = ns:NewModule("HUD")

local WIDTH, ROW_COUNT, ROW_HEIGHT = 250, 6, 16
local TAB_HEIGHT, FOOTER_HEIGHT = 18, 16
local MAX_TABS = 5 -- Session plus four
HUD.MAX_TABS = MAX_TABS

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

local function Build()
  local frame = CreateFrame("Frame", "TackleboxHUD", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, 30 + TAB_HEIGHT + ROW_COUNT * ROW_HEIGHT + FOOTER_HEIGHT + 6)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.7)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
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

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOPLEFT", 10, -8)
  frame.title:SetText("Tacklebox")

  frame.state = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.state:SetPoint("TOPRIGHT", -10, -10)

  -- Tabs: plain text buttons with a brass underline on the open one. The
  -- buttons are a pool; Refresh lays out however many tabs are chosen.
  frame.tabs = {}
  for index = 1, MAX_TABS do
    local button = CreateFrame("Button", nil, frame)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.line = button:CreateTexture(nil, "ARTWORK")
    button.line:SetTexture("Interface\\Buttons\\WHITE8x8")
    button.line:SetVertexColor(0.85, 0.66, 0.22)
    button.line:SetPoint("BOTTOMLEFT", 4, 0)
    button.line:SetPoint("BOTTOMRIGHT", -4, 0)
    button.line:SetHeight(2)
    button:SetScript("OnClick", function(self)
      ns.db.hud.tab = self.key
      HUD:Refresh()
    end)
    frame.tabs[index] = button
  end

  -- Rows are buttons so a tab can make them clickable (picking a lure).
  frame.rows = {}
  for index = 1, ROW_COUNT do
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(WIDTH - 20, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 10, -30 - TAB_HEIGHT - (index - 1) * ROW_HEIGHT)
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.left:SetPoint("LEFT")
    row.left:SetWidth(WIDTH - 90)
    row.left:SetJustifyH("LEFT")
    row.left:SetWordWrap(false)
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT")
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
    row:SetScript("OnClick", function(self)
      if self.onClick then
        self.onClick()
        HUD:Refresh()
      end
    end)
    frame.rows[index] = row
  end

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
  return frame
end

local ROW_COLORS = { gold = { 1, 0.82, 0 }, green = { 0.25, 1, 0.25 }, white = { 1, 1, 1 } }

-- "style" is true/"green", "white", or nil for the default gold.
local function SetRow(row, left, right, onClick, style)
  row.left:SetText(left or "")
  row.right:SetText(right or "")
  -- A row with nothing on the right may use the full width.
  row.left:SetWidth((right == nil or right == "") and (WIDTH - 20) or (WIDTH - 90))
  row.onClick = onClick
  row:EnableMouse(onClick ~= nil)
  local color = ROW_COLORS[style == true and "green" or style or "gold"] or ROW_COLORS.gold
  row.left:SetTextColor(color[1], color[2], color[3])
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
  if stats then
    SetRow(rows[1], L["Catches"], string.format("%d / %d  (%d%%)",
      stats.catches, stats.casts, math.floor(stats.rate * 100 + 0.5)))
    SetRow(rows[2], L["Session gold"], Compat.CoinString(stats.value))
    -- The hourly rate is noise until a minute of fishing is behind it.
    SetRow(rows[3], L["Gold per hour"], stats.perHour > 0 and Compat.CoinString(stats.perHour) or "-")
    SetRow(rows[4], L["Since rare"], string.format(L["%d casts"], stats.sinceRare))
  else
    for index = 1, 4 do SetRow(rows[index]) end
  end

  local lureID = ns.chardb.lureEnabled and ns.Lures:Current()
  SetRow(rows[5], L["Lure"], lureID and LureStatus(lureID) or L["None"])

  if not ns.db.key and not ns.db.doubleClick then
    SetRow(rows[6], L["Next press"], "|cffff5555/tb bind|r")
  else
    SetRow(rows[6], L["Next press"], ns.Engine.nextLabel or "")
  end
  return ns.Events:Headline(true) or "", nil
end

-- The lure in use, then the lures in the bags: click one to switch to it.
function fill.lures(frame)
  local rows = frame.rows
  local current = ns.chardb.lureEnabled and ns.Lures:Current() or nil
  if current then
    SetRow(rows[1], ItemName(current), LureStatus(current), nil, true)
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

-- Tabs built from a report: the first rows of its lines.
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
        ns.db.bobber = (not chosen) and entry.choice or nil -- click again to turn it off
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

  frame.state:SetText(STATE_TEXT[ns.Engine.state] or "")

  local tabs = self:Tabs()
  local current = tabs[1]
  for _, entry in ipairs(tabs) do
    if entry.key == ns.db.hud.tab then current = entry end
  end
  local tabWidth = (WIDTH - 20) / #tabs
  for index, button in ipairs(frame.tabs) do
    local entry = tabs[index]
    button:SetShown(entry ~= nil)
    if entry then
      button.key = entry.key
      button:SetSize(tabWidth, TAB_HEIGHT)
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", 10 + (index - 1) * tabWidth, -26)
      button.text:SetText(entry.name)
      local open = entry == current
      button.line:SetShown(open)
      if open then
        button.text:SetTextColor(1, 1, 1)
      else
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
    frame.footer.text:SetTextColor(0.85, 0.66, 0.22)
  else
    frame.footer.text:SetTextColor(0.5, 0.5, 0.5)
  end
end

-- Shown while there is a session to show: the whole time in normal mode,
-- from the first cast until the idle timeout with always-on.
function HUD:UpdateVisibility()
  local show = ns.Core.mode and ns.db.hud.shown and ns.Log.session ~= nil
  if show and not self.frame then self.frame = Build() end
  if not self.frame then return end
  self.frame:SetScale(ns.db.hud.scale)
  self.frame:SetShown(show)
  self:Refresh()
end

function HUD:Enable()
  self:UpdateVisibility()
end

function HUD:Disable()
  if self.frame then self.frame:Hide() end
end

function HUD:Toggle()
  ns.db.hud.shown = not ns.db.hud.shown
  if ns.Core.mode then self:Enable() end
end

function HUD:Tick()
  self:Refresh()
end
