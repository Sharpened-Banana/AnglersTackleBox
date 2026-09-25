-- Cast, catch and miss cues: a sound for each, and a screen glow while the line is out.
-- The game fires nothing for the bite itself, so these mark only the moments the addon can see.
local _, ns = ...
local L = ns.L

local Cues = ns:NewModule("Cues")

local MISS_WAIT = 1.5 -- a channel that ends with no loot this long after counts as a miss

Cues.moments = {
  { key = "cast", label = L["Cast"] },
  { key = "catch", label = L["Catch"] },
  { key = "miss", label = L["Miss"] },
}

Cues.colors = {
  { key = "blue", label = L["Blue"], rgb = { 0.3, 0.8, 1 } },
  { key = "green", label = L["Green"], rgb = { 0.3, 1, 0.4 } },
  { key = "gold", label = L["Gold"], rgb = { 1, 0.8, 0.2 } },
  { key = "purple", label = L["Purple"], rgb = { 0.75, 0.4, 1 } },
  { key = "white", label = L["White"], rgb = { 1, 1, 1 } },
}
local CATCH_RGB, MISS_RGB = { 0.3, 1, 0.4 }, { 1, 0.35, 0.25 }

function Cues:Color(key)
  for _, color in ipairs(self.colors) do
    if color.key == key then return color end
  end
  return self.colors[1]
end

-- Steps the glow color through the list; direction -1 goes back.
function Cues:CycleColor(direction)
  local index = 1
  for i, color in ipairs(self.colors) do
    if color.key == ns.db.cues.color then index = i end
  end
  index = (index - 1 + (direction or 1)) % #self.colors + 1
  ns.db.cues.color = self.colors[index].key
  self:Restyle()
  return self.colors[index]
end

-- The sound for a moment, or nil for none. A shared sound whose addon is gone plays nothing,
-- rather than an alert's raid-warning fallback on every cast.
function Cues:Sound(moment)
  local sound = ns.Alerts:Sound(ns.db.cues[moment .. "Sound"])
  if sound and sound.key ~= "none" then return sound end
end

function Cues:Play(moment)
  local sound = self:Sound(moment)
  if sound then ns.Alerts:PlaySound(sound.key) end
end

-- Steps a moment's sound through the choices, plays it and returns it.
function Cues:CycleSound(moment, direction)
  local key = moment .. "Sound"
  local sound = ns.Alerts:NextSound(ns.db.cues[key], direction)
  ns.db.cues[key] = sound.key
  self:Play(moment)
  return sound
end

---------------------------------------------------------------------------
-- Glow, built on first use
---------------------------------------------------------------------------

local glow

local function BuildGlow()
  glow = CreateFrame("Frame", nil, UIParent)
  glow:SetAllPoints(UIParent)
  glow:SetFrameStrata("BACKGROUND")
  glow:EnableMouse(false)
  glow.texture = glow:CreateTexture(nil, "BACKGROUND")
  glow.texture:SetAllPoints()
  glow.texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
  glow.texture:SetBlendMode("ADD")
  glow.texture:SetAlpha(0.6)
  glow.fadeIn = glow:CreateAnimationGroup()
  local alpha = glow.fadeIn:CreateAnimation("Alpha")
  alpha:SetFromAlpha(0)
  alpha:SetToAlpha(1)
  alpha:SetDuration(0.3)
  glow:Hide()
end

function Cues:ShowLine()
  local opts = ns.db.cues
  if opts.glow then
    if not glow then BuildGlow() end
    local rgb = self:Color(opts.color).rgb
    glow.texture:SetVertexColor(rgb[1], rgb[2], rgb[3])
    glow:Show()
    glow.fadeIn:Stop()
    glow.fadeIn:Play()
  end
end

function Cues:HideLine()
  if glow then glow:Hide() end
end

-- A settings change shows at once on a line already out.
function Cues:Restyle()
  if self.lineOut and ns.Engine.state == "CHANNELING" then
    self:HideLine()
    self:ShowLine()
  end
end

function Cues:Disable()
  self.lineOut = nil
  self:HideLine()
end

function Cues:Suspend()
  self:Disable()
end

---------------------------------------------------------------------------
-- The moments. Each cast ends in at most one catch or miss cue.
---------------------------------------------------------------------------

local castNumber, settled = 0, true

ns:On("CAST_START", function()
  castNumber, settled = castNumber + 1, false
  Cues.lineOut = true
  Cues:Play("cast")
  Cues:ShowLine()
end)

-- Loot can open before or after the channel stops, so a miss waits a moment for it.
ns:On("CAST_END", function()
  Cues.lineOut = nil
  Cues:HideLine()
  local cast = castNumber
  C_Timer.After(MISS_WAIT, function()
    if cast ~= castNumber or settled or not ns.Core.mode or ns.Core.suspended then return end
    settled = true
    Cues:Play("miss")
    if ns.db.cues.flashMiss then ns.Alerts:Flash(MISS_RGB) end
  end)
end)

ns:On("CAST_LOOTED", function()
  if settled then return end
  settled = true
  Cues:Play("catch")
  if ns.db.cues.flashCatch then ns.Alerts:Flash(CATCH_RGB) end
end)
