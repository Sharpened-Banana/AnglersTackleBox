-- Session window, with Session / Lures / Log tabs. The frame is built the
-- first time it is needed, so a character that never fishes never pays for it.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local HUD = ns:NewModule("HUD")

local WIDTH, ROW_COUNT, ROW_HEIGHT = 250, 6, 16
local TAB_HEIGHT, FOOTER_HEIGHT = 18, 16
local TABS = {
  { key = "session", name = L["Session"] },
  { key = "lures", name = L["Lures"] },
  { key = "log", name = L["Log"] },
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

  -- Tabs: plain text buttons with a brass underline on the open one.
  frame.tabs = {}
  local tabWidth = (WIDTH - 20) / #TABS
  for index, tab in ipairs(TABS) do
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(tabWidth, TAB_HEIGHT)
    button:SetPoint("TOPLEFT", 10 + (index - 1) * tabWidth, -26)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(tab.name)
    button.line = button:CreateTexture(nil, "ARTWORK")
    button.line:SetTexture("Interface\\Buttons\\WHITE8x8")
    button.line:SetVertexColor(0.85, 0.66, 0.22)
    button.line:SetPoint("BOTTOMLEFT", 4, 0)
    button.line:SetPoint("BOTTOMRIGHT", -4, 0)
    button.line:SetHeight(2)
    button:SetScript("OnClick", function()
      ns.db.hud.tab = tab.key
      HUD:Refresh()
    end)
    frame.tabs[tab.key] = button
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

local function SetRow(row, left, right, onClick, highlight)
  row.left:SetText(left or "")
  row.right:SetText(right or "")
  row.onClick = onClick
  row:EnableMouse(onClick ~= nil)
  if highlight then
    row.left:SetTextColor(0.25, 1, 0.25)
  else
    row.left:SetTextColor(1, 0.82, 0)
  end
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

function HUD:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then return end

  frame.state:SetText(STATE_TEXT[ns.Engine.state] or "")

  local selected = ns.db.hud.tab
  if not fill[selected] then selected = "session" end
  for key, button in pairs(frame.tabs) do
    local open = key == selected
    button.line:SetShown(open)
    if open then
      button.text:SetTextColor(1, 1, 1)
    else
      button.text:SetTextColor(0.6, 0.6, 0.6)
    end
  end

  local footer, compartment = fill[selected](frame)
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
