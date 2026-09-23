-- Addon table, saved variables, fishing-mode toggle and event plumbing. With the mode off
-- nothing registers gameplay events, runs timers or touches CVars; CVars change only while fishing ("focus").
local ADDON, ns = ...
local L, Compat = ns.L, ns.Compat

local Core = {}
ns.Core = Core
ns.modules = {}

-- Enable in load order, disable in reverse: the Engine (loaded last) arms the key after gear and lures.
function ns:NewModule(name)
  local module = { name = name }
  self[name] = module
  table.insert(self.modules, module)
  return module
end

function ns:Print(msg)
  print("|cff4fc3f7TackleBox|r: " .. tostring(msg))
end

-- Internal messages (CAST_LOOTED, CATCH, SESSION_START, SESSION_END), so the log needn't know optional modules.
local listeners = {}

function ns:On(message, handler)
  listeners[message] = listeners[message] or {}
  table.insert(listeners[message], handler)
end

function ns:Fire(message, ...)
  local handlers = listeners[message]
  if not handlers then return end
  for i = 1, #handlers do handlers[i](...) end
end

-- Reports are lists of { text = ..., header = bool }, shared by chat and the menu window.
function ns:PrintLines(lines)
  for _, line in ipairs(lines) do
    if line.header then self:Print(line.text) else print("   " .. line.text) end
  end
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
  welcomed = false,     -- first-run welcome seen
  alwaysOn = false,     -- mode starts at login and after instances
  softInteract = true,  -- raise soft-interact CVars while fishing
  classicSoftInteract = false, -- WoW Forever: reel via soft interact, not mouseover
  autoLoot = true,
  useRaft = false,
  doubleClick = false,  -- double right-click performs the armed action
  oversizedBobber = true, -- keep the Reusable Oversized Bobber up, if owned
  bobber = nil,         -- bobber toy to keep up: an item ID, "random" or nil
  eventAlerts = true,   -- fishing event reminders
  autoPole = false,     -- Classic: fishing mode follows the equipped pole
  lureWarn = 60,        -- seconds before expiry
  alerts = true,
  alertQuality = 3,     -- alert on catches of this quality and up
  alertFlash = false,   -- flash the screen edges with each alert
  valueAlert = 0,       -- gold; alert on a single catch worth at least this (0 = off)
  priceCap = 2000,      -- gold; a single fish listed above this is ignored (0 = no ceiling)
  prices = {},          -- [itemID] = last trusted auction price, for spike detection
  priceHistory = {},    -- [itemID] = up to 14 daily { day, price } points (price graph)
  ahScan = true,        -- offer a stale-price refresh at the auction house
  ahScanDays = 1,       -- prices at least this old count as stale
  mapPins = true,       -- fished spots on the world map
  afkWarning = true,
  camera = { enabled = false }, -- zoom preset while fishing
  minimap = { hide = false, angle = 215 },
  alertTypes = {},      -- [category] = false turns one kind of alert off
  sessionGoals = { catches = 0, gold = 0, minutes = 0 }, -- per-session targets (0 = off)
  alertSound = "raidWarning", -- key into Alerts.sounds; "none" plays nothing
  alertSounds = {},     -- [category] = sound key, overriding alertSound
  shareCharSettings = false, -- one set of per-character settings for all characters
  sharedChar = {},      -- the shared set, saved at logout (Profiles.lua)
  audio = {
    enabled = true,
    sfxVolume = 1.0,
    muteMusic = true,
    muteAmbience = true,
    backgroundSound = true,
  },
  hud = { shown = true, scale = 1.0, tab = "session", tabs = { "lures", "log" } },
  ids = {},             -- game IDs found at runtime (faction, currency)
  cvarBackup = {},
  characters = {},      -- [name-realm] = lifetime Stats totals (warband view)
}

ns.charDefaults = {
  gearSwap = true,
  liveSession = nil,    -- session in progress at last reload/logout (Log)
  resumeMode = nil,     -- time() of a logout with the mode on, to resume it
  gearCombatRestore = true,
  fishingSet = nil,     -- equipment set name
  cookingReagents = nil, -- [itemID] = recipe uses from the last Cooking scan (Shopping)
  poleID = nil,
  lureEnabled = true,
  lureID = nil,         -- nil = pick from Data.lures
  lureAutoSwap = false, -- when out of the picked lure, use another owned one
  extras = {},          -- item/toy IDs kept up while fishing
  spots = {},           -- [mapID] = list of places fished
  records = {},         -- personal bests
  attempts = {},        -- rare-drop attempt counters
  skill = {},           -- fishing skill-up history
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
-- CVars: backed up in saved variables before any change, so a crash can be undone next login.
---------------------------------------------------------------------------

local CVars = {}
ns.CVars = CVars

function CVars:Set(name, value)
  local current = Compat.GetCVar(name)
  if current == nil then return end -- not on this client
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
-- Mode events: registered only while fishing mode is on.
---------------------------------------------------------------------------

local modeFrame = CreateFrame("Frame")
local modeHandlers = {}

function ns:OnModeEvent(event, handler)
  modeHandlers[event] = modeHandlers[event] or {}
  table.insert(modeHandlers[event], handler)
end

-- While suspended for combat, only these events get through: Midnight makes some
-- payloads "secret" in combat, where even testing them is an error.
local ALWAYS_DELIVERED = {
  PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true, PLAYER_ENTERING_WORLD = true,
}

modeFrame:SetScript("OnEvent", function(_, event, ...)
  if Core.suspended and not ALWAYS_DELIVERED[event] then return end
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

local FOCUS_IDLE = 30 -- seconds idle before CVars are restored

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

-- A manual "off" sticks until the player turns the mode on, even with always-on.
function Core:ToggleMode()
  self.manualOff = self.mode and ns.db.alwaysOn or nil
  self:SetMode(not self.mode)
end

-- Focus = actually fishing: starts at a cast, ends after FOCUS_IDLE. Sound and interact CVars change only inside it.
function Core:Focus()
  self.lastActivity = GetTime()
  if self.focused or not self.mode or self.suspended then return end
  self.focused = true
  ForEachModule("Focus")
end

function Core:Unfocus()
  if not self.focused then return end
  self.focused = false
  ForEachModule("Unfocus", true)
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

-- Always-on: start the mode when allowed.
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

-- PLAYER_REGEN_DISABLED fires just before lockdown: the last chance to restore bindings, CVars and gear.
function Core:Suspend()
  if not self.mode or self.suspended then return end
  self.suspended = true
  ForEachModule("Suspend", true)
  if self.focused then ForEachModule("Unfocus", true) end
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
-- Always-on events: load, login, logout. None fire in combat.
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")

-- Classic: fishing mode follows the pole in the main hand.
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

-- Always-on restarts the mode after a loading screen or fight; these events are registered only while it's enabled.
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

    AnglersTackleBoxDB = AnglersTackleBoxDB or {}
    AnglersTackleBoxCharDB = AnglersTackleBoxCharDB or {}
    ApplyDefaults(AnglersTackleBoxDB, ns.defaults)
    ApplyDefaults(AnglersTackleBoxCharDB, ns.charDefaults)
    ns.db, ns.chardb = AnglersTackleBoxDB, AnglersTackleBoxCharDB

    -- Undo CVars from a session that never cleaned up.
    CVars:RestoreAll()

    ForEachModule("Init")
    Core:UpdateAutoPole()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Core:UpdateAlwaysOn()

  elseif event == "PLAYER_ENTERING_WORLD" then
    if not Core.loggedIn then
      Core.loggedIn = true
      if not ns.db.alwaysOn then frame:UnregisterEvent("PLAYER_ENTERING_WORLD") end
      ns.Welcome:Maybe()
      -- Resume a mode left on at a recent reload/logout; always-on starts itself below.
      local resume = ns.chardb.resumeMode
      ns.chardb.resumeMode = nil
      if resume and not ns.db.alwaysOn and time() - resume <= ns.Log.RESUME_WINDOW
        and not InGroupInstance() and not InCombatLockdown() then
        Core:SetMode(true, true)
      end
      -- Gear can't be swapped during logout, so restore it now.
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
      ns.chardb.resumeMode = time() -- a quick /reload turns the mode back on
      Core.loggingOut = true -- Gear keeps its backup for the next login
      ForEachModule("Disable", true)
      CVars:RestoreAll()
    end
  end
end)

---------------------------------------------------------------------------
-- Global entry points: key binding and addon compartment
---------------------------------------------------------------------------

function AnglersTackleBox_ToggleFishingMode()
  Core:ToggleMode()
end

function AnglersTackleBox_ToggleMenu()
  ns.Menu:Toggle()
end

-- Left-click opens the box; right-click is the quick fishing-mode switch.
function AnglersTackleBox_OnAddonCompartmentClick(_, button)
  if button == "RightButton" then
    Core:ToggleMode()
  else
    ns.Menu:Toggle()
  end
end
