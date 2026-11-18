-- WoW Forever only: /tb probe records what this client's fishing really does (which APIs exist,
-- what the game says when a fish gets away, what a pool's tooltip looks like), so features are
-- built on what was seen and not on what the original game did. It reads and writes nothing but
-- its own saved table, and is silent until the command is used.
local _, ns = ...

local Probe = ns:NewModule("Probe")

local MAX_EVENTS = 300
local FISHING_SKILL_LINE = 356

local function Store()
  ns.chardb.probe = ns.chardb.probe or { api = {}, events = {} }
  return ns.chardb.probe
end

-- The game hides some values from addons ("secret"): even comparing one is an error.
local IsSecret = ns.Compat.IsSecret

local function Text(value, depth)
  if IsSecret(value) then return "<secret>" end
  if type(value) ~= "table" then return tostring(value) end
  if (depth or 0) > 1 then return "{...}" end
  local parts = {}
  for k, v in pairs(value) do
    parts[#parts + 1] = tostring(k) .. "=" .. Text(v, (depth or 0) + 1)
    if #parts >= 24 then parts[#parts + 1] = "..." break end
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- Every return of a call, or why it could not be made.
local function Returns(fn, ...)
  if type(fn) ~= "function" then return "missing" end
  local function Pack(ok, ...)
    if not ok then return "error: " .. tostring((...)) end
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = Text((select(i, ...))) end
    return #parts > 0 and table.concat(parts, " | ") or "(nothing)"
  end
  return Pack(pcall(fn, ...))
end

local function Keys(tbl)
  if type(tbl) ~= "table" then return "missing" end
  local names = {}
  for k in pairs(tbl) do names[#names + 1] = tostring(k) end
  table.sort(names)
  return table.concat(names, " ")
end

local function Field(tbl, key) return type(tbl) == "table" and tbl[key] or nil end

local function Note(kind, text)
  local probe = ns.chardb.probe
  if not probe or not probe.on then return end
  local events = probe.events
  if #events >= MAX_EVENTS then return end
  events[#events + 1] = { t = time(), k = kind, v = tostring(text) }
end

-- The fishing skill line by every route a client might offer.
local function SkillReport(api)
  api.GetProfessions = Returns(GetProfessions)
  local fishing = GetProfessions and select(4, GetProfessions())
  api.GetProfessionInfo = fishing and Returns(GetProfessionInfo, fishing) or "no fishing index"
  api.GetNumSkillLines = Returns(GetNumSkillLines)
  if GetNumSkillLines and GetSkillLineInfo then
    local name = ns.Compat.FishingName()
    for i = 1, GetNumSkillLines() do
      if GetSkillLineInfo(i) == name then api.GetSkillLineInfo = Returns(GetSkillLineInfo, i) end
    end
  end
  api.C_SkillInfo = Keys(C_SkillInfo)
  api["C_SkillInfo.GetSkillLineInfoByID"] = Returns(Field(C_SkillInfo, "GetSkillLineInfoByID"), FISHING_SKILL_LINE)
  api["C_SkillInfo.GetNumSkillLines"] = Returns(Field(C_SkillInfo, "GetNumSkillLines"))
end

local STRINGS = {
  "ERR_FISH_ESCAPED", "ERR_FISH_NOT_HOOKED", "ERR_SKILL_UP_SI", "ITEM_MIN_SKILL", "SPELL_FAILED_FISHING_TOO_LOW",
  "SPELL_FAILED_NOT_FISHABLE", "SPELL_FAILED_NO_FISH", "ERR_USE_LOCKED_WITH_SPELL_KNOWN_SI", "SKILL_RANK_UP",
}

function Probe:Snapshot()
  local probe = Store()
  local api = {}
  probe.api = api
  api.build = Returns(GetBuildInfo)
  api.project = Text(WOW_PROJECT_ID) .. " camelot=" .. Text(WOW_PROJECT_CAMELOT)
    .. " classic=" .. Text(WOW_PROJECT_CLASSIC) .. " mainline=" .. Text(WOW_PROJECT_MAINLINE)
  SkillReport(api)

  api.GetWeaponEnchantInfo = Returns(GetWeaponEnchantInfo)
  api["C_PaperDollInfo.GetTemporaryEnchantmentInfo"] =
    Returns(Field(C_PaperDollInfo, "GetTemporaryEnchantmentInfo"), ns.Compat.MAINHAND)
  local mainhand = GetInventoryItemLink("player", ns.Compat.MAINHAND)
  api.mainhand = Text(mainhand and mainhand:gsub("|", "||"))
  api.GetItemStats = mainhand and Returns(GetItemStats, mainhand) or "nothing in hand"

  api.C_Container = Keys(C_Container)
  api["C_Container.GetContainerNumFreeSlots"] = Returns(Field(C_Container, "GetContainerNumFreeSlots"), 0)
  api.GetContainerNumFreeSlots = Returns(GetContainerNumFreeSlots, 0)

  api.TooltipDataProcessor = type(TooltipDataProcessor)
  api.C_TooltipInfo = type(C_TooltipInfo)
  api["GameTooltip.HookScript"] = type(Field(GameTooltip, "HookScript"))
  api.C_QuestLog = Keys(C_QuestLog)
  api.C_Calendar = type(C_Calendar)
  api.GetGameTime = Returns(GetGameTime)
  api["C_DateAndTime.GetCurrentCalendarTime"] = Returns(Field(C_DateAndTime, "GetCurrentCalendarTime"))
  api.map = Text(C_Map.GetBestMapForUnit("player")) .. " " .. Text(GetZoneText()) .. " / " .. Text(GetSubZoneText())

  for _, name in ipairs(STRINGS) do api[name] = Text(_G[name]) end
  -- Any other global string about fishing, whatever this client calls it.
  local found = 0
  pcall(function()
    for key, value in pairs(_G) do
      if found < 40 and type(key) == "string" and type(value) == "string" and not api[key]
        and (key:find("FISH", 1, true) or value:find("got away", 1, true)) then
        api[key] = value
        found = found + 1
      end
    end
  end)
  return api
end

-- A world object's tooltip (a pool, say) is neither a unit's nor an item's.
local lastTip
local function ReadTooltip(how)
  local probe = ns.chardb.probe
  if not probe or not probe.on or type(GameTooltip) ~= "table" then return end
  local ok, text = pcall(function()
    if GameTooltip.IsShown and not GameTooltip:IsShown() then return nil end
    if GameTooltip.GetUnit and GameTooltip:GetUnit() then return nil end
    if GameTooltip.GetItem and GameTooltip:GetItem() then return nil end
    local line = _G.GameTooltipTextLeft1
    local shown = line and line.GetText and line:GetText()
    if IsSecret(shown) then return nil end
    return shown
  end)
  if not ok or not text or text == "" then
    if how == "tick" then lastTip = nil end
    return
  end
  if text == lastTip then return end
  lastTip = text
  local owner = GameTooltip.GetOwner and GameTooltip:GetOwner()
  Note("tooltip:" .. how, text .. " (owner " .. Text(owner and owner.GetName and owner:GetName()) .. ")")
end

local hooked
local function HookTooltip()
  if hooked then return end
  hooked = true
  pcall(function() GameTooltip:HookScript("OnShow", function() ns.Safe(ReadTooltip, "show") end) end)
end

local function State()
  return ("map %s %s / %s | skill %s | enchant %s"):format(
    Text(C_Map.GetBestMapForUnit("player")), Text(GetZoneText()), Text(GetSubZoneText()),
    Returns(Field(C_SkillInfo, "GetSkillLineInfoByID"), FISHING_SKILL_LINE), Returns(GetWeaponEnchantInfo))
end

function Probe:Run(rest)
  local probe = Store()
  if rest == "off" then
    probe.on = false
    ns:Print(ns.L["Probe stopped. What it saw is kept until /tb probe clear."])
    return
  elseif rest == "clear" then
    ns.chardb.probe = nil
    ns:Print(ns.L["Probe data cleared."])
    return
  end
  local api = self:Snapshot()
  probe.on = true
  HookTooltip()
  Note("state", State())
  ns:Print(ns.L["Probe on. Fish as usual, hover a pool for a second or two, apply a lure, then /reload."])
  print("   skill: " .. tostring(api["C_SkillInfo.GetSkillLineInfoByID"]))
  print("   professions: " .. tostring(api.GetProfessionInfo))
  print("   lure: " .. tostring(api.GetWeaponEnchantInfo))
  print("   got away text: " .. tostring(api.ERR_FISH_ESCAPED))
  print(("   %d of %d notes used; /tb probe off stops, /tb probe clear forgets."):format(#probe.events, MAX_EVENTS))
end

function Probe:Init()
  if ns.chardb.probe and ns.chardb.probe.on then HookTooltip() end
end

function Probe:Tick()
  if ns.chardb.probe and ns.chardb.probe.on then ReadTooltip("tick") end
end

ns:On("CAST_START", function() Note("cast", State()) end)
ns:On("CAST_END", function() Note("cast end", "") end)
ns:On("CAST_LOOTED", function(looted, pool)
  Note("looted", Text(looted) .. " pool " .. tostring(pool))
end)

for _, event in ipairs({ "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "CHAT_MSG_SKILL", "CHAT_MSG_SYSTEM" }) do
  ns:OnModeEvent(event, function(...)
    local parts = {}
    for i = 1, math.min(select("#", ...), 3) do parts[i] = Text((select(i, ...))) end
    Note(event, table.concat(parts, " | "))
  end)
end
