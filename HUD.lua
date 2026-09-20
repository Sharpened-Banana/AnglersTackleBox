-- Session window and alerts. The frame is built the first time fishing mode
-- turns on, so a character that never fishes never pays for it.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local HUD = ns:NewModule("HUD")

local ROWS = { "catches", "value", "perHour", "sinceRare", "lure", "next" }
local FOOTER_HEIGHT = 16
local LABELS = {
  catches = L["Catches"],
  value = L["Session gold"],
  perHour = L["Gold per hour"],
  sinceRare = L["Since rare"],
  lure = L["Lure"],
  next = L["Next press"],
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
  frame:SetSize(220, 30 + #ROWS * 16 + FOOTER_HEIGHT)
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

  frame.values = {}
  for i, key in ipairs(ROWS) do
    local y = -10 - i * 16
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, y)
    label:SetText(LABELS[key])
    local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("TOPRIGHT", -10, y)
    frame.values[key] = value
  end

  -- Footer: the running or next fishing event.
  frame.event = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.event:SetPoint("BOTTOMLEFT", 10, 8)
  frame.event:SetPoint("BOTTOMRIGHT", -10, 8)
  frame.event:SetJustifyH("LEFT")
  frame.event:SetWordWrap(false)
  return frame
end

function HUD:Refresh()
  local frame = self.frame
  if not frame or not frame:IsShown() then return end

  local engine = ns.Engine
  frame.state:SetText(STATE_TEXT[engine.state] or "")

  local stats = ns.Log:Stats()
  if stats then
    frame.values.catches:SetText(string.format("%d / %d  (%d%%)",
      stats.catches, stats.casts, math.floor(stats.rate * 100 + 0.5)))
    frame.values.value:SetText(Compat.CoinString(stats.value))
    -- The hourly rate is noise until a minute of fishing is behind it.
    frame.values.perHour:SetText(stats.perHour > 0 and Compat.CoinString(stats.perHour) or "-")
    frame.values.sinceRare:SetText(string.format(L["%d casts"], stats.sinceRare))
  end

  local lureText = L["None"]
  if ns.chardb.lureEnabled and ns.Lures:Current() then
    local remaining = ns.Lures:Remaining()
    if remaining == math.huge then
      lureText = L["Active"]
    elseif remaining then
      lureText = ns.FormatTime(remaining)
    else
      lureText = L["Not applied"]
    end
  end
  frame.values.lure:SetText(lureText)

  frame.event:SetText(ns.Events:Headline() or "")

  if not ns.db.key and not ns.db.doubleClick then
    frame.values.next:SetText("|cffff5555/tb bind|r")
  else
    frame.values.next:SetText(engine.nextLabel or "")
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

function HUD:Alert(text)
  ns:Print(text)
  if not ns.db.alerts then return end
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
  end
  PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
end
