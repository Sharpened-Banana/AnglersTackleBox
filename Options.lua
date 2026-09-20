-- Settings panel, slash commands and the key picker.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Options = ns:NewModule("Options")

BINDING_HEADER_TACKLEBOX = "Tacklebox"
BINDING_NAME_TACKLEBOX_TOGGLE = L["Toggle fishing mode"]

---------------------------------------------------------------------------
-- The fishing key
---------------------------------------------------------------------------

function Options:SetKey(key)
  ns.db.key = key
  if not key then
    ns:Print(L["Fishing key cleared."])
  else
    local normal = GetBindingAction(key)
    if normal and normal ~= "" then
      ns:Print(string.format(L["Fishing key set to %s. Outside fishing mode it stays bound to %s."],
        key, GetBindingName(normal) or normal))
    else
      ns:Print(string.format(L["Fishing key set to %s."], key))
    end
  end
  ns.Engine:KeyChanged()
  ns.HUD:Refresh()
end

local MODIFIER_KEYS = {
  LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
  LALT = true, RALT = true, LMETA = true, RMETA = true,
}
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function WithModifiers(key)
  return (IsAltKeyDown() and "ALT-" or "")
    .. (IsControlKeyDown() and "CTRL-" or "")
    .. (IsShiftKeyDown() and "SHIFT-" or "")
    .. key
end

local capture
function Options:CaptureKey()
  if InCombatLockdown() then
    ns:Print(L["Can't pick a key in combat."])
    return
  end
  if not capture then
    capture = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    capture:SetSize(340, 80)
    capture:SetPoint("CENTER", 0, 120)
    capture:SetFrameStrata("DIALOG")
    capture:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    capture:SetBackdropColor(0, 0, 0, 0.9)
    capture:EnableKeyboard(true)
    capture:EnableMouse(true)

    local text = capture:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(L["Press the key to fish with.\nMouse buttons 3-5 work too. Escape cancels."])

    capture:SetScript("OnKeyDown", function(frame, key)
      if MODIFIER_KEYS[key] then return end
      frame:Hide()
      if key ~= "ESCAPE" then Options:SetKey(WithModifiers(key)) end
    end)
    capture:SetScript("OnMouseDown", function(frame, button)
      local key = MOUSE_KEYS[button]
      if not key then return end
      frame:Hide()
      Options:SetKey(WithModifiers(key))
    end)
  end
  capture:Show()
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

local function BuildPanel()
  local category, layout = Settings.RegisterVerticalLayoutCategory("Tacklebox")

  local function Checkbox(tbl, defaults, key, name, tooltip, onChange)
    local setting = Settings.RegisterAddOnSetting(category, "Tacklebox_" .. key, key, tbl,
      "boolean", name, defaults[key] and true or false)
    Settings.CreateCheckbox(category, setting, tooltip)
    if onChange then setting:SetValueChangedCallback(onChange) end
  end

  local function Slider(tbl, defaults, key, name, tooltip, min, max, step, format, onChange)
    local setting = Settings.RegisterAddOnSetting(category, "Tacklebox_" .. key, key, tbl,
      "number", name, defaults[key])
    local options = Settings.CreateSliderOptions(min, max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
    Settings.CreateSlider(category, setting, options, tooltip)
    if onChange then setting:SetValueChangedCallback(onChange) end
  end

  local function Percent(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end
  local function Seconds(value) return string.format(L["%d s"], value) end
  local function UpdateHUD() ns.HUD:UpdateVisibility() end

  local db, chardb = ns.db, ns.chardb
  local defaults, charDefaults = ns.defaults, ns.charDefaults

  if CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer(L["Fishing key"], L["Pick key"],
      function() Options:CaptureKey() end,
      L["The one key that casts, reels and keeps your lure up. It only takes over while fishing mode is on."],
      true))
  end

  Checkbox(db, defaults, "alwaysOn", L["Fishing mode always on"],
    L["Turns fishing mode on by itself at login and after instances, so the key is always ready."]
      .. " " .. L["Sound and interact settings still only change while you are actually fishing."],
    function(_, value) ns.Core:SetAlwaysOn(value) end)
  Checkbox(db, defaults, "doubleClick", L["Double right-click to fish"],
    L["A quick double right-click does the same as the fishing key. Camera drags are ignored."],
    function() ns.Engine:UpdateDoubleClick() end)
  Checkbox(db, defaults, "softInteract", L["Reel in with soft interact"],
    L["Raises the soft-interact settings while fishing so the key grabs the bobber. Restored afterwards."])
  Checkbox(db, defaults, "autoLoot", L["Auto loot while fishing"],
    L["Turns auto loot on while fishing mode is on."])
  Checkbox(db, defaults, "useRaft", L["Use the fishing raft"],
    L["Starts the raft when you swim and refreshes it under 60 seconds."])

  Checkbox(db.audio, defaults.audio, "enabled", L["Focus audio"],
    L["The splash is the bite cue. Boosts sound effects while fishing, then restores your levels."])
  Slider(db.audio, defaults.audio, "sfxVolume", L["Sound effects volume"],
    L["Sound effects volume while fishing."], 0, 1, 0.05, Percent)
  Checkbox(db.audio, defaults.audio, "muteMusic", L["Mute music"], L["Mutes music while fishing."])
  Checkbox(db.audio, defaults.audio, "muteAmbience", L["Mute ambience"], L["Mutes ambience while fishing."])
  Checkbox(db.audio, defaults.audio, "backgroundSound", L["Sound in background"],
    L["Keeps sound on while the game window is in the background."])

  Checkbox(chardb, charDefaults, "gearSwap", L["Swap fishing gear"],
    L["Equips your fishing set or pole when fishing mode starts and your normal gear when it ends."]
      .. " " .. L["Name the set with /tb set."])
  Checkbox(chardb, charDefaults, "gearCombatRestore", L["Restore gear when combat starts"],
    L["Puts your normal gear back the moment you are attacked."])
  Checkbox(chardb, charDefaults, "lureEnabled", L["Keep a lure up"],
    L["Puts 'apply lure' into the one-key queue. Pick the lure with /tb lure."])
  Slider(db, defaults, "lureWarn", L["Lure warning"],
    L["Warn this long before the lure runs out."], 0, 300, 10, Seconds)

  Checkbox(db, defaults, "alerts", L["Alerts"],
    L["Screen and sound alerts for rare catches and lure warnings."])
  Checkbox(db, defaults, "eventAlerts", L["Fishing event reminders"],
    L["While fishing, reminds you shortly before a fishing contest and when it starts."])
  Checkbox(db.hud, defaults.hud, "shown", L["Show session window"],
    L["Casts, catches, value per hour and lure timer while fishing."], UpdateHUD)
  Slider(db.hud, defaults.hud, "scale", L["Session window scale"],
    L["Size of the session window."], 0.6, 2, 0.05, Percent, UpdateHUD)

  if Compat.needsPole then
    Checkbox(db, defaults, "autoPole", L["Fishing mode follows the pole"],
      L["Turns fishing mode on when you equip a fishing pole and off when you remove it."],
      function() ns.Core:UpdateAutoPole() end)
  end

  Settings.RegisterAddOnCategory(category)
  return category
end

function Options:Init()
  if Settings and Settings.RegisterVerticalLayoutCategory then
    local ok, result = pcall(BuildPanel)
    if ok then
      self.category = result
    else
      self.panelError = result
    end
  end
end

function Options:Open()
  if self.category then
    Settings.OpenToCategory(self.category:GetID())
  else
    ns:Print(L["The settings panel isn't available here; use /tb help."])
    if self.panelError then ns:Print(self.panelError) end
  end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function ItemIDFrom(text)
  return tonumber(text:match("item:(%d+)")) or tonumber(text)
end

local function ItemLabel(itemID)
  local name, link = Compat.GetItemInfo(itemID)
  return link or name or ("item:" .. itemID)
end

local function OnOff(text, current)
  if text == "on" then return true end
  if text == "off" then return false end
  return not current
end

local commands = {}

commands.help = function()
  ns:Print(L["Commands:"])
  for _, line in ipairs({
    L["/tb - toggle fishing mode"],
    L["/tb always [on|off] - keep fishing mode on all the time"],
    L["/tb bind - pick the fishing key (/tb key F sets it directly, /tb key none clears it)"],
    L["/tb lure <item link or ID> - choose the lure (/tb lure auto, /tb lure off)"],
    L["/tb extra <item link or ID> - add or remove a toy or item to keep up"],
    L["/tb raft [on|off] - use the fishing raft"],
    L["/tb doubleclick [on|off] - double right-click does the same as the key"],
    L["/tb set <equipment set name> - fishing gear set (/tb set none)"],
    L["/tb hud - show or hide the session window"],
    L["/tb stats - session and zone catch stats"],
    L["/tb reset - restart the session counters"],
    L["/tb events - fishing contest countdowns"],
    L["/tb goals - progress on unfinished fishing achievements"],
    L["/tb options - open the settings panel"],
  }) do
    print("   " .. line)
  end
end

commands.bind = function() Options:CaptureKey() end

commands.key = function(rest)
  if rest == "" then
    ns:Print(string.format(L["Fishing key: %s"], ns.db.key or L["none"]))
  elseif rest:lower() == "none" then
    Options:SetKey(nil)
  else
    Options:SetKey(rest:upper())
  end
end

commands.lure = function(rest)
  local lower = rest:lower()
  if lower == "off" then
    ns.chardb.lureEnabled = false
    ns:Print(L["Lures off."])
  elseif lower == "auto" or lower == "on" then
    ns.chardb.lureEnabled = true
    if lower == "auto" then ns.chardb.lureID = nil end
    ns:Print(L["Lures on."])
  elseif rest ~= "" then
    local itemID = ItemIDFrom(rest)
    if not itemID then
      ns:Print(L["That isn't an item link or ID."])
      return
    end
    ns.chardb.lureID = itemID
    ns.chardb.lureEnabled = true
    ns:Print(string.format(L["Lure set to %s."], ItemLabel(itemID)))
  else
    local current = ns.Lures:Current()
    ns:Print(string.format(L["Lure: %s (%s)"], current and ItemLabel(current) or L["none"],
      ns.chardb.lureEnabled and L["on"] or L["off"]))
  end
end

commands.extra = function(rest)
  local extras = ns.chardb.extras
  if rest == "" then
    if #extras == 0 then
      ns:Print(L["No extras. Add one with /tb extra <item link or ID>."])
    end
    for _, itemID in ipairs(extras) do ns:Print(ItemLabel(itemID)) end
    return
  end
  local itemID = ItemIDFrom(rest)
  if not itemID then
    ns:Print(L["That isn't an item link or ID."])
    return
  end
  for i, existing in ipairs(extras) do
    if existing == itemID then
      table.remove(extras, i)
      ns:Print(string.format(L["Removed %s."], ItemLabel(itemID)))
      return
    end
  end
  table.insert(extras, itemID)
  ns:Print(string.format(L["Added %s."], ItemLabel(itemID)))
end

commands.raft = function(rest)
  ns.db.useRaft = OnOff(rest:lower(), ns.db.useRaft)
  ns:Print(ns.db.useRaft and L["Fishing raft on."] or L["Fishing raft off."])
end

commands.set = function(rest)
  if rest == "" then
    ns:Print(string.format(L["Fishing gear set: %s"], ns.chardb.fishingSet or L["none"]))
  elseif rest:lower() == "none" then
    ns.chardb.fishingSet = nil
    ns:Print(L["Fishing gear set cleared."])
  elseif not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetID(rest) then
    ns:Print(string.format(L["No equipment set named %s."], rest))
  else
    ns.chardb.fishingSet = rest
    ns:Print(string.format(L["Fishing gear set: %s"], rest))
  end
end

commands.always = function(rest)
  ns.Core:SetAlwaysOn(OnOff(rest:lower(), ns.db.alwaysOn))
  ns:Print(ns.db.alwaysOn and L["Fishing mode is now always on. /tb still pauses it."]
    or L["Always-on is off. Toggle fishing mode with /tb."])
end

commands.doubleclick = function(rest)
  ns.db.doubleClick = OnOff(rest:lower(), ns.db.doubleClick)
  ns.Engine:UpdateDoubleClick()
  ns:Print(ns.db.doubleClick and L["Double right-click fishing on."] or L["Double right-click fishing off."])
end

commands.events = function() ns.Events:Print() end
commands.goals = function() ns.Goals:Print() end
commands.hud = function() ns.HUD:Toggle() end
commands.stats = function() ns.Log:PrintStats() end
commands.reset = function() ns.Log:ResetSession() end
commands.options = function() Options:Open() end
commands.config = commands.options

SLASH_TACKLEBOX1 = "/tacklebox"
SLASH_TACKLEBOX2 = "/tb"
SlashCmdList.TACKLEBOX = function(msg)
  local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  if command == "" then
    ns.Core:ToggleMode()
    return
  end
  local handler = commands[command:lower()]
  if handler then
    handler(rest)
  else
    commands.help()
  end
end
