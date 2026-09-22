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
  function f:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
  function f:Hide() local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
  function f:SetShown(v) self.shown = v and true or false end
  function f:IsShown() return self.shown end
  function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
  function f:CreateFontString() return Frame() end
  function f:CreateTexture() return Frame() end
  function f:GetWidth() return 1000 end
  function f:GetHeight() return 600 end
  function f:GetFrameLevel() return 1 end
  function f:GetStringHeight() return 100 end
  function f:GetText() return rawget(self, "textValue") or "" end
  function f:SetText(v) rawset(self, "textValue", v) end
  function f:HasFocus() return false end
  function f:HookScript(s, fn) local h = rawget(self, 'hooks') or {}; rawset(self, 'hooks', h); h[s] = fn end
  function f:GetCenter() return 500, 500 end
  function f:GetEffectiveScale() return 1 end
  function f:GetHighlightTexture() return Frame() end
  function f:CreateAnimationGroup() return Frame() end
  function f:CreateAnimation() return Frame() end
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
-- TB_FLAVOR=classic runs the Classic Era configuration instead.
local CLASSIC = os.getenv("TB_FLAVOR") == "classic"
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = CLASSIC and 2 or 1, 1, 2
issecretvalue = function() return false end
C_Spell = { GetSpellName = function(id) if id == 131474 or id == 131476 then return "Fishing" end if id == 999 then return "Test Lure" end end }
C_Item = { GetItemInfo = function(id) return "Item" .. id, "[Item" .. id .. "]", id == 777 and 0 or 1, 1, 1, "", "", 1, "", 1, 250 end,
  GetItemInfoInstant = function(id) return id, "", "", "", 1, 0, 0 end,
  GetItemCount = function(id) return counts[id] or 0 end,
  GetItemSpell = function(id) if id == 555 then return "Test Lure", 999 end if id == 142529 then return "Cat Head", 5005 end end,
  EquipItemByName = function() end }
C_Container = { GetItemCooldown = function() return 0, 0 end, GetContainerNumSlots = function() return 0 end, GetContainerItemID = function() end }
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return auras[id] end }
AuraUtil = { FindAuraByName = function() end }
C_CVar = { GetCVar = function(n) return cvars[n] end, SetCVar = function(n, v) cvars[n] = tostring(v) end }
C_CurrencyInfo = { GetCoinTextureString = function(c) return c .. "c" end }
C_Map = { GetBestMapForUnit = function() return 2395 end }
C_EquipmentSet = { GetEquipmentSetID = function() end, UseEquipmentSet = function() end }
toys = {}
PlayerHasToy = function(id) return toys[id] or false end
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
UnitName = function(unit) return unit == "player" and "Testfin" or nil end
GetRealmName = function() return "Silvermoon" end
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
played = {}
PlaySound = function(id) played[#played + 1] = id end
StaticPopupDialogs, CLOSE, CANCEL = {}, "Close", "Cancel"
shownPopup = nil
StaticPopup_Show = function(name) shownPopup = name end
SlashCmdList = {}
UISpecialFrames = {}
GetLocale = function() return "enUS" end
UnitGUID = function(unit) return unit == "nameplate1" and "Creature-0-1-2-3-263682-000000" or "Creature-0-1-2-3-1-000000" end
strsplit = function(sep, text) local out = {} for part in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end return table.unpack(out) end
local tooltipCalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipCalls[#tooltipCalls + 1] = fn end }
Enum.TooltipDataType = { Object = 9 }
GameTooltip = {}
function hover(name) for _, fn in ipairs(tooltipCalls) do fn(GameTooltip, { lines = { { leftText = name } } }) end end
C_MountJournal = { GetMountFromSpell = function(id) return id == 64731 and 312 or nil end, GetMountFromItem = function() end,
  GetMountInfoByID = function() return "Sea Turtle", 64731, 1, false, true, 0, false, false, nil, false, false end }
local realm = { weekday = 1, hour = 13, minute = 50 } -- Sunday, ten minutes before the Extravaganza
GetGameTime = function() return realm.hour, realm.minute end
C_DateAndTime = { GetCurrentCalendarTime = function() return { weekday = realm.weekday } end }
WorldFrame = Frame("WorldFrame"); WorldFrame.hooks = {}
WorldMapFrame = Frame("WorldMapFrame"); WorldMapFrame.shown = false
WorldMapFrame.ScrollContainer = { Child = Frame() }
function WorldMapFrame:GetMapID() return 2395 end
function WorldMapFrame.OnMapChanged() end
hooksecurefunc = function() end
Minimap = Frame("Minimap")
position = { x = 0.41, y = 0.62 }
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return position.x, position.y end } end
C_Map.GetMapInfo = function(id) return { name = id == 2395 and "Eversong Woods" or "Somewhere", mapType = 3, parentMapID = 0 } end
local zoom = 15
GetCameraZoom = function() return zoom end
CameraZoomIn = function(d) zoom = zoom - d end
CameraZoomOut = function(d) zoom = zoom + d end
UnitIsAFK = function() return false end
IsInGroup = function() return false end
IsInGuild = function() return true end
sent = {}
SendChatMessage = function(text, channel) sent[#sent + 1] = { text = text, channel = channel } end
GetProfessions = function() return nil, nil, nil, 9 end
skillLevel = 100
GetProfessionInfo = function() return "Fishing", 1, skillLevel, 300 end
GetCategoryInfo = function(id) if id == 171 then return "Fishing" end end
GetCategoryList = function() return { 171 } end
GetCategoryNumAchievements = function() return 3 end
local ach = { { 1, "Done One", true }, { 2, "1000 Fish", false }, { 3, "Checklist", false } }
GetAchievementInfo = function(_, i) return ach[i][1], ach[i][2], 10, ach[i][3] end
GetAchievementNumCriteria = function(id) return id == 2 and 1 or 4 end
GetAchievementCriteriaInfo = function(id, i) if id == 2 then return "fish", 0, false, 412, 1000 end return "part", 0, i <= 1, 0, 1 end
-- Cooking window: one recipe using a fish already in the catch log, so
-- Shopping.lua has something real to cross-reference against.
local tradeSkillOpen = false
if CLASSIC then
  GetTradeSkillLine = function() return tradeSkillOpen and "Cooking" or nil end
  GetNumTradeSkills = function() return tradeSkillOpen and 1 or 0 end
  GetTradeSkillInfo = function(i) if i == 1 then return "Test Fish Feast", nil end end
  GetTradeSkillNumReagents = function(i) return i == 1 and 1 or 0 end
  GetTradeSkillReagentInfo = function(i, r) if i == 1 and r == 1 then return "Oily Blackmouth", "", 4, 0 end end
  GetTradeSkillReagentItemLink = function(i, r)
    if i == 1 and r == 1 then return "|Hitem:6358:0|h[Oily Blackmouth]|h" end
  end
else
  C_TradeSkillUI = {
    GetTradeSkillLine = function() return tradeSkillOpen and "Cooking" or nil end,
    GetAllRecipeIDs = function() return tradeSkillOpen and { 1 } or {} end,
    GetRecipeSchematic = function(id)
      if id == 1 then
        return { name = "Test Fish Feast",
          reagentSlotSchematics = { { quantityRequired = 4, reagents = { { itemID = 220134 } } } } }
      end
    end,
  }
end
local printed = {}
print_real = print
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end

local ns = {}
if CLASSIC then
  local equipped, bagPole, enchantMS = nil, 6256, nil
  C_Item.GetItemInfoInstant = function(id) if id == 6256 then return id, "", "", "", 1, 2, 20 end return id, "", "", "", 1, 0, 0 end
  C_Item.EquipItemByName = function(item) if item == 6256 then equipped, bagPole = 6256, nil end end
  GetInventoryItemID = function(_, slot) if slot == 16 then return equipped end end
  C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end
  C_Container.GetContainerItemID = function(bag, slot) if bag == 0 and slot == 2 then return bagPole end end
  GetWeaponEnchantInfo = function() if enchantMS then return true, enchantMS end return false end
  C_Spell.GetSpellName = function(id) if id == 7620 or id == 7731 then return "Fishing" end end
  TooltipDataProcessor = nil

  for _, file in ipairs({ "Locales/enUS.lua", "Compat.lua", "Data/Classic.lua", "Core.lua", "Profiles.lua", "Audio.lua", "Gear.lua",
    "Lures.lua", "Bobbers.lua", "Log.lua", "HUD.lua", "Alerts.lua", "LogWindow.lua", "Events.lua", "Goals.lua",
    "Spots.lua", "Journal.lua", "Shopping.lua", "Gold.lua", "QoL.lua", "Broker.lua", "Records.lua", "Stats.lua",
    "Recommend.lua", "Planner.lua", "Engine.lua", "Menu.lua", "Welcome.lua", "Options.lua" }) do
    assert(loadfile(ROOT .. file))("AnglersTackleBox", ns)
  end
  local btn = AnglersTackleBoxActionButton
  local function check(cond, msg) if not cond then print_real("FAIL: " .. msg); os.exit(1) end print_real("ok   " .. msg) end
  fire("ADDON_LOADED", "AnglersTackleBox")
  SlashCmdList.ANGLERSTACKLEBOX("key f")
  ns.chardb.gearSwap = false -- first prove the one-key fallback
  SlashCmdList.ANGLERSTACKLEBOX("")
  check(ns.Core.mode and btn.attrs.type == "item" and btn.attrs.item == "item:6256", "classic: no pole in hand -> key equips the pole from the bags")
  equipped, bagPole = 6256, nil; fire("PLAYER_EQUIPMENT_CHANGED", 16)
  check(btn.attrs.type == "spell" and btn.attrs.spell == "Fishing", "classic: pole equipped -> key casts")
  counts[6530] = 5; advance(1)
  check(btn.attrs.item == "item:6530" and btn.attrs["target-slot"] == 16, "classic: best lure in the bags is applied to the pole slot")
  enchantMS = 590000; fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 1); advance(0.5)
  check(btn.attrs.spell == "Fishing" and btn.attrs["target-slot"] == nil, "classic: pole enchant seen -> back to casting")
  fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7731); advance(0.06)
  check(bindings.F == "INTERACTMOUSEOVER", "classic: reel in through mouseover interact")
  ns.db.classicSoftInteract = true; ns.Engine.armed = nil; ns.Engine:Rearm()
  check(bindings.F == "INTERACTTARGET" , "classic: soft-interact reel is available as an option")
  ns.db.classicSoftInteract = false
  loot = { { id = 6358, name = "Oily Blackmouth", qty = 1, quality = 1 } }
  fire("LOOT_READY"); fire("LOOT_OPENED"); fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); fire("LOOT_CLOSED")
  check(ns.Log:Stats().catches == 1, "classic: catch logged")
  SlashCmdList.ANGLERSTACKLEBOX(""); ns.chardb.gearSwap = true
  equipped, bagPole = nil, 6256
  SlashCmdList.ANGLERSTACKLEBOX("")
  check(equipped == 6256 and ns.chardb.gearBackup ~= nil, "classic: gear swap equips the pole and snapshots the gear")
  SlashCmdList.ANGLERSTACKLEBOX("")
  check(ns.chardb.gearBackup == nil, "classic: gear restored when the mode ends")
  local seen = {}
  for _, line in ipairs(ns.Events:Lines()) do seen[#seen + 1] = line.text end
  local events = table.concat(seen, "|")
  check(events:find("Nightfin Snapper peak", 1, true) and events:find("In season", 1, true), "classic: time-of-day and seasonal fish listed")
  check(ns.Shopping:Lines()[1].text:find("Open your Cooking", 1, true) ~= nil, "classic: shopping list waits for a profession window")
  tradeSkillOpen, counts[6358] = true, 1
  fire("TRADE_SKILL_SHOW")
  local shoppingText = {}
  for _, line in ipairs(ns.Shopping:Lines()) do shoppingText[#shoppingText + 1] = line.text end
  local shopping = table.concat(shoppingText, "|")
  check(shopping:find("Oily Blackmouth", 1, true) and shopping:find("have 1", 1, true)
    and shopping:find("Test Fish Feast", 1, true), "classic: shopping list matches a caught fish to a recipe reagent")
  check(shopping:find("Need 3 more", 1, true), "classic: shopping list shows the shortfall against the bag count")
  tradeSkillOpen, counts[6358] = false, nil
  SlashCmdList.ANGLERSTACKLEBOX("menu")
  for key in pairs(AnglersTackleBoxMenu.panels) do ns.Menu:Select(key) end
  check(AnglersTackleBoxMenu.panels.bobbers == nil and AnglersTackleBoxMenu.panels.midnight == nil, "classic: no Bobbers or Coiled Isle compartments")
  for _, key in ipairs({ "lures", "log", "gold", "goals", "events", "records", "bobbers", "midnight" }) do
    ns.db.hud.tabs = { key }; ns.db.hud.tab = key; SlashCmdList.ANGLERSTACKLEBOX(""); ns.HUD:Refresh(); SlashCmdList.ANGLERSTACKLEBOX("")
  end
  check(true, "classic: every window tab survives, including ones Classic lacks")
  SlashCmdList.ANGLERSTACKLEBOX("goals"); SlashCmdList.ANGLERSTACKLEBOX("midnight"); SlashCmdList.ANGLERSTACKLEBOX("bobber")
  local classicExport = ns.Profiles:Export()
  ns.db.classicSoftInteract = true
  check(ns.Profiles:Import(classicExport) and ns.db.classicSoftInteract == false, "classic: settings export and import round trip")
  played = {}; ns.Alerts:Fire("rare", "x")
  check(played[1] == 8959, "classic: alert sound falls back to the numeric raid warning kit")
  print_real("classic run complete")
  os.exit(0)
end
for _, file in ipairs({ "Locales/enUS.lua", "Compat.lua", "Data/Retail.lua", "Core.lua", "Profiles.lua", "Audio.lua", "Gear.lua",
  "Lures.lua", "Bobbers.lua", "Log.lua", "HUD.lua", "Alerts.lua", "LogWindow.lua", "Events.lua", "Goals.lua", "Spots.lua",
  "Journal.lua", "Shopping.lua", "Gold.lua", "QoL.lua", "Broker.lua", "Records.lua", "Stats.lua", "Recommend.lua",
  "Midnight.lua", "Planner.lua", "Engine.lua", "Menu.lua", "Welcome.lua", "Options.lua" }) do
  assert(loadfile(ROOT .. file))("AnglersTackleBox", ns)
end
local btn = AnglersTackleBoxActionButton
local function check(cond, msg) if not cond then print_real("FAIL: " .. msg); os.exit(1) end print_real("ok   " .. msg) end
local function press() if btn.scripts.PostClick and bindings.F == "CLICK AnglersTackleBoxActionButton" then btn.scripts.PostClick(btn) end end

fire("ADDON_LOADED", "AnglersTackleBox")
check(ns.db and ns.chardb, "saved variables initialised")
check(next(bindings) == nil and #timers == 0, "inert after load: no bindings, no timers")

SlashCmdList.ANGLERSTACKLEBOX("key f")
check(ns.db.key == "F", "/tb key sets the key")
SlashCmdList.ANGLERSTACKLEBOX("")
check(ns.Core.mode and ns.Engine.state == "READY", "mode on -> READY")
check(bindings.F == "CLICK AnglersTackleBoxActionButton" and btn.attrs.type == "spell" and btn.attrs.spell == "Fishing", "key armed to cast Fishing")
check(cvars.Sound_MusicVolume == "0.6" and cvars.SoftTargetInteract == "1", "mode on alone leaves CVars untouched")

keydown = true
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476)
check(cvars.Sound_MusicVolume == "0" and cvars.SoftTargetInteract == "3" and cvars.autoLootDefault == "1", "first cast: CVars raised")
check(ns.Engine.state == "CHANNELING" and bindings.F == "CLICK AnglersTackleBoxActionButton", "channel start while key held: no rebind mid-press")
keydown = false; advance(0.06)
check(bindings.F == "INTERACTTARGET", "key released -> armed to reel in")

-- a key that reads as down forever (focus lost mid-press) must not freeze the binding
keydown = true
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 131476)
advance(0.06)
check(bindings.F == "INTERACTTARGET", "stuck key: held at first, binding untouched")
advance(2)
check(bindings.F == "CLICK AnglersTackleBoxActionButton", "stuck key: re-armed to cast after the cap")
keydown = false

loot = { { id = 220134, name = "Test Fish", qty = 2, quality = 1 }, { id = 268730, name = "Nether-Warped Egg", qty = 1, quality = 1 } }
fire("LOOT_READY"); fire("LOOT_OPENED")
check(ns.Engine.state == "LOOTING" and bindings.F == "CLICK AnglersTackleBoxActionButton", "loot opened -> LOOTING, key already casts")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); fire("LOOT_CLOSED")
check(ns.Engine.state == "READY", "loot closed -> READY")
local st = ns.Log:Stats()
check(st.casts == 1 and st.catches == 1 and st.value == 750, "log: 1 cast, 1 catch, value 750c")
check(printed[#printed]:find("hatches into a mount", 1, true), "alerts: special catch matched by item ID")
check(ns.chardb.log[2395][220134].count == 2 and ns.chardb.log[2395][220134].subs.Fairbreeze == 2, "log keyed by map, item, subzone")
check(st.sinceRare == 0, "rare catch resets the streak")

fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476); advance(0.06)
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
check(ns.Engine.state == "READY" and bindings.F == "CLICK AnglersTackleBoxActionButton", "miss -> re-armed to cast at once")

-- spots, journal, gold, records, goals
local spots = ns.chardb.spots[2395]
check(spots and #spots == 1 and spots[1].n == 3 and spots[1].items[220134] == 2, "spots: the catch location is remembered")
WorldMapFrame.shown = true; ns.Spots:RefreshPins()
check(type(ns.Data.knownPools) == "table", "spots: shipped pool data table loads")
check(ns.Data.knownPools[2215] == nil or ns.Data.knownPools[2215][1].name == "Royal Ripple",
  "spots: shipped pool data, when present, has the expected shape")
local savedGetMapID = WorldMapFrame.GetMapID
function WorldMapFrame:GetMapID() return 2215 end
ns.Spots:RefreshPins() -- a zone with shipped pools but no personal spots must not error
ns.db.mapPins = false
ns.Spots:RefreshPins() -- the mapPins toggle also hides shipped pins, personal or not
ns.db.mapPins = true
WorldMapFrame.GetMapID = savedGetMapID
ns.Spots:RefreshPins()
check(ns.Journal:Fish()[1].name == "Test Fish", "journal: fish aggregated from the log")
check(ns.Recommend:Rank()[1].mapID == 2395, "recommend: the only zone with data ranks first")
local found = ns.Journal:Find("test")
check(found[1].text == "Test Fish" and found[#found].text:find("Fairbreeze", 1, true), "journal: /tb find says where you catch it")
check(#ns.Journal:Find("zzz") == 1, "journal: no match handled")
check(ns.Shopping:Lines()[1].text:find("Open your Cooking", 1, true) ~= nil, "shopping: waits for a profession window before showing anything")
tradeSkillOpen, counts[220134] = true, 1
fire("TRADE_SKILL_SHOW")
local shoppingText = {}
for _, line in ipairs(ns.Shopping:Lines()) do shoppingText[#shoppingText + 1] = line.text end
local shopping = table.concat(shoppingText, "|")
check(shopping:find("Test Fish", 1, true) and shopping:find("have 1", 1, true)
  and shopping:find("Test Fish Feast", 1, true), "shopping: cooking window scanned for a fish reagent you've caught")
check(shopping:find("Need 3 more", 1, true), "shopping: shortfall computed from bag count vs. recipe need")
tradeSkillOpen, counts[220134] = false, nil
check(ns.chardb.skill.level == 100, "goals: fishing skill tracked")
check(ns.chardb.attempts.netherEgg.n == 0, "goals: an out-of-scope cast is not an attempt")
ns.db.valueAlert = 0.02; ns.db.camera = { enabled = true, zoom = 6 }

-- session window tabs
check(AnglersTackleBoxHUD and AnglersTackleBoxHUD.shown, "session window showing")
for _, tab in ipairs({ "lures", "log", "session" }) do ns.db.hud.tab = tab; ns.HUD:Refresh() end
check(ns.Events:Headline(true) == "STV Extravaganza in 10m", "session window footer uses short event names")
counts[241145] = 2; ns.db.hud.tab = "lures"; ns.HUD:Refresh()
local lureRow = AnglersTackleBoxHUD.rows[2]
check(lureRow.onClick ~= nil, "lures tab: a lure in the bags is clickable")
lureRow.scripts.OnClick(lureRow)
check(ns.chardb.lureID == 241145, "lures tab: clicking a lure selects it")
ns.chardb.lureID = nil; counts[241145] = nil; ns.db.hud.tab = "session"

-- customisable tabs
local function tabKeys() local out = {} for _, t in ipairs(ns.HUD:Tabs()) do out[#out + 1] = t.key end return table.concat(out, ",") end
check(tabKeys() == "session,lures,log", "tabs: default is Session, Lures, Log")
ns.HUD:SetTab("gold", true); ns.HUD:SetTab("goals", true)
check(tabKeys() == "session,lures,log,gold,goals", "tabs: others can be added")
check(ns.HUD:SetTab("events", true) == false and tabKeys() == "session,lures,log,gold,goals", "tabs: full at five")
ns.HUD:SetTab("lures", false); ns.HUD:SetTab("session", false); ns.HUD:MoveTab("goals", -1)
check(tabKeys() == "session,log,goals,gold", "tabs: removable and reorderable, Session stays first")
ns.db.hud.tabs = { "bogus", "log", "log" }
check(tabKeys() == "session,log", "tabs: unknown and duplicate entries ignored")
for _, key in ipairs({ "bobbers", "gold", "goals", "events", "records", "midnight" }) do
  ns.db.hud.tabs = { key }; ns.db.hud.tab = key; ns.HUD:Refresh()
end
ns.HUD:ResetTabs()
check(tabKeys() == "session,lures,log" and ns.db.hud.tab == "session", "tabs: every catalogue tab renders; reset restores the default")

-- pools
advance(40) -- focus has lapsed, so this cast re-applies the camera
hover("Mailbox"); hover("Sunwell Swarm")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476); advance(0.06)
check(zoom == 6, "camera: zooms to the saved preset when fishing starts")
skillLevel = 101
loot = { { id = 220134, name = "Test Fish", qty = 1, quality = 1 }, { id = 238366, name = "Lynxfish", qty = 1, quality = 1 } }
fire("LOOT_READY"); fire("LOOT_OPENED"); fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); fire("LOOT_CLOSED")
local pools = ns.chardb.log[2395][220134].pools
check(pools and pools["Sunwell Swarm"] == 1 and pools.Mailbox == nil, "pool: hovered pool credited, non-pool objects ignored")
check(ns.chardb.attempts.netherEgg.n == 1, "goals: a Midnight fish makes the cast an egg attempt")
check(ns.chardb.skill.gaps and ns.chardb.skill.gaps[1] == 2, "goals: skill-up recorded as catches per point")
check(spots[1].pool == "Sunwell Swarm" and #spots == 1, "spots: same place merges, pool name attached")
local alerted = false
for _, line in ipairs(printed) do if line:find("is worth", 1, true) then alerted = true end end
check(alerted, "gold: value alert fires above the threshold")
fire("PLAYER_STARTED_MOVING")
check(ns.Log.pool == nil, "pool: forgotten once the player moves")

-- npc alert
fire("NAME_PLATE_UNIT_ADDED", "nameplate2"); local before = #printed
fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(#printed == before + 1, "alerts: Birdie announced once, other nameplates ignored")

-- lure flow
counts[555] = 3; SlashCmdList.ANGLERSTACKLEBOX("lure 555"); advance(1)
check(ns.Engine.state == "PREP" and btn.attrs.type == "item" and btn.attrs.item == "item:555" and btn.attrs.spell == nil, "lure missing -> key applies lure")
auras[999] = { expirationTime = now + 1800 }
press(); fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 999); advance(0.5)
check(ns.Engine.state == "READY" and btn.attrs.spell == "Fishing" and btn.attrs.item == nil, "lure applied -> back to cast")
auras[999] = nil; advance(1)
check(ns.Engine.state == "PREP", "lure gone -> prep again")
ns.Lures.auraSeen[555] = nil
for _ = 1, 3 do press(); advance(0.5) end
check(ns.Engine.state == "READY" and btn.attrs.spell == "Fishing", "lure that never lands is set aside after 3 presses")

-- bobbers
toys[202207] = true; toys[142529] = true; toys[142530] = true
advance(1)
check(btn.attrs.type == "toy" and btn.attrs.toy == 202207 and btn.attrs.spell == nil, "oversized bobber missing -> key uses the toy")
auras[397827] = { expirationTime = now + 3600 }
press(); fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 397827); advance(0.5)
check(btn.attrs.spell == "Fishing", "oversized bobber up -> back to cast")
SlashCmdList.ANGLERSTACKLEBOX("bobber 142529"); advance(1)
check(btn.attrs.toy == 142529, "chosen bobber toy queued when no bobber buff is up")
press(); fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 5005); advance(0.5)
check(btn.attrs.spell == "Fishing" and ns.Bobbers:Active() == 142529, "bobber toy with unreadable buff: trusted for an hour after its cast")
SlashCmdList.ANGLERSTACKLEBOX("bobber random"); advance(1)
check(btn.attrs.spell == "Fishing", "random: nothing queued while a bobber is already up")
SlashCmdList.ANGLERSTACKLEBOX("bobber off"); auras[397827] = nil; ns.db.oversizedBobber = false; advance(1)

-- auction price refresh
local ok, why = ns.Gold:Scan()
check(not ok and why:find("Auctionator", 1, true), "scan: says it needs Auctionator when it is missing")
local searched
Auctionator = { API = { v1 = {
  GetAuctionPriceByItemID = function() return 250 end,
  GetAuctionAgeByItemID = function(_, id) return id == 220134 and 3 or nil end,
  MultiSearchExact = function(_, terms) searched = terms end } } }
ok, why = ns.Gold:Scan()
check(not ok and why:find("auction house", 1, true), "scan: refuses away from the auction house")
check(ns.Gold:PricesStale(), "scan: three-day-old and never-seen prices count as stale")
AuctionHouseFrame = Frame(); fire("AUCTION_HOUSE_SHOW"); advance(1.1)
check(searched and #searched >= 2, "scan: opening the auction house searches for the logged fish")
searched = nil; ns.db.ahScan = false; fire("AUCTION_HOUSE_SHOW"); advance(1.1)
check(searched == nil, "scan: automatic refresh can be turned off")
check(ns.Gold:Lines()[1].text:find("oldest 3 days ago", 1, true), "gold report shows how old the prices are")
Auctionator.API.v1.GetAuctionPriceByItemID = function() return 9999999 end
check(ns.Log.UnitValue(777) == 250, "junk: a grey item is worth its vendor price despite a troll listing")
-- price guard
local function price(id) ns.Log.ForgetPrices() return ns.Log.UnitValue(id) end
check(price(220134) == 250 and ns.Log.suspect[220134].listed == 9999999, "guard: a tenfold spike is ignored and flagged")
local foundSuspect = false
for _, line in ipairs(ns.Gold:Lines()) do if line.text:find("counted as", 1, true) then foundSuspect = true end end
check(foundSuspect, "guard: the gold report lists the ignored price")
local realDate = date
date = function(f, t) if f == "%Y-%m-%d" and not t then return "2099-01-01" end return realDate(f, t) end
check(price(220134) == 9999999 and ns.Log.suspect[220134] == nil, "guard: a spike still there on a later day is believed")
date = realDate
Auctionator.API.v1.GetAuctionPriceByItemID = function() return 30000000 end
check(price(238366) == 250, "guard: a listing above the ceiling is ignored")
ns.db.priceCap = 0
Auctionator.API.v1.GetAuctionPriceByItemID = function() return 600 end
TSM_API = { GetCustomPriceValue = function() return 400 end }
check(price(555) == 400, "guard: the lower of Auctionator and TSM wins")
TSM_API = nil; ns.db.priceCap = 2000; ns.db.prices = {}; ns.Log.suspect = {}
ns.chardb.records.sessionValue = { value = 1, at = 1 }; ns.chardb.records.sessionCatches = { value = 1, at = 1 }
ns.Records:Reset(true)
check(ns.chardb.records.sessionValue == nil and ns.chardb.records.sessionCatches ~= nil, "records: gold records can be cleared alone")
ns.chardb.records.sessionCatches = nil
AuctionHouseFrame.shown = false; Auctionator = nil

-- share and away warning
SlashCmdList.ANGLERSTACKLEBOX("share")
check(#sent == 1 and sent[1].channel == "GUILD" and sent[1].text:find("catches", 1, true), "share: session posted to guild when not in a party")
local beforeAway = #printed
advance(250)
check(#printed > beforeAway and printed[#printed]:find("mark you away", 1, true), "away: warns after four quiet minutes")
ns.db.afkWarning = false

-- combat
fire("PLAYER_REGEN_DISABLED"); combat = true
check(next(bindings) == nil and ns.Engine.state == "PAUSED", "combat: key released")
check(cvars.Sound_MusicVolume == "0.6" and cvars.SoftTargetInteract == "1", "combat: CVars restored")
advance(2); check(next(bindings) == nil, "combat: ticker leaves bindings alone")
local castsBefore = ns.Log:Stats().casts
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476); fire("LOOT_READY"); fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(ns.Log:Stats().casts == castsBefore and ns.Engine.state == "PAUSED", "combat: no handler runs while suspended")
check(ns.Compat.AuraRemaining(397827) == nil, "combat: buffs are not read")
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
SlashCmdList.ANGLERSTACKLEBOX("doubleclick on")
check(WorldFrame.hooks.OnMouseUp ~= nil, "double-click hooks installed only once enabled")
WorldFrame.hooks.OnMouseDown(WorldFrame, "RightButton"); advance(1); WorldFrame.hooks.OnMouseUp(WorldFrame, "RightButton")
check(bindings.BUTTON2 == nil, "camera drag (long press) does not arm the right button")
WorldFrame.hooks.OnMouseDown(WorldFrame, "RightButton"); advance(0.1); WorldFrame.hooks.OnMouseUp(WorldFrame, "RightButton")
check(bindings.BUTTON2 == "CLICK AnglersTackleBoxActionButton", "short right-click arms the right button")
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
auras[456024] = { expirationTime = now + 1500 }
check(ns.Events:Headline() == "Derby Dasher: 25:00 left", "events: Derby Dasher timer takes over the headline")
auras[456024] = nil
SlashCmdList.ANGLERSTACKLEBOX("events"); SlashCmdList.ANGLERSTACKLEBOX("goals")
C_Reputation = { GetNumFactions = function() return 2 end,
  GetFactionDataByIndex = function(i) return i == 1 and { isHeader = true, name = "Midnight" } or { factionID = 2777, name = "Captain Tokka's Crew" } end,
  GetFactionDataByID = function() return { reaction = 5, currentStanding = 4200, currentReactionThreshold = 3000, nextReactionThreshold = 9000 } end }
FACTION_STANDING_LABEL5 = "Friendly"
C_CurrencyInfo.GetCurrencyListSize = function() return 1 end
C_CurrencyInfo.GetCurrencyListInfo = function() return { name = "Coiled Filament" } end
C_CurrencyInfo.GetCurrencyListLink = function() return "|Hcurrency:3344|h[Coiled Filament]|h" end
C_CurrencyInfo.GetCurrencyInfo = function() return { quantity = 625 } end
SlashCmdList.ANGLERSTACKLEBOX("midnight")
check(ns.db.ids.tokkaFaction == 2777, "midnight: faction found by name and remembered")
check(ns.Midnight:FilamentCount() == 625, "midnight: filament count read")

SlashCmdList.ANGLERSTACKLEBOX("stats")
SlashCmdList.ANGLERSTACKLEBOX("")
check(not ns.Core.mode and next(bindings) == nil and ns.Engine.state == "OFF", "mode off: bindings cleared")
check(cvars.Sound_SFXVolume == "0.4" and cvars.Sound_MusicVolume == "0.6" and cvars.autoLootDefault == "0" and cvars.SoftTargetInteractArc == "0" and next(ns.db.cvarBackup) == nil, "mode off: every CVar restored")
local live = 0; for _, f in ipairs(frames) do for e in pairs(f.events) do
  if e ~= "PLAYER_LOGOUT" and e ~= "PLAYER_ENTERING_WORLD" and e ~= "MERCHANT_SHOW" and e ~= "AUCTION_HOUSE_SHOW"
    and e ~= "TRADE_SKILL_SHOW" and e ~= "TRADE_SKILL_LIST_UPDATE" then live = live + 1 end
end end
advance(5)
check(live == 0 and #timers == 0, "inert again: no gameplay events, no timers (shop-window events for the sell helper aside)")
check(#ns.chardb.sessions == 1 and ns.chardb.sessions[1].casts == 4, "session summary saved")
check(zoom == 15, "camera: restored when fishing ends")
check(ns.chardb.records.sessionValue and ns.chardb.records.sessionCatches, "records: set when the session ends")
check(#ns.Gold:Lines() >= 4 and #ns.Records:Lines() >= 3, "gold and records reports build")
check(#ns.Recommend:Lines() >= 1, "recommend report builds")
do
  local data = ns.Stats:Data()
  check(data.casts > 0 and data.casts >= data.catches, "stats: casts counted, catches never exceed them")
  check(data.castSeconds > 0, "stats: time in the water is tracked")
  check(#ns.Stats:Lines() >= 8, "stats report builds")
  check(ns.Stats:Window(1).casts > 0, "stats: the last day includes this session")
  check(next(data.zones or {}) ~= nil, "stats: casts are counted per zone")

  local key = ns.Stats:AccountKey()
  check(key == "Testfin-Silvermoon", "account: identity key built from name and realm")
  local mirrored = ns.db.characters[key]
  check(mirrored and mirrored.casts == data.casts and mirrored.catches == data.catches
    and mirrored.value == data.value, "account: this character's totals mirrored into ns.db.characters")
  local combined, list = ns.Stats:AccountData()
  check(combined.count == 1 and combined.casts == data.casts and combined.value == data.value,
    "account: combined totals match the one known character")
  check(#list == 1 and list[1].name == "Testfin" and list[1].realm == "Silvermoon",
    "account: per-character list carries name and realm")
  local accountLines = ns.Stats:AccountLines()
  check(#accountLines >= 5, "account: warband report builds")
  local byCharacter = false
  for _, line in ipairs(accountLines) do
    if line.header and line.text == ns.L["By character"] then byCharacter = true end
  end
  check(not byCharacter, "account: no per-character breakdown clutter with a single known character")

  ns.Stats:Reset()
  check(ns.Stats:Data().casts == 0 and #ns.Stats:Lines() == 1, "stats: reset starts the totals over")
  check(ns.db.characters[key].casts == 0 and ns.db.characters[key].value == 0,
    "account: reset zeroes the mirrored account-wide slot too")
end
counts[220134] = 3
check(ns.Gold:SellLines()[1] ~= nil, "gold: sell helper prices the session's fish still in the bags")
counts[220134] = nil
-- the Angler's TackleBox window
local cursor
GetCursorInfo = function() if cursor then return "item", cursor end end
ClearCursor = function() cursor = nil end
SlashCmdList.ANGLERSTACKLEBOX("menu")
check(AnglersTackleBoxMenu and AnglersTackleBoxMenu.shown and ns.Menu.selected == "top", "menu opens on the top tray")
for _, key in ipairs({ "lures", "bobbers", "log", "journal", "shopping", "gold", "recommend", "records", "window", "goals", "events", "midnight", "settings", "top" }) do ns.Menu:Select(key) end
check(ns.Menu.selected == "top", "menu: every compartment builds and refreshes")
advance(2)
check(ns.Menu.ticker ~= nil, "menu: live refresh runs while open")
SlashCmdList.ANGLERSTACKLEBOX("log")
check(AnglersTackleBoxMenu.shown and ns.Menu.selected == "log", "/tb log switches to the catch log compartment")
SlashCmdList.ANGLERSTACKLEBOX("log")
check(not AnglersTackleBoxMenu.shown and ns.Menu.ticker == nil, "menu closes and its ticker stops")

-- upkeep
local csv, rowCount = ns.Log:ExportCSV()
check(rowCount >= 2 and csv:find("zone,map_id,item", 1, true) and csv:find('"Eversong Woods",2395,"Test Fish",220134', 1, true), "export: the catch log comes out as CSV")
SlashCmdList.ANGLERSTACKLEBOX("export")
check(AnglersTackleBoxExport and AnglersTackleBoxExport.shown, "export window opens")
local before = #ns.chardb.sessions
SlashCmdList.ANGLERSTACKLEBOX("sessions"); SlashCmdList.ANGLERSTACKLEBOX("sessions drop 1")
check(#ns.chardb.sessions == before - 1, "sessions: one can be dropped by number")
position = { x = 0.41, y = 0.62 }
check(ns.Spots:ForgetHere() and #ns.chardb.spots[2395] == 0, "spots: the spot underfoot can be forgotten")
ns.Log:ForgetZone(2395)
check(ns.chardb.log[2395] == nil and ns.chardb.spots[2395] == nil, "log: a zone can be forgotten")

-- welcome
ns.Welcome:Maybe()
check(ns.db.welcomed == true, "welcome: skipped for someone who already had a key")
ns.db.welcomed = false; SlashCmdList.ANGLERSTACKLEBOX("welcome")
check(AnglersTackleBoxWelcome.shown, "welcome: can be reopened with /tb welcome")
AnglersTackleBoxWelcome:Hide()
check(ns.db.welcomed == true and ns.Welcome.ticker == nil, "welcome: closing it marks it seen")

-- always on
local savedBefore = #ns.chardb.sessions
SlashCmdList.ANGLERSTACKLEBOX("always on")
check(ns.Core.mode and bindings.F ~= nil, "always on: mode starts by itself")
check(ns.Log.session == nil and not (AnglersTackleBoxHUD and AnglersTackleBoxHUD.shown), "always on: no session or window until the first cast")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 131476); advance(0.06)
check(ns.Log.session ~= nil and AnglersTackleBoxHUD.shown, "always on: first cast opens the session and window")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); advance(601)
check(ns.Log.session == nil and not AnglersTackleBoxHUD.shown and #ns.chardb.sessions == savedBefore + 1, "always on: session closes after 10 idle minutes")
check(ns.Core.mode and bindings.F ~= nil, "always on: key stays armed")
inInstance = true; fire("PLAYER_ENTERING_WORLD")
check(not ns.Core.mode and next(bindings) == nil, "always on: off inside a dungeon")
inInstance = false; fire("PLAYER_ENTERING_WORLD")
check(ns.Core.mode, "always on: back on after the dungeon")
SlashCmdList.ANGLERSTACKLEBOX(""); fire("PLAYER_ENTERING_WORLD")
check(not ns.Core.mode, "always on: a manual /tb off survives loading screens")
SlashCmdList.ANGLERSTACKLEBOX("always off")

-- settings profiles
local P = ns.Profiles
local sample = { a = true, b = false, n = 0.05, big = 123456789, neg = -2.5, s = "Fish: {s3:x} ;=",
  empty = "", list = { 1, 2, "three" }, nested = { deeper = { x = 1 } } }
local back = P.Parse(P.Serialize(sample))
check(back and back.a == true and back.b == false and back.n == 0.05 and back.big == 123456789 and back.neg == -2.5
  and back.s == sample.s and back.empty == "" and back.list[3] == "three" and back.nested.deeper.x == 1,
  "profiles: serialize -> parse round trip")
for _, text in ipairs({ "", "hello", "\0\1\2" }) do
  check(P.Decode(P.Encode(text)) == text, "profiles: base64 round trip (" .. #text .. " bytes)")
end
check(P.Parse("{s1:a") == nil and P.Parse("n1e999;") == nil and P.Parse("s99:ab") == nil
  and P.Parse("T junk") == nil and P.Parse("{{{{{{T}}}}}}") == nil, "profiles: parser rejects damaged or hostile input")

ns.chardb.log[9999] = { marker = true }; ns.db.prices[220134] = 42; ns.db.characters["Alt-Realm"] = { casts = 1 }; ns.db.ids.test = 1
local exported = P:Export()
check(exported:sub(1, 5) == "ATB1:" and not exported:find("[^%w%+/=:]"), "profiles: export is a tagged, edit-box-safe string")
local payload = P.Parse(P.Decode(exported:sub(6)))
local leaked = {}
for _, name in ipairs({ "prices", "characters", "cvarBackup", "ids", "welcomed", "sharedChar", "shareCharSettings", "hud.pos", "hud.tab" }) do
  if payload.account[name] ~= nil then leaked[#leaked + 1] = name end
end
for _, name in ipairs({ "log", "sessions", "spots", "records", "attempts", "skill", "daily", "gearBackup", "lifetime" }) do
  if payload.char[name] ~= nil then leaked[#leaked + 1] = name end
end
check(#leaked == 0 and payload.account.alerts ~= nil and payload.account["audio.sfxVolume"] ~= nil
  and payload.char.gearSwap ~= nil and payload.char.extras ~= nil, "profiles: export holds settings only, no data tables (" .. table.concat(leaked, ",") .. ")")

local audioTable, minimapTable = ns.db.audio, ns.db.minimap
local expect = { sfx = ns.db.audio.sfxVolume, warn = ns.db.lureWarn, gear = ns.chardb.gearSwap, rare = ns.db.alertTypes.rare,
  extras = #ns.chardb.extras, tab = ns.db.hud.tabs[1], hide = ns.db.minimap.hide }
ns.db.audio.sfxVolume = 0.3; ns.db.lureWarn = 5; ns.chardb.gearSwap = not expect.gear; ns.db.alertTypes.rare = false
ns.chardb.extras = { 1, 2, 3, 4, 5 }; ns.db.hud.tabs = { "zzz" }; ns.db.minimap.hide = not expect.hide
local applied, skipped = P:Import("  " .. exported .. "\n")
check(applied and applied > 30 and skipped == 0 and ns.db.audio.sfxVolume == expect.sfx and ns.db.lureWarn == expect.warn
  and ns.chardb.gearSwap == expect.gear and ns.db.alertTypes.rare == expect.rare and #ns.chardb.extras == expect.extras
  and ns.db.hud.tabs[1] == expect.tab and ns.db.minimap.hide == expect.hide, "profiles: import restores exported settings")
check(ns.db.audio == audioTable and ns.db.minimap == minimapTable and ns.db.prices[220134] == 42 and #ns.chardb.sessions > 0,
  "profiles: import keeps saved tables and data in place")

local hostile = "ATB1:" .. P.Encode(P.Serialize({
  account = { alwaysOn = "yes", bogus = true, prices = { [1] = 1 }, lureWarn = 30, alertSound = "airhorn",
    alertTypes = { rare = "no" }, ["hud.tabs"] = { "log", 5 }, ["audio.muteMusic"] = false, bobber = "random" },
  char = { log = {}, gearSwap = false, extras = { 7, "x" } },
}))
ns.db.audio.muteMusic = true
applied, skipped = P:Import(hostile)
check(applied == 4 and skipped == 8 and ns.db.lureWarn == 30 and ns.chardb.gearSwap == false and ns.db.bobber == "random"
  and ns.db.audio.muteMusic == false and ns.db.alwaysOn == false and ns.db.bogus == nil and ns.db.alertSound == "raidWarning"
  and ns.db.prices[220134] == 42 and ns.chardb.log[9999].marker and #ns.chardb.extras == expect.extras,
  "profiles: unknown keys and wrong types are skipped, the rest applied")
local bad = {}
for _, text in ipairs({ "", "hello", "ATB1:!!!!", "ATB1:" .. P.Encode("{s3:abc"), "ATB1:" .. P.Encode("T"),
  "ATB1:" .. P.Encode(P.Serialize({ account = { bogus = 1 } })) }) do
  local ok, message = P:Import(text)
  if ok or type(message) ~= "string" then bad[#bad + 1] = text end
end
check(#bad == 0, "profiles: garbage strings give an error, not a crash")
combat = true
check(P:Import(exported) == nil, "profiles: no import in combat")
combat = false
ns.db.bobber = nil; ns.db.lureWarn = expect.warn; ns.chardb.gearSwap = true; ns.db.audio.muteMusic = true

shownPopup = nil; SlashCmdList.ANGLERSTACKLEBOX("export settings")
check(shownPopup == "ANGLERS_TACKLEBOX_EXPORT_SETTINGS" and StaticPopupDialogs[shownPopup], "/tb export settings shows the export popup")
shownPopup = nil; SlashCmdList.ANGLERSTACKLEBOX("import")
check(shownPopup == "ANGLERS_TACKLEBOX_IMPORT_SETTINGS", "/tb import shows the import popup")
ns.db.lureWarn = 10
local dialog = { editBox = Frame() }; dialog.editBox:SetText(exported)
StaticPopupDialogs.ANGLERS_TACKLEBOX_IMPORT_SETTINGS.OnAccept(dialog)
check(ns.db.lureWarn == expect.warn, "import popup: Accept applies the pasted string")

-- same settings on all characters
ns.chardb.lureID, ns.chardb.fishingSet = 555, "Fishing"
P:SetShared(true)
check(ns.db.shareCharSettings and ns.db.sharedChar.lureID == 555 and ns.db.sharedChar.fishingSet == "Fishing", "shared: turning it on copies this character's settings")
ns.chardb.gearSwap = false; fire("PLAYER_LOGOUT")
check(ns.db.sharedChar.gearSwap == false, "shared: changes are saved back at logout")
ns.chardb.gearSwap, ns.chardb.lureID, ns.chardb.fishingSet, ns.chardb.extras = true, nil, nil, { 9 }
P:Init() -- as at the next character's login
check(ns.chardb.gearSwap == false and ns.chardb.lureID == 555 and ns.chardb.fishingSet == "Fishing" and #ns.chardb.extras == 0,
  "shared: the next login takes the shared settings")
check(ns.chardb.log[9999].marker and #ns.chardb.sessions > 0, "shared: per-character data is untouched")
P:SetShared(false)
ns.chardb.gearSwap = true; fire("PLAYER_LOGOUT")
check(ns.db.sharedChar.gearSwap == false, "shared: off means nothing is saved back")
ns.chardb.lureID, ns.chardb.fishingSet, ns.chardb.log[9999] = nil, nil, nil

-- alert sounds
ns.db.alerts, ns.db.alertTypes.rare = true, true
played = {}; ns.Alerts:Fire("rare", "x")
check(played[1] == 8959, "sound: raid warning by default")
ns.db.alertSound = "readyCheck"; played = {}; ns.Alerts:Fire("rare", "x")
check(played[1] == 8960, "sound: the chosen sound plays (numeric kit without SOUNDKIT)")
SOUNDKIT = { READY_CHECK = 4242 }; played = {}; ns.Alerts:Fire("rare", "x"); SOUNDKIT = nil
check(played[1] == 4242, "sound: SOUNDKIT name used when the client has it")
played = {}; ns.Alerts:Fire("rare", "x", true)
check(#played == 0, "sound: silent alerts stay silent")
ns.db.alertSound = "none"; played = {}; ns.Alerts:Fire("rare", "x")
check(#played == 0, "sound: None plays nothing")
SlashCmdList.ANGLERSTACKLEBOX("sound mapping rare")
played = {}; ns.Alerts:Fire("rare", "x"); ns.Alerts:Fire("lure", "y")
check(played[1] == 3175 and #played == 1, "sound: a per-kind override beats the global choice")
SlashCmdList.ANGLERSTACKLEBOX("sound default rare"); SlashCmdList.ANGLERSTACKLEBOX("sound levelup")
check(ns.db.alertSounds.rare == nil and ns.db.alertSound == "levelUp", "/tb sound sets the global sound and clears overrides")
ns.db.alertSound = "bogus"; played = {}; ns.Alerts:Fire("rare", "x")
check(played[1] == 8959, "sound: an unknown choice falls back to the raid warning")
ns.db.alertSound = "raidWarning"
SlashCmdList.ANGLERSTACKLEBOX("sound"); SlashCmdList.ANGLERSTACKLEBOX("sound test")
check(ns.Alerts:CycleSound(1).key == "readyCheck" and ns.Alerts:CycleSound(-1).key == "raidWarning"
  and ns.Alerts:CycleSound(-1).key == "none", "sound: the settings button cycles both ways")
ns.db.alertSound = "raidWarning"
SlashCmdList.ANGLERSTACKLEBOX("menu"); ns.Menu:Select("settings")
check(ns.Menu.selected == "settings", "menu: settings compartment builds with the new controls")
SlashCmdList.ANGLERSTACKLEBOX("menu")
print_real("--- chat output ---"); for _, l in ipairs(printed) do print_real(l) end
