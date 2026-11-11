-- One-Key Engine: decides what the next keypress does but never presses the key. Every
-- protected action runs in Blizzard's secure button on the player's own hardware event.
-- States: OFF, READY, PREP (next press is a prep action), CHANNELING, LOOTING, PAUSED.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Engine = ns:NewModule("Engine")
Engine.state = "OFF"

-- One hidden secure button does every protected action.
local btn = CreateFrame("Button", "AnglersTackleBoxActionButton", UIParent, "SecureActionButtonTemplate")
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

local STUCK_KEY = 1.5 -- seconds a key can read as down before it counts as stuck

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

-- Point the key at the next action; a no-op when it's already armed.
function Engine:Rearm()
  if self.state == "OFF" or self.state == "PAUSED" then return end
  if InCombatLockdown() then return end -- Core re-arms after combat
  local key = ns.db.key -- may be nil for double-click-only players

  -- Never rebind mid-press; this timer only rebinds, never acts. If the window loses
  -- focus mid-press IsKeyDown can stay true, so a hold past STUCK_KEY isn't a press.
  if key and KeyHeld(key) then
    self.heldSince = self.heldSince or GetTime()
  else
    self.heldSince = nil
  end
  if self.heldSince and GetTime() - self.heldSince < STUCK_KEY then
    if not self.retrying then
      self.retrying = true
      C_Timer.After(0.05, function()
        Engine.retrying = false
        ns.Safe(Engine.Rearm, Engine)
      end)
    end
    return
  end

  if self.state == "CHANNELING" then
    if self.armed ~= "reel" then
      Release()
      if key then SetOverrideBinding(btn, true, key, Compat.Interact()) end -- next press reels in
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
    btn:SetAttribute("useOnKeyDown", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("item", nil)
    btn:SetAttribute("toy", nil)
    btn:SetAttribute(action.type, action.value)
    btn:SetAttribute("target-slot", action.targetSlot)
    if key then
      SetOverrideBindingClick(btn, true, key, "AnglersTackleBoxActionButton") -- next press does 'action'
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
      if self.state == "CHANNELING" then self.castOpen = true end
    end
    self:Rearm()
  end
end

function Engine:KeyChanged()
  if self.state == "OFF" or InCombatLockdown() then return end
  Release()
  self:Evaluate()
end

-- Runs at the first cast: soft interact is what lets the key grab the bobber.
function Engine:Focus()
  if ns.db.softInteract and Compat.Interact() == "INTERACTTARGET" then
    local CVars = ns.CVars
    CVars:Set("SoftTargetInteract", 3)
    CVars:Set("SoftTargetInteractArc", 2)
    CVars:Set("SoftTargetInteractRange", 25)
    CVars:Set("SoftTargetIconGameObject", 1)
  end
  if ns.db.autoLoot then ns.CVars:Set("autoLootDefault", 1) end
end

function Engine:Enable()
  self:UpdateDoubleClick()

  -- Mode on, or resuming after combat: a line still out keeps the key on reel. Its CHANNEL_START
  -- may have been swallowed while suspended, so the cast is (re)opened here.
  if self.state == "OFF" then ns.Planner:Reset() end
  self.state = Compat.IsFishingChannelActive() and "CHANNELING" or "READY"
  if self.state == "CHANNELING" then
    self.castOpen = true
    ns.Core:Focus()
  end
  self:Evaluate()
end

Engine.Resume = Engine.Enable

-- Runs on PLAYER_REGEN_DISABLED, just before lockdown: the last chance to
-- give the key back before bindings freeze.
function Engine:Suspend()
  Release()
  self.nextLabel = nil
  -- An addon may not equip once the fight is on, so if the swap at this moment is refused the key
  -- itself puts the weapon back: bound here, while bindings can still change.
  local macro, key = ns.Gear:CombatWeaponMacro(), ns.db.key
  if macro and key then
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("useOnKeyDown", nil)
    btn:SetAttribute("macrotext", macro)
    SetOverrideBindingClick(btn, true, key, "AnglersTackleBoxActionButton")
    self.nextLabel = L["Equip weapon"]
  end
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
  -- A pause normally ends on a mount/death event; re-checking here means a missed one can't
  -- leave the key released.
  if self.state == "PAUSED" then
    self:Evaluate()
  elseif self.state ~= "CHANNELING" then
    self:Rearm()
  end
end

---------------------------------------------------------------------------
-- Prep actions that don't take effect are counted so they can't block casting
-- forever. PostClick runs after the secure action and does nothing protected.
---------------------------------------------------------------------------

btn:SetScript("PreClick", function(_, _, down)
  -- Letting go before the pole is on would only earn the game's "must have a fishing pole" error:
  -- skip that cast, and the next press makes it.
  if Engine.poleCast and not down then
    Engine.poleCast = nil
    if not ns.Gear:PoleEquipped() and not InCombatLockdown() then btn:SetAttribute("type", nil) end
    return
  end
  if Engine.armed == "pole" then ns.Gear:BeforePolePress()
  elseif Engine.armed == "cast" then ns.Gear:BeforeCastPress() end
end)

local lastClick = 0
btn:SetScript("PostClick", function(_, _, down)
  local now = GetTime()
  ns.Core.lastInput = now -- for the away warning
  -- Key down just equipped the pole: point the key at the cast, so letting go casts. If the pole
  -- isn't on yet by then, the game refuses that cast and the next press makes it.
  if down and Engine.armed == "pole" and ns.db.holdToCast and not InCombatLockdown() then
    ns.Planner:NoteAttempt(Engine.action)
    -- The game runs a key's action on key down or on key up, whichever the player's setting says.
    -- On key down the pole is on its way and this one release has to act; on key up nothing has
    -- run yet, so the pole is equipped here and the release casts as it normally would.
    if Compat.GetCVar("ActionButtonUseKeyDown") == "0" then
      local pole = ns.Gear:FindPole()
      if pole then Compat.EquipItemByName(pole) end
    else
      btn:SetAttribute("useOnKeyDown", false)
    end
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("item", nil)
    btn:SetAttribute("target-slot", nil)
    btn:SetAttribute("spell", Compat.FishingName())
    Engine.armed, Engine.nextLabel, Engine.poleCast = nil, L["Cast"], true
    lastClick = now
    C_Timer.After(0.3, function() ns.Safe(Engine.Rearm, Engine) end)
    return
  end
  if not down and not InCombatLockdown() then btn:SetAttribute("useOnKeyDown", nil) end
  if now - lastClick < 0.25 then return end -- key down and key up both click
  lastClick = now
  if Engine.prep and Engine.armed ~= "reel" and Engine.armed ~= nil then
    ns.Planner:NoteAttempt(Engine.action)
    Engine.armed = nil -- re-plan, in case the action was just set aside
    C_Timer.After(0.3, function() ns.Safe(Engine.Rearm, Engine) end)
  end
end)

---------------------------------------------------------------------------
-- Double right-click: a short right-click briefly binds the right button to the
-- action button, so a second click performs the armed action. Camera drags are long
-- presses and never trigger it. Hooked only once the option is used; inert outside fishing mode.
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

  SetOverrideBindingClick(clickOwner, true, "BUTTON2", "AnglersTackleBoxActionButton")
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
  if Engine.state == "PAUSED" then return end
  if not Compat.IsFishingSpell(spellID) then
    -- Maybe a way of fishing the addon doesn't know yet; fishing loot after it decides (LOOT_OPENED).
    Engine.otherChannel = { id = spellID }
    return
  end
  ns.Core:Focus()
  SetState("CHANNELING")
  Engine.castOpen = true
  ns.Log:OnCast()
  ns:Fire("CAST_START")
  Engine:Rearm()
end)

-- The end of a cast, once: the channel stopping or the loot window opening, whichever the game
-- sends first (both orders happen).
local function EndCast()
  if not Engine.castOpen then return end
  Engine.castOpen = nil
  Engine.lastFishEnd = GetTime()
  ns.Core.lastActivity = Engine.lastFishEnd
  ns:Fire("CAST_END")
end

-- Catch, miss or out-of-range cast: re-arm at once so the next press casts.
ns:OnModeEvent("UNIT_SPELLCAST_CHANNEL_STOP", function()
  if Engine.state ~= "CHANNELING" then
    if Engine.castOpen then
      EndCast() -- the loot window opened first; the cast ends now
    elseif Engine.otherChannel then
      Engine.otherChannel.stopped = GetTime()
    end
    return
  end
  EndCast()
  Engine.state = "READY"
  Engine:Rearm()
end)

-- Fishing loot right after a channel the addon didn't know (casting into an Oceanic Vortex, say):
-- that channel is a way of fishing too, from the next cast on. Retail only, where the game itself
-- says which loot is fishing loot, so gathering or opening a chest can't be learned by mistake.
local LEARN_WINDOW = 3
local function LearnChannel()
  local other = Engine.otherChannel
  Engine.otherChannel = nil
  if not other or not IsFishingLoot or Compat.IsSecret(other.id) or not other.id then return end
  if other.stopped and GetTime() - other.stopped > LEARN_WINDOW then return end
  if not IsFishingLoot() then return end
  local name = Compat.GetSpellName(other.id) or ("spell " .. other.id)
  ns.db.ids.fishingSpells = ns.db.ids.fishingSpells or {}
  ns.db.ids.fishingSpells[other.id] = name
  ns:Print(string.format(L["Learned a new way to fish: %s. From your next cast it counts like any other."], name))
end

ns:OnModeEvent("LOOT_OPENED", function()
  LearnChannel()
  if Engine.state ~= "READY" and Engine.state ~= "PREP" and Engine.state ~= "CHANNELING" then return end
  local recentlyFished = Engine.state == "CHANNELING"
    or (Engine.lastFishEnd ~= nil and GetTime() - Engine.lastFishEnd < 3)
  if not Compat.IsFishingLoot(recentlyFished) then return end
  if Engine.state == "CHANNELING" then EndCast() end
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
