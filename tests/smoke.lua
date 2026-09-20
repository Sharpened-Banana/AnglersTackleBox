-- Headless smoke test: stubs the WoW API and drives one fishing session
-- through the state machine. Run from the repo root: lua tests/smoke.lua
local ROOT = "./"
local now, timers, frames, bindings, cvars = 100, {}, {}, {}, {
  Sound_SFXVolume="0.4", Sound_MusicVolume="0.6", Sound_AmbienceVolume="0.5", Sound_EnableAllSound="1",
  Sound_EnableSFX="1", Sound_EnableSoundWhenGameIsInBG="0", SoftTargetInteract="1", SoftTargetInteractArc="0",
  SoftTargetInteractRange="10", SoftTargetIconGameObject="0", autoLootDefault="0" }
local combat, mounted, keydown, swimming = false, false, false, false
local auras, counts, loot = {}, {}, {}
local function Frame(name)
  local f = { events = {}, scripts = {}, attrs = {}, name = name, shown = true }
  local function noop() end
  setmetatable(f, { __index = function(_, k)
    if k:find("^Get") then return function() return nil end end
    return noop end })
  function f:RegisterEvent(e) self.events[e] = true end
  function f:RegisterUnitEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:UnregisterAllEvents() self.events = {} end
  function f:SetScript(s, fn) self.scripts[s] = fn end
  function f:SetAttribute(k, v) self.attrs[k] = v end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:SetShown(v) self.shown = v and true or false end
  function f:IsShown() return self.shown end
  function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
  function f:CreateFontString() return Frame() end
  frames[#frames + 1] = f
  if name then _G[name] = f end
  return f
end
CreateFrame = function(_, name) return Frame(name) end
UIParent = {}
function fire(event, ...)
  for _, f in ipairs(frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end
function advance(dt)
  now = now + dt
  local due = {}
  for i = #timers, 1, -1 do if timers[i].at <= now then table.insert(due, table.remove(timers, i)) end end
  for _, t in ipairs(due) do t.fn(); if t.every and not t.cancelled then t.at = now + t.every; table.insert(timers, t) end end
end
C_Timer = { After = function(d, fn) table.insert(timers, { at = now + d, fn = fn }) end,
  NewTicker = function(d, fn) local t = { at = now + d, fn = fn, every = d }
    function t:Cancel() self.cancelled = true; for i, x in ipairs(timers) do if x == self then table.remove(timers, i) end end end
    table.insert(timers, t); return t end }
GetTime = function() return now end
time, date = os.time, os.date
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = 1, 1, 2
issecretvalue = function() return false end
C_Spell = { GetSpellName = function(id) if id == 131474 or id == 131476 then return "Fishing" end if id == 999 then return "Test Lure" end end }
C_Item = { GetItemInfo = function(id) return "Item" .. id, "[Item" .. id .. "]", 1, 1, 1, "", "", 1, "", 1, 250 end,
  GetItemInfoInstant = function(id) return id, "", "", "", 1, 0, 0 end,
  GetItemCount = function(id) return counts[id] or 0 end,
  GetItemSpell = function(id) if id == 555 then return "Test Lure", 999 end end,
  EquipItemByName = function() end }
C_Container = { GetItemCooldown = function() return 0, 0 end, GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() end }
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return auras[id] end }
AuraUtil = { FindAuraByName = function() end }
C_CVar = { GetCVar = function(n) return cvars[n] end, SetCVar = function(n, v) cvars[n] = tostring(v) end }
C_CurrencyInfo = { GetCoinTextureString = function(c) return c .. "c" end }
C_Map = { GetBestMapForUnit = function() return 2395 end }
C_EquipmentSet = { GetEquipmentSetID = function() end, UseEquipmentSet = function() end }
PlayerHasToy = function() return false end
InCombatLockdown = function() return combat end
inInstance = false
IsInInstance = function() return inInstance, inInstance and "party" or "none" end
IsMounted = function() return mounted end
IsSwimming = function() return swimming end
UnitIsDeadOrGhost = function() return false end
UnitChannelInfo = function() end
IsKeyDown = function() return keydown end
IsMouseButtonDown = function() return false end
GetInventoryItemID = function() end
GetInventoryItemLink = function() end
GetZoneText = function() return "Eversong Woods" end
GetSubZoneText = function() return "Fairbreeze" end
IsFishingLoot = function() return true end
GetNumLootItems = function() return #loot end
GetLootSlotType = function() return 1 end
GetLootSlotLink = function(i) return "|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h" end
GetLootSlotInfo = function(i) return 1, loot[i].name, loot[i].qty, nil, loot[i].quality end
Enum = { LootSlotType = { Item = 1 } }
-- Override bindings belong to an owner frame, as in the game.
local owners = {}
SetOverrideBinding = function(owner, _, key, action) bindings[key] = action; owners[key] = owner end
SetOverrideBindingClick = function(owner, _, key, button) bindings[key] = "CLICK " .. button; owners[key] = owner end
ClearOverrideBindings = function(owner)
  for key, keyOwner in pairs(owners) do
    if keyOwner == owner then bindings[key], owners[key] = nil, nil end
  end
end
GetBindingAction = function() return "" end
GetBindingName = function(a) return a end
PlaySound = function() end
SlashCmdList = {}
local realm = { weekday = 1, hour = 13, minute = 50 } -- Sunday, ten minutes before the Extravaganza
GetGameTime = function() return realm.hour, realm.minute end
C_DateAndTime = { GetCurrentCalendarTime = function() return { weekday = realm.weekday } end }
WorldFrame = Frame("WorldFrame"); WorldFrame.hooks = {}
function WorldFrame:HookScript(s, fn) self.hooks[s] = fn end
GetCategoryInfo = function(id) if id == 171 then return "Fishing" end end
GetCategoryList = function() return { 171 } end
GetCategoryNumAchievements = function() return 3 end
local ach = { { 1, "Done One", true }, { 2, "1000 Fish", false }, { 3, "Checklist", false } }
GetAchievementInfo = function(_, i) return ach[i][1], ach[i][2], 10, ach[i][3] end
GetAchievementNumCriteria = function(id) return id == 2 and 1 or 4 end
GetAchievementCriteriaInfo = function(id, i) if id == 2 then return "fish", 0, false, 412, 1000 end return "part", 0, i <= 1, 0, 1 end
local printed = {}
print_real = print
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end

local ns = {}
for _, file in ipairs({ "Locales/enUS.lua", "Compat.lua", "Data/Retail.lua", "Core.lua", "Audio.lua", "Gear.lua",
  "Lures.lua", "Log.lua", "HUD.lua", "Events.lua", "Goals.lua", "Midnight.lua", "Planner.lua", "Engine.lua", "Options.lua" }) do
  assert(loadfile(ROOT .. file))("Tacklebox", ns)
end
local btn = TackleboxActionButton
local function check(cond, msg) if not cond then print_real("FAIL: " .. msg); os.exit(1) end print_real("ok   " .. msg) end
local function press() if btn.scripts.PostClick and bindings.F == "CLICK TackleboxActionButton" then btn.scripts.PostClick(btn) end end

fire("ADDON_LOADED", "Tacklebox")
check(ns.db and ns.chardb, "saved variables initialised")
check(next(bindings) == nil and #timers == 0, "inert after load: no bindings, no timers")

SlashCmdList.TACKLEBOX("key f")
check(ns.db.key == "F", "/tb key sets the key")
SlashCmdList.TACKLEBOX("")
check(ns.Core.mode and ns.Engine.state == "READY", "mode on -> READY")
check(bindings.F == "CLICK TackleboxActionButton" and btn.attrs.type == "spell" and btn.attrs.spell == "Fishing", "key armed to cast Fishing")
check(cvars.Sound_MusicVolume == "0.6" and cvars.SoftTargetInteract == "1", "mode on alone leaves CVars untouched")

keydown = true
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476)
check(cvars.Sound_MusicVolume == "0" and cvars.SoftTargetInteract == "3" and cvars.autoLootDefault == "1", "first cast: CVars raised")
check(ns.Engine.state == "CHANNELING" and bindings.F == "CLICK TackleboxActionButton", "channel start while key held: no rebind mid-press")
keydown = false; advance(0.06)
check(bindings.F == "INTERACTTARGET", "key released -> armed to reel in")

loot = { { id = 220134, name = "Test Fish", qty = 2, quality = 1 }, { id = 1, name = "Nether-Warped Egg", qty = 1, quality = 4 } }
fire("LOOT_READY"); fire("LOOT_OPENED")
check(ns.Engine.state == "LOOTING" and bindings.F == "CLICK TackleboxActionButton", "loot opened -> LOOTING, key already casts")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); fire("LOOT_CLOSED")
check(ns.Engine.state == "READY", "loot closed -> READY")
local st = ns.Log:Stats()
check(st.casts == 1 and st.catches == 1 and st.value == 750, "log: 1 cast, 1 catch, value 750c")
check(ns.chardb.log[2395][220134].count == 2 and ns.chardb.log[2395][220134].subs.Fairbreeze == 2, "log keyed by map, item, subzone")
check(st.sinceRare == 0, "rare catch resets the streak")

fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476); advance(0.06)
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
check(ns.Engine.state == "READY" and bindings.F == "CLICK TackleboxActionButton", "miss -> re-armed to cast at once")

-- lure flow
counts[555] = 3; SlashCmdList.TACKLEBOX("lure 555"); advance(1)
check(ns.Engine.state == "PREP" and btn.attrs.type == "item" and btn.attrs.item == "item:555" and btn.attrs.spell == nil, "lure missing -> key applies lure")
auras[999] = { expirationTime = now + 1800 }
press(); fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 999); advance(0.5)
check(ns.Engine.state == "READY" and btn.attrs.spell == "Fishing" and btn.attrs.item == nil, "lure applied -> back to cast")
auras[999] = nil; advance(1)
check(ns.Engine.state == "PREP", "lure gone -> prep again")
ns.Lures.auraSeen[555] = nil
for _ = 1, 3 do press(); advance(0.5) end
check(ns.Engine.state == "READY" and btn.attrs.spell == "Fishing", "lure that never lands is set aside after 3 presses")

-- combat
fire("PLAYER_REGEN_DISABLED"); combat = true
check(next(bindings) == nil and ns.Engine.state == "PAUSED", "combat: key released")
check(cvars.Sound_MusicVolume == "0.6" and cvars.SoftTargetInteract == "1", "combat: CVars restored")
advance(2); check(next(bindings) == nil, "combat: ticker leaves bindings alone")
combat = false; fire("PLAYER_REGEN_ENABLED")
check(bindings.F ~= nil and cvars.Sound_MusicVolume == "0.6", "combat over: re-armed, CVars wait for the next cast")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476); advance(0.06)
check(cvars.Sound_MusicVolume == "0", "next cast: CVars raised again")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); advance(20)
check(cvars.Sound_MusicVolume == "0", "20s idle: still focused")
advance(15)
check(cvars.Sound_MusicVolume == "0.6" and cvars.SoftTargetInteract == "1" and bindings.F ~= nil, "30s idle: CVars restored, key still armed")

-- mount
mounted = true; fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(next(bindings) == nil and ns.Engine.state == "PAUSED", "mounted: key released")
mounted = false; fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(bindings.F ~= nil, "dismounted: re-armed")

-- double right-click
SlashCmdList.TACKLEBOX("doubleclick on")
check(WorldFrame.hooks.OnMouseUp ~= nil, "double-click hooks installed only once enabled")
WorldFrame.hooks.OnMouseDown(WorldFrame, "RightButton"); advance(1); WorldFrame.hooks.OnMouseUp(WorldFrame, "RightButton")
check(bindings.BUTTON2 == nil, "camera drag (long press) does not arm the right button")
WorldFrame.hooks.OnMouseDown(WorldFrame, "RightButton"); advance(0.1); WorldFrame.hooks.OnMouseUp(WorldFrame, "RightButton")
check(bindings.BUTTON2 == "CLICK TackleboxActionButton", "short right-click arms the right button")
advance(0.5)
check(bindings.BUTTON2 == nil and bindings.F ~= nil, "right button handed back after the window; key untouched")

-- events clock
check(ns.Events:Headline() == "Stranglethorn Fishing Extravaganza in 10m", "events: headline counts down (" .. tostring(ns.Events:Headline()) .. ")")
realm.minute = 0; realm.hour = 15
check(ns.Events:Headline() == "Stranglethorn Fishing Extravaganza: 1h 0m left", "events: running contest shows time left")
realm.weekday = 7
check(ns.Events:Headline():find("Hallowfall Fishing Derby: 9h 0m left", 1, true), "events: Saturday derby runs all day")
realm.weekday = 2
check(ns.Events:Headline() == "Hallowfall Fishing Derby in 4d 9h", "events: next week's event picked (" .. ns.Events:Headline() .. ")")
SlashCmdList.TACKLEBOX("events"); SlashCmdList.TACKLEBOX("goals")
C_Reputation = { GetNumFactions = function() return 2 end,
  GetFactionDataByIndex = function(i) return i == 1 and { isHeader = true, name = "Midnight" } or { factionID = 2777, name = "Captain Tokka's Crew" } end,
  GetFactionDataByID = function() return { reaction = 5, currentStanding = 4200, currentReactionThreshold = 3000, nextReactionThreshold = 9000 } end }
FACTION_STANDING_LABEL5 = "Friendly"
C_CurrencyInfo.GetCurrencyListSize = function() return 1 end
C_CurrencyInfo.GetCurrencyListInfo = function() return { name = "Coiled Filament" } end
C_CurrencyInfo.GetCurrencyListLink = function() return "|Hcurrency:3344|h[Coiled Filament]|h" end
C_CurrencyInfo.GetCurrencyInfo = function() return { quantity = 625 } end
SlashCmdList.TACKLEBOX("midnight")
check(ns.db.ids.tokkaFaction == 2777 and ns.db.ids.filamentCurrency == 3344, "midnight: faction and currency found by name and remembered")
check(ns.Midnight:FilamentCount() == 625, "midnight: filament count read")

SlashCmdList.TACKLEBOX("stats")
SlashCmdList.TACKLEBOX("")
check(not ns.Core.mode and next(bindings) == nil and ns.Engine.state == "OFF", "mode off: bindings cleared")
check(cvars.Sound_SFXVolume == "0.4" and cvars.Sound_MusicVolume == "0.6" and cvars.autoLootDefault == "0" and cvars.SoftTargetInteractArc == "0" and next(ns.db.cvarBackup) == nil, "mode off: every CVar restored")
local live = 0; for _, f in ipairs(frames) do for e in pairs(f.events) do if e ~= "PLAYER_LOGOUT" and e ~= "PLAYER_ENTERING_WORLD" then live = live + 1 end end end
advance(5)
check(live == 0 and #timers == 0, "inert again: no gameplay events, no timers")
check(#ns.chardb.sessions == 1 and ns.chardb.sessions[1].casts == 3, "session summary saved")

-- always on
SlashCmdList.TACKLEBOX("always on")
check(ns.Core.mode and bindings.F ~= nil, "always on: mode starts by itself")
check(ns.Log.session == nil and not (TackleboxHUD and TackleboxHUD.shown), "always on: no session or window until the first cast")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476); advance(0.06)
check(ns.Log.session ~= nil and TackleboxHUD.shown, "always on: first cast opens the session and window")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); advance(601)
check(ns.Log.session == nil and not TackleboxHUD.shown and #ns.chardb.sessions == 2, "always on: session closes after 10 idle minutes")
check(ns.Core.mode and bindings.F ~= nil, "always on: key stays armed")
inInstance = true; fire("PLAYER_ENTERING_WORLD")
check(not ns.Core.mode and next(bindings) == nil, "always on: off inside a dungeon")
inInstance = false; fire("PLAYER_ENTERING_WORLD")
check(ns.Core.mode, "always on: back on after the dungeon")
SlashCmdList.TACKLEBOX(""); fire("PLAYER_ENTERING_WORLD")
check(not ns.Core.mode, "always on: a manual /tb off survives loading screens")
SlashCmdList.TACKLEBOX("always off")
print_real("--- chat output ---"); for _, l in ipairs(printed) do print_real(l) end
