-- First-run tour: nothing shows until fishing mode is on, so the first login walks through four short
-- pages: what TackleBox does, picking the key, a first cast, and what's in the box. Once per account;
-- /tb welcome reopens it. Steps tick off as they happen.
local _, ns = ...
local L = ns.L

local Welcome = {}
ns.Welcome = Welcome

local WIDTH, HEIGHT, PAD = 460, 310, 18
local TEXT_WIDTH = WIDTH - 2 * PAD
local BRASS = { 0.85, 0.66, 0.22 }

local function Tick(done, text)
  return (done and "|cff40ff40[x]|r  " or "|cffffd100[ ]|r  ") .. text
end

local function Text(parent, font, text, y)
  local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  label:SetPoint("TOPLEFT", PAD, y)
  label:SetWidth(TEXT_WIDTH)
  label:SetJustifyH("LEFT")
  label:SetSpacing(3)
  if text then label:SetText(text) end
  return label
end

local function Button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 24)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return button
end

local function Check(parent, text, y, get, set)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check:SetPoint("TOPLEFT", PAD - 4, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", check, "RIGHT", 2, 0)
  label:SetText(text)
  check:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  check.Sync = function() check:SetChecked(get() and true or false) end
  return check
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

local pages = {}

-- 1: what it is.
pages[1] = function(page)
  Text(page, "GameFontHighlightLarge",
    L["One key for all your fishing, and a box that remembers every catch."], -8)
  local bullets = {
    L["Your key casts, reels in, and keeps your lure, bobber and raft up."],
    L["The Fishing Companion, a small window, counts catches, gold per hour and goals as you fish."],
    L["The box holds your catch log, gold, achievements, alerts and settings."],
  }
  for index, text in ipairs(bullets) do
    Text(page, "GameFontHighlight", "|cffd9a838-|r  " .. text, -52 - (index - 1) * 26)
  end
  Text(page, "GameFontNormal", L["Two quick steps and you're fishing."], -140)
end

-- 2: the key.
pages[2] = function(page)
  Text(page, "GameFontHighlight",
    L["Pick one key to fish with. It only takes over while fishing mode is on; the rest of the time "
      .. "it does what it always did."], -8)
  local status = Text(page, "GameFontHighlight", nil, -64)
  local pick = Button(page, L["Pick key"], 110, function() ns.Options:CaptureKey() end)
  pick:SetPoint("TOPLEFT", PAD, -92)
  local double = Check(page, L["Or fish with a quick double right-click"], -128,
    function() return ns.db.doubleClick end,
    function(value) ns.db.doubleClick = value; ns.Engine:UpdateDoubleClick() end)
  Text(page, "GameFontDisableSmall", L["You can change both any time in the box's Top Tray."], -164)
  page.Refresh = function()
    local hasKey = ns.db.key ~= nil or ns.db.doubleClick
    status:SetText(Tick(hasKey, hasKey and string.format(L["Fishing key: %s"], ns.db.key or L["double right-click"])
      or L["No key yet."]))
    double.Sync()
  end
end

-- 3: a first cast.
pages[3] = function(page)
  local modeLine = Text(page, "GameFontHighlight", nil, -8)
  local start = Button(page, L["Start fishing mode"], 150, function() ns.Core:SetMode(true) end)
  start:SetPoint("TOPLEFT", PAD, -32)
  local always = Check(page, L["Keep fishing mode on all the time"], -64,
    function() return ns.db.alwaysOn end,
    function(value) ns.Core:SetAlwaysOn(value) end)
  local castLine = Text(page, "GameFontHighlight", nil, -104)
  Text(page, "GameFontDisableSmall",
    L["The splash is your bite cue, so sound effects get louder while you fish and go back to normal after."], -150)
  Text(page, "GameFontDisableSmall", L["/tb turns fishing mode on and off."], -176)
  page.Refresh = function()
    modeLine:SetText(Tick(ns.Core.mode, L["Turn on fishing mode."]))
    start:SetEnabled(not ns.Core.mode)
    always.Sync()
    local stats = ns.Log:Stats()
    castLine:SetText(Tick(stats ~= nil and stats.casts > 0,
      L["Face some water and press your key. Press it again when the bobber splashes."]))
  end
end

-- 4: what's in the box. Each compartment opens from here.
local SHOWCASE = {
  { key = "top", name = L["Top Tray"], text = L["Mode, key, Fishing Companion"],
    icon = "Interface\\Icons\\Trade_Fishing" },
  { key = "log", name = L["Catch Log"], text = L["Every fish, by zone or fish"],
    icon = "Interface\\Icons\\INV_Misc_Book_09" },
  { key = "lures", name = L["Lures"], text = L["Your lure, kept up for you"],
    lureIcon = true },
  { key = "gold", name = L["Gold"], text = L["Value, prices, best zones"],
    icon = "Interface\\Icons\\INV_Misc_Coin_01" },
  { key = "goals", name = L["Goals"], text = L["Achievements, Briny Best"],
    icon = "Interface\\Icons\\INV_Crown_01" },
  { key = "alarms", name = L["Alarms"], text = L["Alerts, sounds, session goals"],
    icon = "Interface\\Icons\\Spell_Nature_TimeStop" },
  { key = "events", name = L["Events"], text = L["Contests and the Coiled Isle"],
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
  { key = "settings", name = L["Settings"], text = L["Audio, export, feedback"],
    icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

pages[4] = function(page)
  Text(page, "GameFontHighlight",
    L["Open the box any time with /tb menu or the minimap button. Click one to look inside:"], -8)
  local cellWidth, cellHeight = TEXT_WIDTH / 2, 38
  for index, entry in ipairs(SHOWCASE) do
    local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
    local cell = CreateFrame("Button", nil, page)
    cell:SetSize(cellWidth - 6, cellHeight - 4)
    cell:SetPoint("TOPLEFT", PAD + column * cellWidth, -40 - row * cellHeight)
    cell:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    cell:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 2, 0)
    local lureID = entry.lureIcon and ns.Data.knownLures[1]
    local itemIcon = lureID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(lureID)
    icon:SetTexture(itemIcon or entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local name = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    name:SetText(entry.name)
    local text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 0)
    text:SetText(entry.text)
    cell:SetScript("OnClick", function()
      Welcome.frame:Hide()
      ns.Menu:Open(entry.key)
    end)
  end
end

local TITLES = {
  L["Welcome to Angler's TackleBox"],
  L["Step 1: Pick your fishing key"],
  L["Step 2: Make your first cast"],
  L["What's in the box"],
}

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local function Build()
  local frame = CreateFrame("Frame", "AnglersTackleBoxWelcome", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER", 0, 80)
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0.11, 0.22, 0.16, 0.97)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  table.insert(UISpecialFrames, "AnglersTackleBoxWelcome") -- Escape closes it

  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetSize(32, 32)
  logo:SetPoint("TOPLEFT", PAD, -12)
  logo:SetTexture("Interface\\Icons\\Trade_Fishing")
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
  local rule = frame:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(BRASS[1], BRASS[2], BRASS[3], 0.6)
  rule:SetPoint("TOPLEFT", PAD, -52)
  rule:SetPoint("TOPRIGHT", -PAD, -52)
  rule:SetHeight(1)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  frame.pages = {}
  for index, build in ipairs(pages) do
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", 0, -60)
    page:SetPoint("BOTTOMRIGHT", 0, 48)
    build(page)
    page:Hide()
    frame.pages[index] = page
  end

  -- Step dots, bottom centre.
  frame.dots = {}
  for index = 1, #pages do
    local dot = frame:CreateTexture(nil, "ARTWORK")
    dot:SetSize(8, 8)
    dot:SetPoint("BOTTOM", (index - (#pages + 1) / 2) * 16, 22)
    dot:SetColorTexture(1, 1, 1, 1)
    frame.dots[index] = dot
  end

  frame.back = Button(frame, L["Back"], 90, function() Welcome:Go(Welcome.page - 1) end)
  frame.back:SetPoint("BOTTOMLEFT", PAD, 14)
  frame.next = Button(frame, L["Next"], 110, function()
    if Welcome.page < #pages then
      Welcome:Go(Welcome.page + 1)
    else
      frame:Hide()
    end
  end)
  frame.next:SetPoint("BOTTOMRIGHT", -PAD, 14)

  frame:SetScript("OnShow", function()
    Welcome.ticker = Welcome.ticker or C_Timer.NewTicker(0.5, function() Welcome:Refresh() end)
  end)
  frame:SetScript("OnHide", function()
    if Welcome.ticker then Welcome.ticker:Cancel() Welcome.ticker = nil end
    ns.db.welcomed = true -- closing it is "got it"
  end)
  frame:Hide()
  return frame
end

function Welcome:Go(index)
  local frame = self.frame
  self.page = math.max(1, math.min(#pages, index))
  for i, page in ipairs(frame.pages) do page:SetShown(i == self.page) end
  for i, dot in ipairs(frame.dots) do
    if i == self.page then
      dot:SetVertexColor(BRASS[1], BRASS[2], BRASS[3], 1)
    else
      dot:SetVertexColor(0.4, 0.4, 0.4, 1)
    end
  end
  frame.title:SetText(TITLES[self.page])
  frame.back:SetShown(self.page > 1)
  local labels = { L["Let's go"], L["Next"], L["Next"], L["Done"] }
  frame.next:SetText(labels[self.page])
  self:Refresh()
end

function Welcome:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then return end
  local page = frame.pages[self.page]
  if page.Refresh then page.Refresh() end
  -- The first cast finishes step 2: move on to the box once.
  local stats = ns.Log:Stats()
  if self.page == 3 and stats and stats.casts > 0 and not self.castSeen then
    self.castSeen = true
    C_Timer.After(1.5, function()
      if frame:IsShown() and self.page == 3 then self:Go(4) end
    end)
  end
end

-- Called once at login.
function Welcome:Maybe()
  if ns.db.welcomed or InCombatLockdown() then return end
  -- Someone who already set a key before this existed doesn't need the tour.
  if ns.db.key then
    ns.db.welcomed = true
    return
  end
  C_Timer.After(4, function()
    if ns.db.welcomed or InCombatLockdown() then return end
    self:Show()
  end)
end

function Welcome:Show()
  self.frame = self.frame or Build()
  self.castSeen = nil
  self.frame:Show()
  self:Go(1)
end
