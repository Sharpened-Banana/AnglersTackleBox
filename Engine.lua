-- One-Key Engine. The addon decides what the next keypress does; it never
-- presses the key. Every protected action below happens inside Blizzard's
-- secure button, triggered by the player's own hardware event.
--
-- States: OFF, READY, PREP (ready, but the next press is a prep action),
-- CHANNELING, LOOTING, PAUSED. Transitions come from game events.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Engine = ns:NewModule("Engine")
Engine.state = "OFF"

-- One hidden secure button does every protected action.
local btn = CreateFrame("Button", "TackleboxActionButton", UIParent, "SecureActionButtonTemplate")
btn:RegisterForClicks("AnyUp", "AnyDown") -- works whichever key-down setting the player uses

local MOUSE_BUTTONS = { [1] = "LeftButton", [2] = "RightButton", [3] = "MiddleButton" }

-- Is the physical fishing key still down? Modifiers are stripped first.
local function KeyHeld(key)
  local base = key:sub(-1) == "-" and "-" or (key:match("([^-]+)$") or key)
  local mouse = tonumber(base:match("^BUTTON(%d+)$"))
  if mouse then
    return IsMouseButtonDown(MOUSE_BUTTONS[mouse] or ("Button" .. mouse))
  end
  local ok, down = pcall(IsKeyDown, base)
  return ok and down or false
end

local function ShouldPause()
  return IsMounted() or UnitIsDeadOrGhost("player")
end

-- The double-click binding has its own owner so re-arming the key never
-- clears it mid-click.
local clickOwner = CreateFrame("Frame")

local function Release()
  ClearOverrideBindings(btn)
  ClearOverrideBindings(clickOwner)
  Engine.armed = nil
end

local function SetState(state)
  Engine.state = state
  ns.HUD:Refresh()
end

-- Point the key at the next action. Safe to call as often as needed: it
-- does nothing when the right action is already armed.
function Engine:Rearm()
  if self.state == "OFF" or self.state == "PAUSED" then return end
  if InCombatLockdown() then return end -- Core re-arms after combat
  local key = ns.db.key -- may be nil for double-click-only players

  -- Never rebind mid-press. This timer only rebinds; it never acts.
  if key and KeyHeld(key) then
    if not self.retrying then
      self.retrying = true
      C_Timer.After(0.05, function()
        Engine.retrying = false
        Engine:Rearm()
      end)
    end
    return
  end

  if self.state == "CHANNELING" then
    if self.armed ~= "reel" then
      Release()
      if key then SetOverrideBinding(btn, true, key, Compat.INTERACT) end -- next press reels in
      self.armed, self.action = "reel", nil
      self.nextLabel = L["Reel in"]
      ns.HUD:Refresh()
    end
    return
  end

  local action = ns.Planner:Next()
  self.prep = action.id ~= "cast"
  if action.id ~= self.armed then
    if self.action and self.action.id ~= action.id then
      ns.Planner:ClearAttempts(self.action.id)
    end
    Release()
    btn:SetAttribute("type", action.type)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("item", nil)
    btn:SetAttribute("toy", nil)
    btn:SetAttribute(action.type, action.value)
    btn:SetAttribute("target-slot", action.targetSlot)
    if key then
      SetOverrideBindingClick(btn, true, key, "TackleboxActionButton") -- next press does 'action'
    end
    self.armed, self.action = action.id, action
    self.nextLabel = action.label
  end
  -- LOOTING arms the same way but keeps its name until the loot closes.
  if self.state ~= "LOOTING" then self.state = self.prep and "PREP" or "READY" end
  ns.HUD:Refresh()
end

-- Mounted or dead: hand the key back until that ends.
function Engine:Evaluate()
  if self.state == "OFF" or ns.Core.suspended or InCombatLockdown() then return end
  if ShouldPause() then
    if self.state ~= "PAUSED" then
      Release()
      self.nextLabel = nil
      SetState("PAUSED")
    end
  else
    if self.state == "PAUSED" then
      self.state = Compat.IsFishingChannelActive() and "CHANNELING" or "READY"
    end
    self:Rearm()
  end
end

-- The player picked a new key while fishing mode is on.
function Engine:KeyChanged()
  if self.state == "OFF" or InCombatLockdown() then return end
  Release()
  self:Evaluate()
end

function Engine:Enable()
  if ns.db.softInteract and Compat.INTERACT == "INTERACTTARGET" then
    local CVars = ns.CVars
    CVars:Set("SoftTargetInteract", 3)
    CVars:Set("SoftTargetInteractArc", 2)
    CVars:Set("SoftTargetInteractRange", 25)
    CVars:Set("SoftTargetIconGameObject", 1)
  end
  if ns.db.autoLoot then ns.CVars:Set("autoLootDefault", 1) end
  self:UpdateDoubleClick()

  if self.state == "OFF" then
    ns.Planner:Reset()
    self.state = Compat.IsFishingChannelActive() and "CHANNELING" or "READY"
  else -- resuming after combat
    self.state = "READY"
  end
  self:Evaluate()
end

Engine.Resume = Engine.Enable

-- Runs on PLAYER_REGEN_DISABLED, just before lockdown: the last chance to
-- give the key back before bindings freeze.
function Engine:Suspend()
  Release()
  self.nextLabel = nil
  SetState("PAUSED")
end

function Engine:Disable()
  if not InCombatLockdown() then Release() end
  self.action, self.nextLabel = nil, nil
  self.state = "OFF"
end

-- Catches changes no event announces: a lure running out, a raft about to
-- expire, a cooldown finishing.
function Engine:Tick()
  if self.state ~= "CHANNELING" then self:Rearm() end
end

---------------------------------------------------------------------------
-- Prep actions that don't take effect get counted so they can't block
-- casting forever. PostClick runs after the secure action; it does nothing
-- protected itself.
---------------------------------------------------------------------------

local lastClick = 0
btn:SetScript("PostClick", function()
  local now = GetTime()
  if now - lastClick < 0.25 then return end -- key down and key up both click
  lastClick = now
  if Engine.prep and Engine.armed ~= "reel" and Engine.armed ~= nil then
    ns.Planner:NoteAttempt(Engine.action)
    Engine.armed = nil -- re-plan, in case the action was just set aside
    C_Timer.After(0.3, function() Engine:Rearm() end)
  end
end)

---------------------------------------------------------------------------
-- Double right-click: a short right-click lends the right mouse button to
-- the action button for a moment, so a second click performs the armed
-- action. Camera drags are long presses and never trigger it. The hook is
-- only installed once the option is used, and does nothing outside
-- fishing mode.
---------------------------------------------------------------------------

local SHORT_CLICK = 0.25
local DOUBLE_CLICK_WINDOW = 0.4
local hooked, rightDownAt

local function OnWorldMouseDown(_, button)
  if button == "RightButton" and ns.Core.mode then rightDownAt = GetTime() end
end

local function OnWorldMouseUp(_, button)
  if button ~= "RightButton" or not ns.Core.mode or not ns.db.doubleClick then return end
  local downAt = rightDownAt
  rightDownAt = nil
  if not downAt or GetTime() - downAt > SHORT_CLICK then return end
  local state = Engine.state
  if state ~= "READY" and state ~= "PREP" and state ~= "LOOTING" then return end
  if InCombatLockdown() or not Engine.action then return end

  SetOverrideBindingClick(clickOwner, true, "BUTTON2", "TackleboxActionButton")
  C_Timer.After(DOUBLE_CLICK_WINDOW, function()
    if not InCombatLockdown() then ClearOverrideBindings(clickOwner) end
  end)
end

function Engine:UpdateDoubleClick()
  if ns.db.doubleClick and not hooked then
    hooked = true
    WorldFrame:HookScript("OnMouseDown", OnWorldMouseDown)
    WorldFrame:HookScript("OnMouseUp", OnWorldMouseUp)
  end
end

---------------------------------------------------------------------------
-- State transitions
---------------------------------------------------------------------------

ns:OnModeEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, _, spellID)
  if Engine.state == "PAUSED" or not Compat.IsFishingSpell(spellID) then return end
  SetState("CHANNELING")
  ns.Log:OnCast()
  Engine:Rearm()
end)

-- Catch, miss or out-of-range cast: re-arm at once so the next press casts.
ns:OnModeEvent("UNIT_SPELLCAST_CHANNEL_STOP", function()
  if Engine.state ~= "CHANNELING" then return end
  Engine.lastFishEnd = GetTime()
  Engine.state = "READY"
  Engine:Rearm()
end)

ns:OnModeEvent("LOOT_OPENED", function()
  if Engine.state ~= "READY" and Engine.state ~= "PREP" and Engine.state ~= "CHANNELING" then return end
  local recentlyFished = Engine.state == "CHANNELING"
    or (Engine.lastFishEnd ~= nil and GetTime() - Engine.lastFishEnd < 3)
  if not Compat.IsFishingLoot(recentlyFished) then return end
  Engine.state = "LOOTING"
  Engine:Rearm() -- LOOTING arms the same as READY: the next press casts
end)

ns:OnModeEvent("LOOT_CLOSED", function()
  if Engine.state ~= "LOOTING" then return end
  Engine.state = "READY"
  Engine:Rearm()
end)

-- A prep action landed (lure applied, toy used, pole equipped).
ns:OnModeEvent("UNIT_SPELLCAST_SUCCEEDED", function()
  if Engine.prep and Engine.state ~= "CHANNELING" and Engine.state ~= "PAUSED" then
    Engine.armed = nil
    Engine:Rearm()
  end
end)

ns:OnModeEvent("PLAYER_EQUIPMENT_CHANGED", function()
  if Engine.state ~= "CHANNELING" then Engine:Rearm() end
end)

local function Evaluate() Engine:Evaluate() end
ns:OnModeEvent("PLAYER_MOUNT_DISPLAY_CHANGED", Evaluate)
ns:OnModeEvent("PLAYER_DEAD", Evaluate)
ns:OnModeEvent("PLAYER_ALIVE", Evaluate)
ns:OnModeEvent("PLAYER_UNGHOST", Evaluate)
