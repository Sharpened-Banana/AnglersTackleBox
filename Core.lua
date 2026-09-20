-- Addon table, saved variables, the fishing-mode toggle and event plumbing.
-- Design rule: with fishing mode off, Tacklebox is inert. Nothing below
-- registers a gameplay event, runs a timer or touches a CVar until the
-- player turns the mode on. Even with the mode on, CVars only change while
-- the player is actually fishing ("focus"), so the mode can stay on all day.
local ADDON, ns = ...
local L, Compat = ns.L, ns.Compat

local Core = {}
ns.Core = Core
ns.modules = {}

-- Modules enable in load order and disable in reverse, so the Engine
-- (loaded last) arms the key after gear and lures are ready.
function ns:NewModule(name)
  local module = { name = name }
  self[name] = module
  table.insert(self.modules, module)
  return module
end

function ns:Print(msg)
  print("|cff4fc3f7Tacklebox|r: " .. tostring(msg))
end

function ns.FormatTime(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

ns.defaults = {
  key = nil,            -- the one fishing key, e.g. "F" or "SHIFT-BUTTON4"
  alwaysOn = false,     -- fishing mode turns itself on at login and after instances
  softInteract = true,  -- raise the soft-interact CVars while fishing
  autoLoot = true,
  useRaft = false,
  doubleClick = false,  -- double right-click performs the armed action
  eventAlerts = true,   -- fishing event reminders while fishing
  autoPole = false,     -- Classic: fishing mode follows the equipped pole
  lureWarn = 60,        -- seconds before expiry
  alerts = true,
  alertQuality = 3,     -- alert on catches of this quality and up
  alertFlash = false,   -- flash the screen edges with each alert
  alertTypes = {},      -- [category] = false turns one kind of alert off
  audio = {
    enabled = true,
    sfxVolume = 1.0,
    muteMusic = true,
    muteAmbience = true,
    backgroundSound = true,
  },
  hud = { shown = true, scale = 1.0 },
  ids = {},             -- game IDs discovered at runtime (faction, currency)
  cvarBackup = {},
}

ns.charDefaults = {
  gearSwap = true,
  gearCombatRestore = true,
  fishingSet = nil,     -- equipment set name
  poleID = nil,
  lureEnabled = true,
  lureID = nil,         -- nil = pick from Data.lures
  extras = {},          -- item/toy IDs kept up while fishing
  log = {},
  sessions = {},
  daily = {},
}

local function ApplyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then target[key] = {} end
      ApplyDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

---------------------------------------------------------------------------
-- CVars: every change is backed up in the saved variables first, so a
-- crash or disconnect can still be undone at the next login.
---------------------------------------------------------------------------

local CVars = {}
ns.CVars = CVars

function CVars:Set(name, value)
  local current = Compat.GetCVar(name)
  if current == nil then return end -- CVar doesn't exist on this client
  value = tostring(value)
  local backup = ns.db.cvarBackup
  if backup[name] == nil then backup[name] = current end
  if current ~= value then Compat.SetCVar(name, value) end
end

function CVars:RestoreAll()
  local backup = ns.db.cvarBackup
  for name, value in pairs(backup) do
    if Compat.GetCVar(name) ~= value then Compat.SetCVar(name, value) end
    backup[name] = nil
  end
end

---------------------------------------------------------------------------
-- Mode events: registered when fishing mode turns on, dropped when it
-- turns off.
---------------------------------------------------------------------------

local modeFrame = CreateFrame("Frame")
local modeHandlers = {}

function ns:OnModeEvent(event, handler)
  modeHandlers[event] = modeHandlers[event] or {}
  table.insert(modeHandlers[event], handler)
end

modeFrame:SetScript("OnEvent", function(_, event, ...)
  local handlers = modeHandlers[event]
  if not handlers then return end
  for i = 1, #handlers do handlers[i](...) end
end)

local function RegisterModeEvents()
  for event in pairs(modeHandlers) do
    if event:find("^UNIT_") then
      pcall(modeFrame.RegisterUnitEvent, modeFrame, event, "player")
    else
      pcall(modeFrame.RegisterEvent, modeFrame, event)
    end
  end
end

---------------------------------------------------------------------------
-- Fishing mode
---------------------------------------------------------------------------

Core.mode = false
Core.suspended = false
Core.focused = false

local FOCUS_IDLE = 30 -- seconds without fishing before CVars go back

local function ForEachModule(method, reverse)
  local first, last, step = 1, #ns.modules, 1
  if reverse then first, last, step = last, 1, -1 end
  for i = first, last, step do
    local module = ns.modules[i]
    if module[method] then module[method](module) end
  end
end

local function InGroupInstance()
  local inInstance, instanceType = IsInInstance()
  return inInstance and (instanceType == "party" or instanceType == "raid"
    or instanceType == "pvp" or instanceType == "arena")
end

function Core:SetMode(on, quiet)
  on = on and true or false
  if on == self.mode then return end

  if InCombatLockdown() then
    if on then
      ns:Print(L["Can't start fishing mode in combat."])
    else
      self.offAfterCombat = true
      ns:Print(L["Fishing mode will turn off when combat ends."])
    end
    return
  end

  if on then
    if InGroupInstance() then
      ns:Print(L["Fishing mode stays off inside dungeons, raids and PvP."])
      return
    end
    self.mode = true
    self.suspended = false
    RegisterModeEvents()
    ForEachModule("Enable")
    self.ticker = C_Timer.NewTicker(1, function() Core:Tick() end)
    if not quiet then ns:Print(L["Fishing mode on."]) end
    if not quiet and not ns.db.key and not ns.db.doubleClick then
      ns:Print(L["No fishing key set yet. Type /tb bind to pick one."])
    end
  else
    self.mode = false
    self.suspended = false
    self.offAfterCombat = nil
    if self.ticker then self.ticker:Cancel() self.ticker = nil end
    modeFrame:UnregisterAllEvents()
    ForEachModule("Disable", true)
    self:Unfocus()
    CVars:RestoreAll()
    if not quiet then ns:Print(L["Fishing mode off."]) end
  end
end

-- A manual "off" holds until the player turns the mode back on, even when
-- always-on would otherwise restart it at the next loading screen.
function Core:ToggleMode()
  self.manualOff = self.mode and ns.db.alwaysOn or nil
  self:SetMode(not self.mode)
end

-- Focus: the player is actually fishing. Starts at a cast, ends after a
-- short idle. Sound and interact CVars are only changed inside it.
function Core:Focus()
  self.lastActivity = GetTime()
  if self.focused or not self.mode or self.suspended then return end
  self.focused = true
  ForEachModule("Focus")
end

function Core:Unfocus()
  if not self.focused then return end
  self.focused = false
  CVars:RestoreAll()
end

function Core:Tick()
  if not self.mode or self.suspended then return end
  if self.focused and ns.Engine.state ~= "CHANNELING"
    and GetTime() - (self.lastActivity or 0) > FOCUS_IDLE then
    self:Unfocus()
  end
  ForEachModule("Tick")
end

-- Always-on: start the mode whenever that is possible and wanted.
function Core:AutoStart()
  if not ns.db.alwaysOn or self.mode or self.manualOff or InGroupInstance() then return end
  if InCombatLockdown() then
    self.startAfterCombat = true
    return
  end
  self:SetMode(true, true)
end

function Core:SetAlwaysOn(on)
  ns.db.alwaysOn = on and true or false
  self.manualOff = nil
  self:UpdateAlwaysOn()
  self:AutoStart()
end

-- Combat: PLAYER_REGEN_DISABLED fires just before lockdown begins, which is
-- the last moment bindings, CVars and gear can still be put back.
function Core:Suspend()
  if not self.mode or self.suspended then return end
  self.suspended = true
  ForEachModule("Suspend", true)
  self.focused = false
  CVars:RestoreAll()
end

function Core:Resume()
  if not self.mode or not self.suspended then return end
  self.suspended = false
  ForEachModule("Resume")
end

ns:OnModeEvent("PLAYER_REGEN_DISABLED", function() Core:Suspend() end)

ns:OnModeEvent("PLAYER_REGEN_ENABLED", function()
  if Core.offAfterCombat then
    Core:SetMode(false)
  else
    Core:Resume()
  end
end)

ns:OnModeEvent("PLAYER_ENTERING_WORLD", function()
  if InGroupInstance() then Core:SetMode(false, ns.db.alwaysOn) end
end)

---------------------------------------------------------------------------
-- Always-on events: load, login, logout. Nothing here fires in combat.
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

-- Classic option: fishing mode follows the pole in the main hand.
local function OnEquipmentChanged(slot)
  if slot ~= Compat.MAINHAND or Core.suspended then return end
  if ns.Gear.lastSwap and GetTime() - ns.Gear.lastSwap < 2 then return end
  local poleEquipped = ns.Gear:PoleEquipped()
  if poleEquipped and not Core.mode then
    Core.autoStarted = true
    Core:SetMode(true)
  elseif not poleEquipped and Core.mode and Core.autoStarted then
    Core.autoStarted = nil
    Core:SetMode(false)
  end
end

-- Always-on needs two cheap, non-combat events to restart the mode after a
-- loading screen or a fight. They are only registered while it is enabled.
function Core:UpdateAlwaysOn()
  if ns.db.alwaysOn then
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  else
    frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if Core.loggedIn then frame:UnregisterEvent("PLAYER_ENTERING_WORLD") end
  end
end

function Core:UpdateAutoPole()
  if Compat.needsPole and ns.db.autoPole then
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  else
    frame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
  end
end

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    frame:UnregisterEvent("ADDON_LOADED")

    TackleboxDB = TackleboxDB or {}
    TackleboxCharDB = TackleboxCharDB or {}
    ApplyDefaults(TackleboxDB, ns.defaults)
    ApplyDefaults(TackleboxCharDB, ns.charDefaults)
    ns.db, ns.chardb = TackleboxDB, TackleboxCharDB

    -- Leftovers from a session that never got to clean up.
    CVars:RestoreAll()

    ForEachModule("Init")
    Core:UpdateAutoPole()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Core:UpdateAlwaysOn()

  elseif event == "PLAYER_ENTERING_WORLD" then
    if not Core.loggedIn then
      Core.loggedIn = true
      if not ns.db.alwaysOn then frame:UnregisterEvent("PLAYER_ENTERING_WORLD") end
      -- Gear can't be swapped back during logout, so finish that job now.
      if ns.chardb.gearBackup then
        C_Timer.After(2, function()
          if (not Core.mode or ns.db.alwaysOn) and not InCombatLockdown() then ns.Gear:Restore() end
        end)
      end
    end
    Core:AutoStart()

  elseif event == "PLAYER_REGEN_ENABLED" then
    if Core.startAfterCombat then
      Core.startAfterCombat = nil
      Core:AutoStart()
    end

  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    OnEquipmentChanged(arg1)

  elseif event == "PLAYER_LOGOUT" then
    if Core.mode then
      Core.loggingOut = true -- Gear keeps its backup for the next login
      ForEachModule("Disable", true)
      CVars:RestoreAll()
    end
  end
end)

---------------------------------------------------------------------------
-- Global entry points: key binding and addon compartment
---------------------------------------------------------------------------

function Tacklebox_ToggleFishingMode()
  Core:ToggleMode()
end

function Tacklebox_OnAddonCompartmentClick(_, button)
  if button == "RightButton" then
    ns.Options:Open()
  else
    Core:ToggleMode()
  end
end
