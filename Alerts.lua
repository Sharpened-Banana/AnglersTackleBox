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
  { key = "goal", label = L["Session goals"] },
}

-- Alert sounds: only the game's own sound kits, played with PlaySound. Each
-- entry has its SOUNDKIT name and the numeric kit ID, so a client whose
-- SOUNDKIT table lacks the name still plays the same sound.
Alerts.sounds = {
  { key = "raidWarning", label = L["Raid warning"], kit = "RAID_WARNING", id = 8959 },
  { key = "readyCheck", label = L["Ready check"], kit = "READY_CHECK", id = 8960 },
  { key = "auction", label = L["Auction window open"], kit = "AUCTION_WINDOW_OPEN", id = 5274 },
  { key = "questComplete", label = L["Quest complete"], kit = "IG_QUEST_LIST_COMPLETE", id = 878 },
  { key = "levelUp", label = L["Level up"], kit = "LEVEL_UP", id = 888 },
  { key = "mapPing", label = L["Map ping"], kit = "MAP_PING", id = 3175 },
  { key = "none", label = L["None"] },
}

function Alerts:Sound(key)
  for _, sound in ipairs(self.sounds) do
    if sound.key == key then return sound end
  end
end

-- A category's own sound, else the global choice, else the raid warning.
function Alerts:SoundFor(category)
  local override = category and ns.db.alertSounds[category]
  return self:Sound(override) or self:Sound(ns.db.alertSound) or self.sounds[1]
end

function Alerts:PlaySound(key)
  local sound = self:Sound(key) or self.sounds[1]
  if not sound.id then return end -- "None"
  PlaySound(SOUNDKIT and SOUNDKIT[sound.kit] or sound.id)
end

-- Steps the global choice through the list; direction -1 goes back.
function Alerts:CycleSound(direction)
  local index = 1
  for i, sound in ipairs(self.sounds) do
    if sound.key == ns.db.alertSound then index = i end
  end
  index = (index - 1 + (direction or 1)) % #self.sounds + 1
  ns.db.alertSound = self.sounds[index].key
  return self.sounds[index]
end

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
  self:PlaySound(self:SoundFor(category).key)
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
