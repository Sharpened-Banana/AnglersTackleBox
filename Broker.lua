-- Minimap button and data broker feed. Uses LibDataBroker and LibDBIcon
-- when another addon has already loaded them; otherwise falls back to a
-- plain minimap button of its own. No library is bundled.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Broker = ns:NewModule("Broker")

local ICON = "Interface\\Icons\\Trade_Fishing"

local function OnClick(_, button)
  if button == "RightButton" then
    ns.Core:ToggleMode()
  else
    ns.Menu:Toggle()
  end
end

local function FillTooltip(tooltip)
  tooltip:AddLine("Tacklebox")
  tooltip:AddLine(ns.Core.mode and L["Fishing mode on"] or L["Fishing mode off"], 1, 1, 1)
  local stats = ns.Log:Stats()
  if stats then
    tooltip:AddLine(string.format(L["%d catches, %s, %s/hr"], stats.catches,
      Compat.CoinString(stats.value), Compat.CoinString(stats.perHour)), 1, 1, 1)
  end
  tooltip:AddLine(L["Left-click: open the box. Right-click: fishing mode."], 0.6, 0.6, 0.6)
end

function Broker:Text()
  local stats = ns.Log:Stats()
  if not stats then return ns.Core.mode and L["Ready"] or L["Off"] end
  return string.format("%d  %s", stats.catches, Compat.CoinString(stats.value))
end

-- Fallback button: sits on the minimap's edge and can be dragged around it.
local function Place(button)
  local angle = math.rad(ns.db.minimap.angle or 215)
  local radius = (Minimap:GetWidth() / 2) + 6
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function BuildButton()
  local button = CreateFrame("Button", "TackleboxMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")
  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ICON)
  icon:SetSize(19, 19)
  icon:SetPoint("CENTER")
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(52, 52)
  border:SetPoint("TOPLEFT")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button:SetScript("OnClick", OnClick)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    FillTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      Place(self)
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  Place(button)
  return button
end

function Broker:UpdateButton()
  local icons = LibStub and LibStub("LibDBIcon-1.0", true)
  if icons and self.object then
    if not self.registered then
      icons:Register("Tacklebox", self.object, ns.db.minimap)
      self.registered = true
    end
    if ns.db.minimap.hide then icons:Hide("Tacklebox") else icons:Show("Tacklebox") end
    return
  end
  if ns.db.minimap.hide then
    if self.button then self.button:Hide() end
  elseif Minimap then
    self.button = self.button or BuildButton()
    self.button:Show()
  end
end

function Broker:Init()
  local broker = LibStub and LibStub("LibDataBroker-1.1", true)
  if broker then
    self.object = broker:NewDataObject("Tacklebox", {
      type = "data source", label = "Tacklebox", icon = ICON, text = L["Off"],
      OnClick = OnClick, OnTooltipShow = FillTooltip,
    })
  end
  self:UpdateButton()
end

function Broker:Refresh()
  if self.object then self.object.text = self:Text() end
end

Broker.Enable, Broker.Disable, Broker.Tick = Broker.Refresh, Broker.Refresh, Broker.Refresh
