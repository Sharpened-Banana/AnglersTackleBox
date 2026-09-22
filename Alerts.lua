-- Alerts: one place for every screen, sound and flash alert, with a toggle
-- per category. The chat line always prints; the rest can be turned off.
local _, ns = ...
local L, Compat, Data = ns.L, ns.Compat, ns.Data

local Alerts = ns:NewModule("Alerts")

Alerts.categories = {
  { key = "mount", label = L["Mount drops"] },
  { key = "rare", label = L["Rare catches"] },
  { key = "teleport", label = L["Teleporting catches"] },
  { key = "hostile", label = L["Hostile catches"] },
  { key = "npc", label = L["Master Grenadier Birdie"] },
  { key = "lure", label = L["Lure warnings"] },
  { key = "event", label = L["Fishing events"] },
  { key = "value", label = L["Valuable catches"] },
  { key = "record", label = L["Personal records"] },
  { key = "afk", label = L["Away warnings"] },
}

local NPC_THROTTLE = 120

local flash
local function Flash()
  if not flash then
    flash = CreateFrame("Frame", nil, UIParent)
    flash:SetAllPoints(UIParent)
    flash:SetFrameStrata("FULLSCREEN_DIALOG")
    flash:EnableMouse(false)
    local texture = flash:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(0.3, 0.8, 1)
    flash.fade = flash:CreateAnimationGroup()
    local alpha = flash.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(1.2)
    flash.fade:SetScript("OnFinished", function() flash:Hide() end)
  end
  flash:Show()
  flash.fade:Stop()
  flash.fade:Play()
end

-- silent: show the text on screen without the sound or the flash.
function Alerts:Fire(category, text, silent)
  ns:Print(text)
  if not ns.db.alerts or ns.db.alertTypes[category] == false then return end
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
  end
  if silent then return end
  PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
  if ns.db.alertFlash then Flash() end
end

-- Birdie spawns while you fish on the Coiled Isle; killing her is worth rep.
ns:OnModeEvent("NAME_PLATE_UNIT_ADDED", function(unit)
  local wanted = Data.npcs.birdie
  if not wanted or ns.Core.suspended then return end
  local guid = UnitGUID(unit)
  if not guid or Compat.IsSecret(guid) then return end
  local npcID = tonumber((select(6, strsplit("-", guid))))
  if npcID ~= wanted then return end
  local now = GetTime()
  if Alerts.lastNPC and now - Alerts.lastNPC < NPC_THROTTLE then return end
  Alerts.lastNPC = now
  Alerts:Fire("npc", L["Master Grenadier Birdie is here! Killing her gives Tokka reputation."])
end)
