-- Settings export/import as text, and per-character settings shared by all characters.
-- Only allow-listed settings travel (never logs, records or prices); imports are parsed, never run as code.
local _, ns = ...
local L = ns.L

local Profiles = ns:NewModule("Profiles")

local PREFIX = "ATB1:"
local MAX_INPUT = 20000   -- characters in a pasted string
local MAX_DEPTH = 4       -- nested tables
local MAX_ENTRIES = 200   -- entries in any one table
local MAX_STRING = 200    -- characters in any one string

---------------------------------------------------------------------------
-- Allow-lists: a path into ns.db / ns.chardb, plus a kind when the default is nil or a
-- table (else the default's type). Kinds: boolean, number, string, "string|number",
-- "list:<type>", "map:<type>" (string keys).
---------------------------------------------------------------------------

-- A shared-media sound can't be checked when its addon isn't loaded here, so any "lsm:" name passes.
local function ValidSound(value)
  return ns.Alerts:Sound(value) ~= nil or (type(value) == "string" and value:match("^lsm:.") ~= nil)
end

local function ValidColor(value)
  return ns.Cues:Color(value).key == value
end

Profiles.account = {
  { "key", "string" }, { "alwaysOn" }, { "softInteract" }, { "classicSoftInteract" },
  { "autoLoot" }, { "useRaft" }, { "doubleClick" }, { "oversizedBobber" },
  { "bobber", "string|number" }, { "eventAlerts" }, { "autoPole" }, { "lureWarn" },
  { "alerts" }, { "alertQuality" }, { "alertFlash" }, { "valueAlert" }, { "priceCap" },
  { "ahScan" }, { "ahScanDays" }, { "mapPins" }, { "afkWarning" },
  { "camera.enabled" }, { "camera.zoom", "number" },
  { "minimap.hide" }, { "minimap.angle" },
  { "alertTypes", "map:boolean" },
  { "alertSound", check = ValidSound }, { "alertSounds", "map:string", check = ValidSound },
  { "audio.enabled" }, { "audio.sfxVolume" }, { "audio.muteMusic" }, { "audio.muteAmbience" },
  { "audio.backgroundSound" },
  { "cues.castSound", check = ValidSound }, { "cues.catchSound", check = ValidSound },
  { "cues.missSound", check = ValidSound }, { "cues.glow" },
  { "cues.color", check = ValidColor }, { "cues.flashCatch" }, { "cues.flashMiss" },
  { "hud.shown" }, { "hud.scale" }, { "hud.tabs", "list:string" },
  { "briny.enabled" }, { "sessionGoals.catches" }, { "sessionGoals.gold" }, { "sessionGoals.minutes" },
}

Profiles.char = {
  { "gearSwap" }, { "gearCombatRestore" }, { "fishingSet", "string" }, { "poleID", "number" },
  { "lureEnabled" }, { "lureID", "number" }, { "lureAutoSwap" }, { "extras", "list:number" },
}

local function Get(root, path)
  local node = root
  for part in path:gmatch("[^.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

local function Wipe(tbl)
  for key in pairs(tbl) do tbl[key] = nil end
  return tbl
end

local function Copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, inner in pairs(value) do out[key] = inner end
  return out
end

-- Refill tables in place: the settings panel and LibDBIcon hold references to them.
local function Set(root, path, value)
  local parts = {}
  for part in path:gmatch("[^.]+") do parts[#parts + 1] = part end
  local parent = root
  for i = 1, #parts - 1 do
    if type(parent[parts[i]]) ~= "table" then parent[parts[i]] = {} end
    parent = parent[parts[i]]
  end
  local last = parts[#parts]
  if type(value) == "table" and type(parent[last]) == "table" then
    local target = Wipe(parent[last])
    for key, inner in pairs(value) do target[key] = inner end
  else
    parent[last] = Copy(value)
  end
end

local function Index(list, defaults)
  local index = {}
  for _, entry in ipairs(list) do
    local path = entry[1]
    index[path] = { path = path, kind = entry[2] or type(Get(defaults, path)), check = entry.check }
  end
  return index
end

local function Finite(value)
  return value == value and value ~= math.huge and value ~= -math.huge
end

local function ScalarOK(kind, value)
  local actual = type(value)
  if actual == "number" then
    if not Finite(value) then return false end
  elseif actual == "string" then
    if #value > MAX_STRING then return false end
  end
  if kind == "string|number" then return actual == "string" or actual == "number" end
  return actual == kind
end

local function Valid(entry, value)
  local kind = entry.kind
  local listOf, mapOf = kind:match("^list:(%a+)$"), kind:match("^map:(%a+)$")
  if listOf then
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
      count = count + 1
      if type(key) ~= "number" then return false end
    end
    for i = 1, count do
      if not ScalarOK(listOf, value[i]) then return false end
    end
    return true
  elseif mapOf then
    if type(value) ~= "table" then return false end
    for key, inner in pairs(value) do
      if type(key) ~= "string" or #key > MAX_STRING or not ScalarOK(mapOf, inner) then return false end
      if entry.check and not entry.check(inner) then return false end
    end
    return true
  end
  if not ScalarOK(kind, value) then return false end
  return not entry.check or entry.check(value)
end

-- Allow-listed settings of one saved table, flat: { ["audio.enabled"] = true, ... }
local function Collect(root, list)
  local out = {}
  for _, entry in ipairs(list) do
    local value = Get(root, entry[1])
    if value ~= nil then out[entry[1]] = Copy(value) end
  end
  return out
end

---------------------------------------------------------------------------
-- Serializer: T, F, n<number>;, s<length>:<bytes>, {<key><value>...}
---------------------------------------------------------------------------

local function SortKeys(tbl)
  local keys = {}
  for key in pairs(tbl) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    if type(a) ~= type(b) then return type(a) == "number" end
    return a < b
  end)
  return keys
end

local function Write(value, out, depth)
  local kind = type(value)
  if kind == "boolean" then
    out[#out + 1] = value and "T" or "F"
  elseif kind == "number" then
    if not Finite(value) then error("number", 0) end
    out[#out + 1] = "n" .. string.format("%.17g", value) .. ";"
  elseif kind == "string" then
    out[#out + 1] = "s" .. #value .. ":" .. value
  elseif kind == "table" then
    if depth >= MAX_DEPTH then error("depth", 0) end
    out[#out + 1] = "{"
    for _, key in ipairs(SortKeys(value)) do
      Write(key, out, depth + 1)
      Write(value[key], out, depth + 1)
    end
    out[#out + 1] = "}"
  else
    error(kind, 0)
  end
end

function Profiles.Serialize(value)
  local out = {}
  Write(value, out, 0)
  return table.concat(out)
end

local function Read(text, pos, depth)
  local tag = text:sub(pos, pos)
  if tag == "T" then return true, pos + 1 end
  if tag == "F" then return false, pos + 1 end
  if tag == "n" then
    local digits, after = text:match("^([%d%.eE+-]+);()", pos + 1)
    local value = tonumber(digits or "")
    if not value or not Finite(value) then error("bad number", 0) end
    return value, after
  end
  if tag == "s" then
    local length, start = text:match("^(%d+):()", pos + 1)
    length = tonumber(length or "")
    if not length or length > MAX_STRING then error("bad string", 0) end
    local value = text:sub(start, start + length - 1)
    if #value ~= length then error("short string", 0) end
    return value, start + length
  end
  if tag == "{" then
    if depth >= MAX_DEPTH then error("too deep", 0) end
    local tbl, count = {}, 0
    pos = pos + 1
    while text:sub(pos, pos) ~= "}" do
      local key, value
      key, pos = Read(text, pos, depth + 1)
      if type(key) ~= "string" and type(key) ~= "number" then error("bad key", 0) end
      value, pos = Read(text, pos, depth + 1)
      count = count + 1
      if count > MAX_ENTRIES then error("too many entries", 0) end
      tbl[key] = value
    end
    return tbl, pos + 1
  end
  error("unexpected data", 0)
end

-- Returns the value, or nil and an error message.
function Profiles.Parse(text)
  if type(text) ~= "string" then return nil, "not text" end
  local ok, value, pos = pcall(Read, text, 1, 0)
  if not ok then return nil, value end
  if pos ~= #text + 1 then return nil, "trailing data" end
  return value
end

---------------------------------------------------------------------------
-- Base64, so the string survives an edit box and chat.
---------------------------------------------------------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for i = 1, #ALPHABET do DECODE[ALPHABET:sub(i, i)] = i - 1 end

local function Char(n) return ALPHABET:sub(n + 1, n + 1) end

function Profiles.Encode(data)
  local out = {}
  for i = 1, #data, 3 do
    local a, b, c = data:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    out[#out + 1] = Char(math.floor(n / 262144))
      .. Char(math.floor(n / 4096) % 64)
      .. (b and Char(math.floor(n / 64) % 64) or "=")
      .. (c and Char(n % 64) or "=")
  end
  return table.concat(out)
end

function Profiles.Decode(text)
  text = text:gsub("%s", "")
  if #text % 4 ~= 0 or not text:match("^[A-Za-z0-9+/]*=?=?$") then return nil end
  local out = {}
  for i = 1, #text, 4 do
    local chunk = text:sub(i, i + 3)
    local pad = #chunk:match("=*$")
    if pad > 0 and i + 3 < #text then return nil end
    local n = 0
    for j = 1, 4 do n = n * 64 + (DECODE[chunk:sub(j, j)] or 0) end
    local bytes = string.char(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256)
    out[#out + 1] = bytes:sub(1, 3 - pad)
  end
  return table.concat(out)
end

---------------------------------------------------------------------------
-- Export and import
---------------------------------------------------------------------------

function Profiles:Export()
  local payload = {
    account = Collect(ns.db, self.account),
    char = Collect(ns.chardb, self.char),
  }
  return PREFIX .. self.Encode(self.Serialize(payload))
end

-- Returns the number applied and the number skipped, or nil and an error.
function Profiles:Import(text)
  if InCombatLockdown() then return nil, L["Settings can't be imported in combat."] end
  text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
  if text == "" then return nil, L["Paste a settings string first."] end
  if #text > MAX_INPUT or text:sub(1, #PREFIX) ~= PREFIX then
    return nil, L["That isn't an Angler's TackleBox settings string."]
  end
  local decoded = self.Decode(text:sub(#PREFIX + 1))
  local payload = decoded and self.Parse(decoded)
  if type(payload) ~= "table" then
    return nil, L["That settings string is damaged. Copy it again, all of it."]
  end

  local staged, skipped = {}, 0
  for section, spec in pairs({ account = { ns.db, self.account, ns.defaults },
    char = { ns.chardb, self.char, ns.charDefaults } }) do
    local values = payload[section]
    if values ~= nil then
      local index = Index(spec[2], spec[3])
      if type(values) ~= "table" then
        skipped = skipped + 1
      else
        for path, value in pairs(values) do
          local entry = type(path) == "string" and index[path]
          if entry and Valid(entry, value) then
            staged[#staged + 1] = { spec[1], path, value }
          else
            skipped = skipped + 1
          end
        end
      end
    end
  end
  if #staged == 0 then return nil, L["No usable settings in that string."] end

  local db = ns.db
  local before = { key = db.key, alwaysOn = db.alwaysOn }
  for _, change in ipairs(staged) do Set(change[1], change[2], change[3]) end

  if db.key ~= before.key then ns.Engine:KeyChanged() end
  if db.alwaysOn ~= before.alwaysOn then ns.Core:SetAlwaysOn(db.alwaysOn) end
  ns.Engine:UpdateDoubleClick()
  ns.Core:UpdateAutoPole()
  ns.Broker:UpdateButton()
  ns.Spots:RefreshPins()
  ns.HUD:UpdateVisibility()
  if db.shareCharSettings then self:SaveShared() end
  ns.Menu:Refresh()
  return #staged, skipped
end

function Profiles:ImportAndReport(text)
  local applied, skipped = self:Import(text)
  if not applied then
    ns:Print(skipped)
    return
  end
  ns:Print(string.format(L["Imported %d settings."], applied))
  if skipped > 0 then
    ns:Print(string.format(L["%d entries weren't recognised and were left out."], skipped))
  end
end

local function EditBox(dialog) return dialog.editBox or dialog.EditBox end

function Profiles:ShowExport()
  self.exported = self:Export()
  if not StaticPopupDialogs["ANGLERS_TACKLEBOX_EXPORT_SETTINGS"] then
    StaticPopupDialogs["ANGLERS_TACKLEBOX_EXPORT_SETTINGS"] = {
      text = L["Your settings as text. Copy it (Ctrl-C) and paste it into Import settings on any character:"],
      button1 = CLOSE,
      hasEditBox = true,
      editBoxWidth = 320,
      maxLetters = 0,
      OnShow = function(dialog)
        local box = EditBox(dialog)
        box:SetMaxLetters(0)
        box:SetText(Profiles.exported)
        box:HighlightText()
        box:SetFocus()
      end,
      EditBoxOnTextChanged = function(box)
        if box:GetText() ~= Profiles.exported then
          box:SetText(Profiles.exported)
          box:HighlightText()
        end
      end,
      EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
      EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
      timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
  end
  StaticPopup_Show("ANGLERS_TACKLEBOX_EXPORT_SETTINGS")
end

function Profiles:ShowImport()
  if not StaticPopupDialogs["ANGLERS_TACKLEBOX_IMPORT_SETTINGS"] then
    StaticPopupDialogs["ANGLERS_TACKLEBOX_IMPORT_SETTINGS"] = {
      text = L["Paste a settings string (Ctrl-V). Only settings are changed; your catch log and other records are kept."],
      button1 = L["Import"],
      button2 = CANCEL,
      hasEditBox = true,
      editBoxWidth = 320,
      maxLetters = 0,
      OnShow = function(dialog)
        local box = EditBox(dialog)
        box:SetMaxLetters(0)
        box:SetText("")
        box:SetFocus()
      end,
      OnAccept = function(dialog) Profiles:ImportAndReport(EditBox(dialog):GetText()) end,
      EditBoxOnEnterPressed = function(box)
        Profiles:ImportAndReport(box:GetText())
        box:GetParent():Hide()
      end,
      EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
      timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
  end
  StaticPopup_Show("ANGLERS_TACKLEBOX_IMPORT_SETTINGS")
end

---------------------------------------------------------------------------
-- Shared character settings still live in ns.chardb: the shared copy is written
-- into chardb at login and copied back at logout, so no other module changes.
---------------------------------------------------------------------------

local logout = CreateFrame("Frame")
logout:SetScript("OnEvent", function()
  if ns.db.shareCharSettings then Profiles:SaveShared() end
end)

function Profiles:UpdateLogout()
  if ns.db.shareCharSettings then
    logout:RegisterEvent("PLAYER_LOGOUT")
  else
    logout:UnregisterEvent("PLAYER_LOGOUT")
  end
end

function Profiles:SaveShared()
  local shared = {}
  for _, entry in ipairs(self.char) do
    shared[entry[1]] = Copy(Get(ns.chardb, entry[1]))
  end
  ns.db.sharedChar = shared
end

-- Every listed setting is copied, nil included: the shared copy wins.
function Profiles:LoadShared()
  local shared = ns.db.sharedChar
  if type(shared) ~= "table" or next(shared) == nil then return end
  local index = Index(self.char, ns.charDefaults)
  for _, entry in ipairs(self.char) do
    local path = entry[1]
    local value = shared[path]
    if value == nil then
      if index[path].kind:find(":") then value = {} end
      Set(ns.chardb, path, value)
    elseif Valid(index[path], value) then
      Set(ns.chardb, path, value)
    end
  end
end

function Profiles:SetShared(on)
  ns.db.shareCharSettings = on and true or false
  if on then
    self:SaveShared()
    ns:Print(L["This character's gear and lure settings now apply to all your characters."])
  else
    ns:Print(L["Each character keeps its own gear and lure settings again."])
  end
  self:UpdateLogout()
end

function Profiles:Init()
  if ns.db.shareCharSettings then self:LoadShared() end
  self:UpdateLogout()
end
