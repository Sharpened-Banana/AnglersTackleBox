-- The Tacklebox: the addon's main window, laid out like a tackle box. A lid
-- with a handle and a brass latch, a tray of compartments down the left,
-- and the open compartment's contents on the right. Built the first time
-- it is opened (/tb menu); nothing here runs while it is closed.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Menu = {}
ns.Menu = Menu

local SOLID = "Interface\\Buttons\\WHITE8x8"
local WIDTH, HEIGHT, LID, TRAY = 660, 560, 48, 156
local SLOT_HEIGHT = 40

-- Moulded-plastic greens, a cream tray, brass fittings.
local COLOR = {
  shell = { 0.11, 0.22, 0.16 },
  lid = { 0.16, 0.33, 0.23 },
  seam = { 0.03, 0.07, 0.05 },
  tray = { 0.78, 0.72, 0.56 },
  trayLifted = { 0.93, 0.88, 0.72 },
  ridge = { 0.52, 0.47, 0.34 },
  ink = { 0.22, 0.16, 0.08 },
  brass = { 0.85, 0.66, 0.22 },
  steel = { 0.35, 0.36, 0.38 },
  well = { 0.04, 0.08, 0.06 },
}

local function Fill(parent, layer, color, alpha)
  local texture = parent:CreateTexture(nil, layer)
  texture:SetTexture(SOLID)
  texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
  return texture
end

local function Label(parent, font, text)
  local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  if text then label:SetText(text) end
  return label
end

local function Button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 120, 24)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return button
end

-- Checkbox bound to tbl[key]; own label, so no template child is assumed.
local function Check(parent, text, tbl, key, onChange)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check.label = Label(parent, "GameFontHighlight", text)
  check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
  check:SetScript("OnClick", function(self)
    tbl[key] = self:GetChecked() and true or false
    if onChange then onChange(tbl[key]) end
    Menu:Refresh()
  end)
  check.Sync = function() check:SetChecked(tbl[key] and true or false) end
  return check
end

local function ItemName(itemID)
  local name, link = Compat.GetItemInfo(itemID)
  return link or name or ("item:" .. itemID)
end

local function ItemIcon(itemID)
  local getIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon
  return getIcon and getIcon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Takes whatever item is on the cursor, whether dropped or clicked in.
local function DropSlot(parent, text, onItem)
  local slot = CreateFrame("Button", nil, parent)
  slot:SetSize(200, 30)
  Fill(slot, "BACKGROUND", COLOR.tray, 0.12):SetAllPoints()
  local label = Label(slot, "GameFontDisableSmall", text)
  label:SetPoint("CENTER")
  local function Take()
    local kind, itemID = GetCursorInfo()
    if kind == "item" and itemID then
      ClearCursor()
      onItem(itemID)
      Menu:Refresh()
    end
  end
  slot:SetScript("OnReceiveDrag", Take)
  slot:SetScript("OnClick", Take)
  return slot
end

-- A scrolling block of report lines, as produced by the X:Lines() functions.
-- "top" leaves room above it for a compartment's own controls.
local function Report(panel, getLines, top)
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -(top or 0))
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(410, 10)
  scroll:SetScrollChild(content)
  local text = Label(content, "GameFontHighlight")
  text:SetPoint("TOPLEFT")
  text:SetWidth(410)
  text:SetJustifyH("LEFT")
  text:SetSpacing(4)
  local function Refresh()
    local out = {}
    for _, line in ipairs(getLines()) do
      out[#out + 1] = line.header and ("|cffffd100" .. line.text .. "|r") or ("   " .. line.text)
    end
    text:SetText(table.concat(out, "\n"))
    content:SetHeight(math.max(10, text:GetStringHeight() or 10))
  end
  panel.Refresh = panel.Refresh or Refresh
  return Refresh
end

---------------------------------------------------------------------------
-- Compartments
---------------------------------------------------------------------------

local function BuildTopTray(panel)
  local mode = Button(panel, "", 190, function()
    ns.Core:ToggleMode()
    Menu:Refresh()
  end)
  mode:SetHeight(30)
  mode:SetPoint("TOPLEFT", 0, 0)
  local modeNote = Label(panel, "GameFontDisableSmall")
  modeNote:SetPoint("LEFT", mode, "RIGHT", 10, 0)

  local always = Check(panel, L["Always on (no /tb needed)"], ns.db, "alwaysOn",
    function(value) ns.Core:SetAlwaysOn(value) end)
  always:SetPoint("TOPLEFT", 0, -38)

  local keyLabel = Label(panel, "GameFontNormal")
  keyLabel:SetPoint("TOPLEFT", 2, -78)
  local pick = Button(panel, L["Pick key"], 100, function() ns.Options:CaptureKey() end)
  pick:SetPoint("TOPLEFT", 250, -73)

  local double = Check(panel, L["Double right-click also fishes"], ns.db, "doubleClick",
    function() ns.Engine:UpdateDoubleClick() end)
  double:SetPoint("TOPLEFT", 0, -100)

  local header = Label(panel, "GameFontNormalLarge", L["This session"])
  header:SetPoint("TOPLEFT", 2, -146)
  local rows = {}
  for index, name in ipairs({ L["Casts"], L["Catches"], L["Session gold"], L["Gold per hour"], L["Since rare"] }) do
    local left = Label(panel, "GameFontNormal", name)
    left:SetPoint("TOPLEFT", 2, -152 - index * 20)
    local right = Label(panel, "GameFontHighlight")
    right:SetPoint("TOPLEFT", 160, -152 - index * 20)
    rows[index] = right
  end

  local reset = Button(panel, L["Reset session"], 120, function() ns.Log:ResetSession() Menu:Refresh() end)
  reset:SetPoint("TOPLEFT", 0, -284)
  local share = Button(panel, L["Share to chat"], 120, function() ns.Records:Share() end)
  share:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  local window = Button(panel, L["Customise the fishing window..."], 220, function() Menu:Select("window") end)
  window:SetPoint("TOPLEFT", 0, -320)

  panel.Refresh = function()
    local on = ns.Core.mode
    mode:SetText(on and L["Stop fishing mode"] or L["Start fishing mode"])
    modeNote:SetText(on and L["Your key is armed."] or L["Your key does its normal job."])
    keyLabel:SetText(string.format(L["Fishing key: %s"], ns.db.key or ("|cffff5555" .. L["not set"] .. "|r")))
    always.Sync() double.Sync()
    local stats = ns.Log:Stats()
    if stats then
      rows[1]:SetText(stats.casts)
      rows[2]:SetText(string.format("%d  (%d%%)", stats.catches, math.floor(stats.rate * 100 + 0.5)))
      rows[3]:SetText(Compat.CoinString(stats.value))
      rows[4]:SetText(stats.perHour > 0 and Compat.CoinString(stats.perHour) or "-")
      rows[5]:SetText(string.format(L["%d casts"], stats.sinceRare))
    else
      for index = 1, #rows do rows[index]:SetText("-") end
    end
    reset:SetEnabled(stats ~= nil)
    share:SetEnabled(stats ~= nil and stats.casts > 0)
  end
end

local LURE_ROWS, EXTRA_ROWS = 7, 5

local function BuildLures(panel)
  local enabled = Check(panel, L["Keep a lure up with the fishing key"], ns.chardb, "lureEnabled")
  enabled:SetPoint("TOPLEFT", 0, 0)
  local current = Label(panel, "GameFontNormal")
  current:SetPoint("TOPLEFT", 2, -32)

  local hint = Label(panel, "GameFontDisableSmall", L["Lures in your bags - click one to use it:"])
  hint:SetPoint("TOPLEFT", 2, -54)

  local rows = {}
  for index = 1, LURE_ROWS do
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(300, 22)
    row:SetPoint("TOPLEFT", 0, -50 - index * 23)
    row.glow = Fill(row, "BACKGROUND", COLOR.brass, 0.25)
    row.glow:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 2, 0)
    row.text = Label(row, "GameFontHighlight")
    row.text:SetPoint("LEFT", 28, 0)
    row:SetHighlightTexture(SOLID)
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
    row:SetScript("OnClick", function(self)
      ns.chardb.lureID, ns.chardb.lureEnabled = self.itemID, true
      Menu:Refresh()
    end)
    rows[index] = row
  end

  local drop = DropSlot(panel, L["Drop any other lure here"], function(itemID)
    ns.chardb.lureID, ns.chardb.lureEnabled = itemID, true
  end)
  drop:SetPoint("TOPLEFT", 0, -240)
  local auto = Button(panel, L["Clear choice"], 110, function()
    ns.chardb.lureID = nil
    Menu:Refresh()
  end)
  auto:SetPoint("LEFT", drop, "RIGHT", 10, 0)

  local extrasHeader = Label(panel, "GameFontNormal", L["Also keep up (toys, tea, bobbers):"])
  extrasHeader:SetPoint("TOPLEFT", 2, -282)
  local extras = {}
  for index = 1, EXTRA_ROWS do
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(200, 18)
    row:SetPoint("TOPLEFT", 216, -302 - (index - 1) * 18)
    row.text = Label(row, "GameFontHighlightSmall")
    row.text:SetPoint("LEFT")
    row:SetScript("OnClick", function(self)
      table.remove(ns.chardb.extras, self.index)
      Menu:Refresh()
    end)
    extras[index] = row
  end
  local extraDrop = DropSlot(panel, L["Drop a toy or item here"], function(itemID)
    for _, existing in ipairs(ns.chardb.extras) do
      if existing == itemID then return end
    end
    table.insert(ns.chardb.extras, itemID)
  end)
  extraDrop:SetPoint("TOPLEFT", 0, -302)
  local raft = Check(panel, L["Use the fishing raft"], ns.db, "useRaft")
  raft:SetPoint("TOPLEFT", 0, -338)

  panel.Refresh = function()
    enabled.Sync() raft.Sync()
    local lureID = ns.Lures:Current()
    if lureID then
      local remaining = ns.Lures:Remaining(lureID)
      local status = remaining == math.huge and L["Active"]
        or remaining and ns.FormatTime(remaining) or L["Not applied"]
      current:SetText(string.format(L["Using: %s  (%s)"], ItemName(lureID), status))
    else
      current:SetText(L["Using: nothing chosen"])
    end

    local owned = {}
    local seen = {}
    local function Add(itemID)
      if itemID and not seen[itemID] and Compat.GetItemCount(itemID) > 0 then
        seen[itemID] = true
        owned[#owned + 1] = itemID
      end
    end
    Add(ns.chardb.lureID)
    for _, itemID in ipairs(Data.knownLures) do Add(itemID) end

    for index, row in ipairs(rows) do
      local itemID = owned[index]
      row.itemID = itemID
      row:SetShown(itemID ~= nil)
      if itemID then
        row.icon:SetTexture(ItemIcon(itemID))
        row.text:SetText(string.format("%s  x%d", ItemName(itemID), Compat.GetItemCount(itemID)))
        row.glow:SetShown(itemID == lureID)
      end
    end
    hint:SetText(#owned > 0 and L["Lures in your bags - click one to use it:"]
      or L["No known lures in your bags."])

    for index, row in ipairs(extras) do
      local itemID = ns.chardb.extras[index]
      row.index = index
      row:SetShown(itemID ~= nil)
      if itemID then row.text:SetText(ItemName(itemID) .. "  |cffff5555x|r") end
    end
  end
end

local BOBBER_ROWS = 14

local function BuildBobbers(panel)
  local oversized = Check(panel, L["Keep the Reusable Oversized Bobber up"], ns.db, "oversizedBobber")
  oversized:SetPoint("TOPLEFT", 0, 0)
  local status = Label(panel, "GameFontNormal")
  status:SetPoint("TOPLEFT", 2, -34)
  local hint = Label(panel, "GameFontDisableSmall",
    L["When the buff is missing, your next key press uses the toy, then you cast."])
  hint:SetPoint("TOPLEFT", 2, -52)

  local rows = {}
  for index = 1, BOBBER_ROWS do
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(300, 21)
    row:SetPoint("TOPLEFT", 0, -50 - index * 22)
    row.glow = Fill(row, "BACKGROUND", COLOR.brass, 0.25)
    row.glow:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(19, 19)
    row.icon:SetPoint("LEFT", 2, 0)
    row.text = Label(row, "GameFontHighlight")
    row.text:SetPoint("LEFT", 28, 0)
    row:SetHighlightTexture(SOLID)
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
    row:SetScript("OnClick", function(self)
      ns.db.bobber = self.choice
      ns.Bobbers.randomPick = nil
      Menu:Refresh()
    end)
    rows[index] = row
  end

  panel.Refresh = function()
    oversized.Sync()
    oversized:SetEnabled(ns.Bobbers:HasOversized())
    oversized.label:SetText(ns.Bobbers:HasOversized() and L["Keep the Reusable Oversized Bobber up"]
      or L["Reusable Oversized Bobber (not in your toy box)"])

    local active, remaining = ns.Bobbers:Active()
    if active then
      status:SetText(string.format(L["Bobber now: %s  (%s)"], ItemName(active),
        remaining == math.huge and L["Active"] or ns.FormatTime(remaining)))
    else
      status:SetText(L["Bobber now: the plain one"])
    end

    local choices = { { choice = nil, text = L["None - leave my bobber alone"] } }
    local owned = ns.Bobbers:Owned()
    if #owned > 1 then
      choices[#choices + 1] = { choice = "random", text = L["Random - surprise me each time"],
        icon = "Interface\\Icons\\INV_Misc_Dice_01" }
    end
    for _, itemID in ipairs(owned) do
      choices[#choices + 1] = { choice = itemID, text = ItemName(itemID), icon = ItemIcon(itemID) }
    end
    for index, row in ipairs(rows) do
      local entry = choices[index]
      row:SetShown(entry ~= nil)
      if entry then
        row.choice = entry.choice
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText(entry.text)
        row.glow:SetShown(ns.db.bobber == entry.choice)
      end
    end
    if #owned == 0 then
      hint:SetText(L["No bobber toys in your toy box yet (Crate of Bobbers, from Conjurer Margoss)."])
    end
  end
end

-- Journal: every fish you have logged on the left of the search box's list;
-- click one for its page.
local function BuildJournal(panel)
  local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  search:SetSize(200, 20)
  search:SetPoint("TOPLEFT", 6, 0)
  search:SetAutoFocus(false)
  local hint = Label(panel, "GameFontDisableSmall", L["Type to find a fish"])
  hint:SetPoint("LEFT", search, "RIGHT", 10, 0)

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -28)
  scroll:SetPoint("TOPRIGHT", -24, -28)
  scroll:SetHeight(130)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(410, 10)
  scroll:SetScrollChild(content)

  local rows, selected = {}, nil
  local page = CreateFrame("Frame", nil, panel)
  page:SetPoint("TOPLEFT", 0, -170)
  page:SetPoint("BOTTOMRIGHT", 0, 0)
  local refreshPage = Report(page, function()
    if selected then return ns.Journal:Page(selected) end
    return { { text = L["Pick a fish above to see where you catch it."] } }
  end)

  local function Refresh()
    local needle = (search:GetText() or ""):lower()
    local shown = 0
    for _, fish in ipairs(ns.Journal:Fish()) do
      if needle == "" or fish.name:lower():find(needle, 1, true) then
        shown = shown + 1
        local row = rows[shown]
        if not row then
          row = CreateFrame("Button", nil, content)
          row:SetSize(400, 18)
          row:SetPoint("TOPLEFT", 0, -(shown - 1) * 18)
          row.glow = Fill(row, "BACKGROUND", COLOR.brass, 0.25)
          row.glow:SetAllPoints()
          row.name = Label(row, "GameFontHighlightSmall")
          row.name:SetPoint("LEFT", 4, 0)
          row.count = Label(row, "GameFontHighlightSmall")
          row.count:SetPoint("RIGHT", -4, 0)
          row:SetHighlightTexture(SOLID)
          row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
          row:SetScript("OnClick", function(self)
            selected = self.fish
            Menu:Refresh()
          end)
          rows[shown] = row
        end
        row.fish = fish
        row.name:SetText(fish.name)
        row.count:SetText(fish.total)
        row.glow:SetShown(selected ~= nil and selected.id == fish.id)
        row:Show()
        if selected and selected.id == fish.id then selected = fish end -- fresh numbers
      end
    end
    for index = shown + 1, #rows do rows[index]:Hide() end
    content:SetHeight(math.max(10, shown * 18))
    refreshPage()
  end
  search:SetScript("OnTextChanged", Refresh)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  panel.Refresh = Refresh
end

-- Gold: the value alert, a bar chart of recent sessions, and the rankings.
local CHART_BARS, CHART_HEIGHT = 30, 70

local function BuildGold(panel)
  local label = Label(panel, "GameFontHighlight", L["Alert when one catch is worth at least"])
  label:SetPoint("TOPLEFT", 2, -4)
  local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  box:SetSize(60, 20)
  box:SetPoint("LEFT", label, "RIGHT", 12, 0)
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  local unit = Label(panel, "GameFontHighlight", L["gold  (0 = off)"])
  unit:SetPoint("LEFT", box, "RIGHT", 6, 0)
  local function Commit(self)
    ns.db.valueAlert = tonumber(self:GetText()) or 0
    self:ClearFocus()
  end
  box:SetScript("OnEnterPressed", Commit)
  box:SetScript("OnEditFocusLost", Commit)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local autoScan = Check(panel, L["Refresh stale fish prices when I open the auction house"], ns.db, "ahScan")
  autoScan:SetPoint("TOPLEFT", 0, -28)
  local scan = Button(panel, L["Scan now"], 90, function()
    local _, message = ns.Gold:Scan()
    ns:Print(message)
  end)
  scan:SetPoint("TOPLEFT", 330, -28)

  local chartTitle = Label(panel, "GameFontNormal")
  chartTitle:SetPoint("TOPLEFT", 2, -64)
  local chart = CreateFrame("Frame", nil, panel)
  chart:SetPoint("TOPLEFT", 0, -82)
  chart:SetSize(410, CHART_HEIGHT)
  Fill(chart, "BACKGROUND", COLOR.tray, 0.08):SetAllPoints()
  local bars = {}
  for index = 1, CHART_BARS do
    local bar = CreateFrame("Frame", nil, chart)
    bar:SetWidth(410 / CHART_BARS - 3)
    bar:SetPoint("BOTTOMLEFT", (index - 1) * (410 / CHART_BARS) + 1, 0)
    Fill(bar, "ARTWORK", COLOR.brass):SetAllPoints()
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
      if not self.session then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(date("%Y-%m-%d %H:%M", self.session.start))
      GameTooltip:AddLine(string.format(L["%s per hour, %s in total"], Compat.CoinString(self.session.perHour),
        Compat.CoinString(self.session.value)), 1, 1, 1)
      GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bars[index] = bar
  end

  local report = CreateFrame("Frame", nil, panel)
  report:SetPoint("TOPLEFT", 0, -164)
  report:SetPoint("BOTTOMRIGHT", 0, 0)
  local refreshReport = Report(report, function() return ns.Gold:Lines() end)

  panel.Refresh = function()
    autoScan.Sync()
    if not box:HasFocus() then box:SetText(tostring(ns.db.valueAlert or 0)) end
    local history = ns.Gold:History(CHART_BARS)
    local best = 0
    for _, session in ipairs(history) do best = math.max(best, session.perHour) end
    chartTitle:SetText(best > 0
      and string.format(L["Gold per hour, last %d sessions (best %s)"], #history, Compat.CoinString(best))
      or L["Gold per hour by session - nothing saved yet"])
    for index, bar in ipairs(bars) do
      local session = history[index]
      bar.session = session
      bar:SetShown(session ~= nil and best > 0)
      if session and best > 0 then
        bar:SetHeight(math.max(2, session.perHour / best * CHART_HEIGHT))
      end
    end
    refreshReport()
  end
end

-- Window: which tabs the small fishing window shows, and in what order.
local function BuildWindow(panel)
  local show = Check(panel, L["Show the window while fishing"], ns.db.hud, "shown",
    function() ns.HUD:UpdateVisibility() end)
  show:SetPoint("TOPLEFT", 0, 0)

  local scaleLabel = Label(panel, "GameFontHighlight")
  scaleLabel:SetPoint("TOPLEFT", 2, -36)
  local function Scale(step)
    ns.db.hud.scale = math.max(0.6, math.min(2, (ns.db.hud.scale or 1) + step))
    ns.HUD:UpdateVisibility()
    Menu:Refresh()
  end
  local smaller = Button(panel, "-", 26, function() Scale(-0.05) end)
  smaller:SetPoint("TOPLEFT", 130, -31)
  local bigger = Button(panel, "+", 26, function() Scale(0.05) end)
  bigger:SetPoint("LEFT", smaller, "RIGHT", 4, 0)

  local header = Label(panel, "GameFontNormal")
  header:SetPoint("TOPLEFT", 2, -70)
  local note = Label(panel, "GameFontDisableSmall",
    L["Session always comes first. Tick the tabs you want; the arrows set their order."])
  note:SetPoint("TOPLEFT", 2, -88)

  local rows = {}
  for index = 1, #ns.HUD.catalog do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(400, 26)
    row:SetPoint("TOPLEFT", 0, -84 - index * 27)
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(24, 24)
    row.check:SetPoint("LEFT")
    row.name = Label(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", 30, 0)
    row.place = Label(row, "GameFontDisableSmall")
    row.place:SetPoint("LEFT", 160, 0)
    row.left = Button(row, "<", 26, function() ns.HUD:MoveTab(row.key, -1) Menu:Refresh() end)
    row.left:SetPoint("LEFT", 270, 0)
    row.right = Button(row, ">", 26, function() ns.HUD:MoveTab(row.key, 1) Menu:Refresh() end)
    row.right:SetPoint("LEFT", row.left, "RIGHT", 4, 0)
    row.check:SetScript("OnClick", function(self)
      if not ns.HUD:SetTab(row.key, self:GetChecked() and true or false) then
        ns:Print(string.format(L["The window holds %d tabs. Untick one first."], ns.HUD.MAX_TABS))
      end
      Menu:Refresh()
    end)
    rows[index] = row
  end
  local reset = Button(panel, L["Back to the default tabs"], 190, function()
    ns.HUD:ResetTabs()
    Menu:Refresh()
  end)
  reset:SetPoint("TOPLEFT", 0, -90 - (#ns.HUD.catalog + 1) * 27)

  panel.Refresh = function()
    show.Sync()
    scaleLabel:SetText(string.format(L["Size: %d%%"], math.floor((ns.db.hud.scale or 1) * 100 + 0.5)))
    local tabs = ns.HUD:Tabs()
    local place = {}
    for index, entry in ipairs(tabs) do place[entry.key] = index end
    header:SetText(string.format(L["Tabs (%d of %d used)"], #tabs, ns.HUD.MAX_TABS))

    -- Chosen tabs first, in their order; then the rest of the catalogue.
    local ordered = {}
    for _, entry in ipairs(tabs) do ordered[#ordered + 1] = entry end
    for _, entry in ipairs(ns.HUD.catalog) do
      if not place[entry.key] and ns.HUD:CatalogEntry(entry.key) then ordered[#ordered + 1] = entry end
    end
    for index, row in ipairs(rows) do
      local entry = ordered[index]
      row:SetShown(entry ~= nil)
      if entry then
        local position = place[entry.key]
        row.key = entry.key
        row.name:SetText(entry.name)
        row.check:SetChecked(position ~= nil)
        row.check:SetEnabled(not entry.fixed)
        row.place:SetText(entry.fixed and L["always first"]
          or position and string.format(L["tab %d"], position) or "")
        local movable = position ~= nil and not entry.fixed
        row.left:SetShown(movable)
        row.right:SetShown(movable)
        row.left:SetEnabled(movable and position > 2)
        row.right:SetEnabled(movable and position < #tabs)
      end
    end
  end
end

local function BuildRecords(panel)
  local share = Button(panel, L["Share this session to chat"], 200, function() ns.Records:Share() end)
  share:SetPoint("TOPLEFT", 0, 0)
  local note = Label(panel, "GameFontDisableSmall", L["Party if you are in one, else guild, else say."])
  note:SetPoint("LEFT", share, "RIGHT", 10, 0)
  local clear = Button(panel, L["Clear gold records"], 150, function()
    ns.Records:Reset(true)
    Menu:Refresh()
  end)
  clear:SetPoint("BOTTOMLEFT", 0, 0)
  local report = CreateFrame("Frame", nil, panel)
  report:SetPoint("TOPLEFT", 0, -36)
  report:SetPoint("BOTTOMRIGHT", 0, 0)
  local refreshReport = Report(report, function() return ns.Records:Lines() end)
  panel.Refresh = function()
    share:SetEnabled(ns.Records:Summary() ~= nil)
    refreshReport()
  end
end

local function BuildLog(panel)
  ns.LogWindow:Attach(panel)
  panel.Refresh = function() ns.LogWindow:Refresh() end
  panel.OnOpen = function() ns.LogWindow:ShowHere() end
end

local function BuildSettings(panel)
  local checks = {
    Check(panel, L["Focus audio: boost the splash while fishing"], ns.db.audio, "enabled"),
    Check(panel, L["Mute music while fishing"], ns.db.audio, "muteMusic"),
    Check(panel, L["Mute ambience while fishing"], ns.db.audio, "muteAmbience"),
    Check(panel, L["Reel in with soft interact"], ns.db, "softInteract"),
    Check(panel, L["Auto loot while fishing"], ns.db, "autoLoot"),
    Check(panel, L["Swap to fishing gear"], ns.chardb, "gearSwap"),
    Check(panel, L["Alerts on screen and with sound"], ns.db, "alerts"),
    Check(panel, L["Flash the screen on alerts"], ns.db, "alertFlash"),
    Check(panel, L["Fishing event reminders"], ns.db, "eventAlerts"),
    Check(panel, L["Warn before the game marks me away"], ns.db, "afkWarning"),
    Check(panel, L["Show my fishing spots on the world map"], ns.db, "mapPins",
      function() ns.Spots:RefreshPins() end),
  }
  local minimap = Check(panel, L["Minimap button"], ns.db.minimap, "hide",
    function() ns.Broker:UpdateButton() end)
  -- Stored as "hide", shown as "show".
  minimap:SetScript("OnClick", function(self)
    ns.db.minimap.hide = not self:GetChecked()
    ns.Broker:UpdateButton()
  end)
  minimap.Sync = function() minimap:SetChecked(not ns.db.minimap.hide) end
  checks[#checks + 1] = minimap
  local camera = Check(panel, L["Use my saved fishing camera zoom"], ns.db.camera, "enabled")
  checks[#checks + 1] = camera
  for index, check in ipairs(checks) do
    check:SetPoint("TOPLEFT", 0, -(index - 1) * 25)
  end
  local saveCamera = Button(panel, L["Save current zoom"], 140, function() ns.Camera:Save() Menu:Refresh() end)
  saveCamera:SetPoint("TOPLEFT", 270, -(#checks - 1) * 25)
  local all = Button(panel, L["All settings..."], 140, function() ns.Options:Open() end)
  all:SetPoint("TOPLEFT", 0, -#checks * 25 - 8)
  panel.Refresh = function()
    for _, check in ipairs(checks) do check.Sync() end
  end
end

local function SpellIcon(spellID)
  local getTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
  return getTexture and getTexture(spellID)
end

local function Compartments()
  local list = {
    { key = "top", name = L["Top Tray"], icon = "Interface\\Icons\\Trade_Fishing", build = BuildTopTray },
    { key = "lures", name = L["Lures"], icon = Data.knownLures[1] and ItemIcon(Data.knownLures[1]),
      build = BuildLures },
    { key = "bobbers", name = L["Bobbers"], icon = Data.oversizedBobber and ItemIcon(Data.oversizedBobber.item),
      build = BuildBobbers },
    { key = "log", name = L["Catch Log"], icon = "Interface\\Icons\\INV_Misc_Book_09", build = BuildLog },
    { key = "journal", name = L["Journal"], icon = "Interface\\Icons\\INV_Misc_Note_01", build = BuildJournal },
    { key = "gold", name = L["Gold"], icon = "Interface\\Icons\\INV_Misc_Coin_01", build = BuildGold },
    { key = "goals", name = L["Goals"], icon = SpellIcon(64731),
      build = function(panel) Report(panel, function() return ns.Goals:Lines() end) end },
    { key = "events", name = L["Events"], icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
      build = function(panel) Report(panel, function() return ns.Events:Lines() end) end },
  }
  if not Data.oversizedBobber then table.remove(list, 3) end -- no bobber toys on Classic
  if ns.Midnight then
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
      and C_CurrencyInfo.GetCurrencyInfo(Data.midnight.currencyID)
    list[#list + 1] = { key = "midnight", name = L["Coiled Isle"], icon = info and info.iconFileID,
      build = function(panel) Report(panel, function() return ns.Midnight:Lines() end) end }
  end
  list[#list + 1] = { key = "records", name = L["Records"], icon = "Interface\\Icons\\INV_Crown_01",
    build = BuildRecords }
  if not ns.Gold then -- the gold module can be left out of a build
    for index = #list, 1, -1 do
      if list[index].key == "gold" then table.remove(list, index) end
    end
  end
  list[#list + 1] = { key = "window", name = L["Window"], icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
    build = BuildWindow }
  list[#list + 1] = { key = "settings", name = L["Settings"], icon = "Interface\\Icons\\INV_Misc_Gear_01",
    build = BuildSettings }
  return list
end

---------------------------------------------------------------------------
-- The box
---------------------------------------------------------------------------

local function BuildBox()
  local frame = CreateFrame("Frame", "TackleboxMenu", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetBackdrop({
    bgFile = SOLID,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(COLOR.shell[1], COLOR.shell[2], COLOR.shell[3], 0.97)
  frame:SetBackdropBorderColor(COLOR.seam[1], COLOR.seam[2], COLOR.seam[3], 1)
  table.insert(UISpecialFrames, "TackleboxMenu") -- Escape closes it

  -- Carry handle: two posts and a grip, standing proud of the lid.
  for _, x in ipairs({ -70, 70 }) do
    local post = Fill(frame, "BACKGROUND", COLOR.steel)
    post:SetSize(8, 14)
    post:SetPoint("BOTTOM", frame, "TOP", x, -2)
  end
  local grip = Fill(frame, "BACKGROUND", COLOR.steel)
  grip:SetSize(164, 9)
  grip:SetPoint("BOTTOM", frame, "TOP", 0, 10)

  -- Lid, with a lighter top edge and the seam where it meets the body.
  local lid = Fill(frame, "BORDER", COLOR.lid)
  lid:SetPoint("TOPLEFT", 4, -4)
  lid:SetPoint("TOPRIGHT", -4, -4)
  lid:SetHeight(LID)
  local shine = Fill(frame, "ARTWORK", { 1, 1, 1 }, 0.07)
  shine:SetPoint("TOPLEFT", lid)
  shine:SetPoint("TOPRIGHT", lid)
  shine:SetHeight(LID / 2)
  local seam = Fill(frame, "ARTWORK", COLOR.seam)
  seam:SetPoint("TOPLEFT", lid, "BOTTOMLEFT")
  seam:SetPoint("TOPRIGHT", lid, "BOTTOMRIGHT")
  seam:SetHeight(3)

  local icon = frame:CreateTexture(nil, "OVERLAY")
  icon:SetTexture("Interface\\Icons\\Trade_Fishing")
  icon:SetSize(30, 30)
  icon:SetPoint("TOPLEFT", 14, -13)
  local title = Label(frame, "GameFontNormalHuge", "TACKLEBOX")
  title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
  title:SetTextColor(COLOR.trayLifted[1], COLOR.trayLifted[2], COLOR.trayLifted[3])
  frame.status = Label(frame, "GameFontNormal")
  frame.status:SetPoint("TOPRIGHT", -44, -22)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -8)

  -- Brass latch over the seam. It doubles as the fishing-mode switch:
  -- bright when the mode is on, dull when it is off.
  local latch = CreateFrame("Button", nil, frame)
  latch:SetSize(46, 22)
  latch:SetPoint("TOP", frame, "TOP", 0, -LID + 8)
  latch.plate = Fill(latch, "OVERLAY", COLOR.brass)
  latch.plate:SetAllPoints()
  local rivet = Fill(latch, "OVERLAY", COLOR.seam, 0.7)
  rivet:SetSize(6, 6)
  rivet:SetPoint("CENTER")
  latch:SetScript("OnClick", function()
    ns.Core:ToggleMode()
    Menu:Refresh()
  end)
  latch:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L["Latch: click to start or stop fishing mode"])
    GameTooltip:Show()
  end)
  latch:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.latch = latch

  -- The tray of compartments.
  local tray = CreateFrame("Frame", nil, frame)
  tray:SetPoint("TOPLEFT", 10, -LID - 14)
  tray:SetPoint("BOTTOMLEFT", 10, 10)
  tray:SetWidth(TRAY)
  Fill(tray, "BACKGROUND", COLOR.tray):SetAllPoints()

  -- The well the open compartment's contents sit in.
  local well = CreateFrame("Frame", nil, frame)
  well:SetPoint("TOPLEFT", tray, "TOPRIGHT", 8, 0)
  well:SetPoint("BOTTOMRIGHT", -10, 10)
  Fill(well, "BACKGROUND", COLOR.well, 0.85):SetAllPoints()
  frame.heading = Label(well, "GameFontNormalLarge")
  frame.heading:SetPoint("TOPLEFT", 14, -12)
  local rule = Fill(well, "ARTWORK", COLOR.brass, 0.6)
  rule:SetPoint("TOPLEFT", 12, -34)
  rule:SetPoint("TOPRIGHT", -12, -34)
  rule:SetHeight(1)

  frame.slots, frame.panels = {}, {}
  for index, compartment in ipairs(Compartments()) do
    local slot = CreateFrame("Button", nil, tray)
    slot:SetSize(TRAY, SLOT_HEIGHT)
    slot:SetPoint("TOPLEFT", 0, -(index - 1) * SLOT_HEIGHT)
    slot.lift = Fill(slot, "BORDER", COLOR.trayLifted)
    slot.lift:SetAllPoints()
    slot.tab = Fill(slot, "ARTWORK", COLOR.brass)
    slot.tab:SetPoint("TOPLEFT")
    slot.tab:SetPoint("BOTTOMLEFT")
    slot.tab:SetWidth(5)
    local ridge = Fill(slot, "ARTWORK", COLOR.ridge) -- moulded divider between compartments
    ridge:SetPoint("BOTTOMLEFT")
    ridge:SetPoint("BOTTOMRIGHT")
    ridge:SetHeight(2)
    local slotIcon = slot:CreateTexture(nil, "OVERLAY")
    slotIcon:SetSize(28, 28)
    slotIcon:SetPoint("LEFT", 14, 0)
    slotIcon:SetTexture(compartment.icon or "Interface\\Icons\\Trade_Fishing")
    local name = Label(slot, "GameFontNormal", compartment.name)
    name:SetPoint("LEFT", slotIcon, "RIGHT", 10, 0)
    name:SetTextColor(COLOR.ink[1], COLOR.ink[2], COLOR.ink[3])
    name:SetShadowOffset(0, 0)
    slot:SetHighlightTexture(SOLID)
    slot:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.18)
    slot:SetScript("OnClick", function() Menu:Select(compartment.key) end)
    frame.slots[compartment.key] = slot

    local panel = CreateFrame("Frame", nil, well)
    panel:SetPoint("TOPLEFT", 14, -46)
    panel:SetPoint("BOTTOMRIGHT", -12, 12)
    panel.name = compartment.name
    panel.build = compartment.build
    panel:Hide()
    frame.panels[compartment.key] = panel
  end

  -- Live numbers (session, lure timer, events) tick while the box is open.
  frame:SetScript("OnShow", function()
    Menu.ticker = Menu.ticker or C_Timer.NewTicker(1, function() Menu:Refresh() end)
  end)
  frame:SetScript("OnHide", function()
    if Menu.ticker then Menu.ticker:Cancel() Menu.ticker = nil end
  end)
  frame:Hide() -- new frames start shown; Open decides
  return frame
end

function Menu:Select(key)
  local frame = self.frame
  if not frame.panels[key] then key = "top" end
  self.selected = key
  for name, panel in pairs(frame.panels) do
    local open = name == key
    if open and panel.build then
      panel.build(panel) -- contents are made the first time a compartment opens
      panel.build = nil
    end
    panel:SetShown(open)
    frame.slots[name].lift:SetShown(open)
    frame.slots[name].tab:SetShown(open)
  end
  local panel = frame.panels[key]
  frame.heading:SetText(panel.name)
  if panel.OnOpen then panel.OnOpen() end
  self:Refresh()
end

function Menu:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then return end
  local on = ns.Core.mode
  frame.status:SetText(on and ("|cff40ff40" .. L["Fishing mode on"] .. "|r")
    or ("|cff9d9d9d" .. L["Fishing mode off"] .. "|r"))
  local brass = COLOR.brass
  local shade = on and 1 or 0.45
  frame.latch.plate:SetVertexColor(brass[1] * shade, brass[2] * shade, brass[3] * shade)
  local panel = frame.panels[self.selected]
  if panel and panel.Refresh then panel.Refresh() end
end

function Menu:Open(key)
  if not self.frame then self.frame = BuildBox() end
  self.frame:Show()
  self:Select(key or self.selected or "top")
end

function Menu:Toggle(key)
  if self.frame and self.frame:IsShown() and (not key or key == self.selected) then
    self.frame:Hide()
  else
    self:Open(key)
  end
end
