-- First-run welcome: a new install does nothing visible until fishing mode
-- is on, so the first login shows the three steps to a first cast. Shown
-- once per account; the steps tick themselves off as they happen.
local _, ns = ...
local L = ns.L

local Welcome = {}
ns.Welcome = Welcome

local function Step(done, text)
  return (done and "|cff40ff40[x]|r  " or "|cffffd100[ ]|r  ") .. text
end

local function Build()
  local frame = CreateFrame("Frame", "TackleboxWelcome", UIParent, "BackdropTemplate")
  frame:SetSize(420, 230)
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

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(L["Welcome to Tacklebox"])
  local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  intro:SetPoint("TOPLEFT", 16, -40)
  intro:SetWidth(388)
  intro:SetJustifyH("LEFT")
  intro:SetText(L["One key does your fishing: it casts, reels in, and keeps your lure and bobber up."])

  frame.steps = {}
  for index = 1, 3 do
    local step = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    step:SetPoint("TOPLEFT", 16, -64 - index * 24)
    frame.steps[index] = step
  end

  local function Button(text, x, width, onClick)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("BOTTOMLEFT", x, 14)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
  end
  Button(L["Pick key"], 16, 90, function() ns.Options:CaptureKey() end)
  Button(L["Start fishing mode"], 112, 140, function() ns.Core:SetMode(true) end)
  Button(L["Open the box"], 258, 100, function() ns.Menu:Open("top") end)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

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

function Welcome:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then return end
  local hasKey = ns.db.key ~= nil or ns.db.doubleClick
  local stats = ns.Log:Stats()
  local hasCast = stats ~= nil and stats.casts > 0
  local keyText = hasKey and string.format(L["Fishing key: %s"], ns.db.key or L["double right-click"])
    or L["Pick the key you want to fish with."]
  frame.steps[1]:SetText(Step(hasKey, keyText))
  frame.steps[2]:SetText(Step(ns.Core.mode, L["Turn fishing mode on (/tb, or make it always on in the box)."]))
  frame.steps[3]:SetText(Step(hasCast, L["Face some water and press your key. Press it again on the splash."]))
  if hasCast then
    ns:Print(L["That's all there is to it. /tb menu opens the box any time."])
    frame:Hide()
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
    self.frame = self.frame or Build()
    self.frame:Show()
    self:Refresh()
  end)
end

function Welcome:Show()
  self.frame = self.frame or Build()
  self.frame:Show()
  self:Refresh()
end
