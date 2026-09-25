-- Screen, sound and flash alerts with a per-category toggle. The chat line always prints.
local ADDON, ns = ...
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
  { key = "briny", label = L["Briny Best rank-ups"] },
}

local SOUND_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Sounds\\"

-- Game sound kits, then the sounds shipped in Sounds/. The numeric ID is a
-- fallback for clients whose SOUNDKIT table lacks the name.
Alerts.sounds = {
  { key = "raidWarning", label = L["Raid warning"], kit = "RAID_WARNING", id = 8959 },
  { key = "readyCheck", label = L["Ready check"], kit = "READY_CHECK", id = 8960 },
  { key = "auction", label = L["Auction window open"], kit = "AUCTION_WINDOW_OPEN", id = 5274 },
  { key = "questComplete", label = L["Quest complete"], kit = "IG_QUEST_LIST_COMPLETE", id = 878 },
  { key = "levelUp", label = L["Level up"], kit = "LEVEL_UP", id = 888 },
  { key = "mapPing", label = L["Map ping"], kit = "MAP_PING", id = 3175 },
  { key = "plink", label = L["Plink"], file = SOUND_DIR .. "plink.ogg" },
  { key = "reelClick", label = L["Reel click"], file = SOUND_DIR .. "reel.ogg" },
  { key = "chime", label = L["Chime"], file = SOUND_DIR .. "chime.ogg" },
  { key = "fallingTone", label = L["Falling tone"], file = SOUND_DIR .. "drop.ogg" },
  { key = "water", label = L["Water"], file = SOUND_DIR .. "splash.ogg" },
  { key = "none", label = L["None"] },
}

-- Other addons' sounds through LibSharedMedia, when one of them loads it.
-- Their keys are "lsm:<name>"; ours are offered back to them as "TackleBox: <label>".
local LSM_PREFIX, LSM_OURS = "lsm:", "TackleBox: "

local function SharedMedia()
  return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function Alerts:RegisterSharedMedia()
  local lsm = SharedMedia()
  if not lsm or self.sharedRegistered then return end
  self.sharedRegistered = true
  for _, sound in ipairs(self.sounds) do
    if sound.file then lsm:Register("sound", LSM_OURS .. sound.label, sound.file) end
  end
end

function Alerts:Sound(key)
  if type(key) ~= "string" then return end
  if key:sub(1, #LSM_PREFIX) == LSM_PREFIX then
    local lsm, name = SharedMedia(), key:sub(#LSM_PREFIX + 1)
    local file = lsm and lsm:IsValid("sound", name) and lsm:Fetch("sound", name, true)
    if file then return { key = key, label = name, file = file } end
    return
  end
  for _, sound in ipairs(self.sounds) do
    if sound.key == key then return sound end
  end
end

-- Every sound on offer: ours, then shared ones, with None kept last.
function Alerts:Choices()
  local lsm = SharedMedia()
  if not lsm then return self.sounds end
  self:RegisterSharedMedia()
  local list = {}
  for index = 1, #self.sounds - 1 do list[index] = self.sounds[index] end
  for _, name in ipairs(lsm:List("sound") or {}) do
    if name ~= "None" and name:sub(1, #LSM_OURS) ~= LSM_OURS then
      list[#list + 1] = { key = LSM_PREFIX .. name, label = name }
    end
  end
  list[#list + 1] = self.sounds[#self.sounds]
  return list
end

-- Steps a sound key through Choices; direction -1 goes back.
function Alerts:NextSound(key, direction)
  local choices, index = self:Choices(), 1
  for i, sound in ipairs(choices) do
    if sound.key == key then index = i end
  end
  index = (index - 1 + (direction or 1)) % #choices + 1
  return choices[index]
end

-- A category's own sound, else the global choice, else the raid warning.
function Alerts:SoundFor(category)
  local override = category and ns.db.alertSounds[category]
  return self:Sound(override) or self:Sound(ns.db.alertSound) or self.sounds[1]
end

function Alerts:PlaySound(key)
  local sound = self:Sound(key) or self.sounds[1]
  if sound.file then
    PlaySoundFile(sound.file)
  elseif sound.id then -- "None" has neither
    PlaySound(SOUNDKIT and SOUNDKIT[sound.kit] or sound.id)
  end
end

-- Steps the global choice through the list; direction -1 goes back.
function Alerts:CycleSound(direction)
  local sound = self:NextSound(ns.db.alertSound, direction)
  ns.db.alertSound = sound.key
  return sound
end

local NPC_THROTTLE = 120

-- rgb: { r, g, b }, else the alert blue.
local flash
function Alerts:Flash(rgb)
  if not flash then
    flash = CreateFrame("Frame", nil, UIParent)
    flash:SetAllPoints(UIParent)
    flash:SetFrameStrata("FULLSCREEN_DIALOG")
    flash:EnableMouse(false)
    flash.texture = flash:CreateTexture(nil, "BACKGROUND")
    flash.texture:SetAllPoints()
    flash.texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    flash.texture:SetBlendMode("ADD")
    flash.fade = flash:CreateAnimationGroup()
    local alpha = flash.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(1.2)
    flash.fade:SetScript("OnFinished", function() flash:Hide() end)
  end
  flash.texture:SetVertexColor(unpack(rgb or { 0.3, 0.8, 1 }))
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
  if ns.db.alertFlash then self:Flash() end
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
