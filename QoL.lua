-- Camera zoom preset while fishing, and a warning before the AFK flag.
local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Camera zoom preset. Zoom is the only camera setting addons can read and set.
---------------------------------------------------------------------------

local Camera = ns:NewModule("Camera")

local function ZoomTo(target)
  local delta = GetCameraZoom() - target
  if delta > 0.05 then
    CameraZoomIn(delta)
  elseif delta < -0.05 then
    CameraZoomOut(-delta)
  end
end

function Camera:Save()
  ns.db.camera.zoom = GetCameraZoom()
  ns.db.camera.enabled = true
  ns:Print(string.format(L["Fishing camera saved at zoom %.1f. It applies when you start fishing."],
    ns.db.camera.zoom))
end

function Camera:Focus()
  local opts = ns.db.camera
  if not opts.enabled or not opts.zoom then return end
  self.previous = GetCameraZoom()
  ZoomTo(opts.zoom)
end

function Camera:Unfocus()
  if self.previous then ZoomTo(self.previous) end
  self.previous = nil
end

---------------------------------------------------------------------------
-- Away warning: the game flags AFK after five minutes without input, then logs out.
---------------------------------------------------------------------------

local Away = ns:NewModule("Away")

local QUIET_LIMIT = 240

function Away:Enable()
  ns.Core.lastInput = GetTime()
  self.warned = nil
end

function Away:Tick()
  if not ns.db.afkWarning or not ns.Log.session then return end
  local quiet = GetTime() - (ns.Core.lastInput or GetTime())
  if quiet < QUIET_LIMIT then
    self.warned = nil
  elseif not self.warned then
    self.warned = true
    ns.Alerts:Fire("afk", L["No key press for four minutes - the game will mark you away soon."])
  end
end

ns:OnModeEvent("PLAYER_FLAGS_CHANGED", function()
  if not ns.db.afkWarning or not ns.Log.session then return end
  if UnitIsAFK("player") then
    ns.Alerts:Fire("afk", L["You are marked away. Press a key or you will be logged out."])
  end
end)

-- Any movement counts as input too.
ns:OnModeEvent("PLAYER_STARTED_MOVING", function()
  ns.Core.lastInput = GetTime()
end)
