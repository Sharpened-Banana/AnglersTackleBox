-- Pool route memory: remembers where you have fished and pins those spots
-- on the world map, so a few sessions build your own route for each zone.
-- Each spot keeps its catches and the time spent there, which is what the
-- gold rankings work from.
local _, ns = ...
local L, Compat = ns.L, ns.Compat

local Spots = ns:NewModule("Spots")

local MERGE = 0.012      -- catches this close together (map units) are one spot
local MAX_GAP = 90       -- longest pause that still counts as fishing the spot
local MAX_PINS = 200

local function PlayerPosition()
  if not C_Map or not C_Map.GetPlayerMapPosition then return nil end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local position = C_Map.GetPlayerMapPosition(mapID, "player")
  if not position then return nil end
  local x, y = position:GetXY()
  if not x or (x == 0 and y == 0) then return nil end
  return mapID, x, y
end

local function SpotAt(mapID, x, y)
  local list = ns.chardb.spots[mapID]
  if not list then list = {} ns.chardb.spots[mapID] = list end
  for _, spot in ipairs(list) do
    local dx, dy = spot.x - x, spot.y - y
    if dx * dx + dy * dy <= MERGE * MERGE then return spot end
  end
  local spot = { x = x, y = y, n = 0, seconds = 0, items = {} }
  table.insert(list, spot)
  return spot
end

ns:On("CAST_LOOTED", function(looted, pool)
  local mapID, x, y = PlayerPosition()
  if not mapID then return end
  local spot = SpotAt(mapID, x, y)
  for itemID, quantity in pairs(looted) do
    spot.items[itemID] = (spot.items[itemID] or 0) + quantity
    spot.n = spot.n + quantity
  end
  if pool then spot.pool = pool end
  spot.last = time()

  -- Time at the spot: the gap since the previous catch here, if it was recent.
  local now = GetTime()
  if Spots.lastSpot == spot and Spots.lastAt then
    spot.seconds = spot.seconds + math.min(MAX_GAP, now - Spots.lastAt)
  end
  Spots.lastSpot, Spots.lastAt = spot, now
  Spots:RefreshPins()
end)

-- Current value of everything caught at a spot, and its hourly rate once
-- there are a few minutes of data behind it.
function Spots.Value(spot)
  local value = 0
  for itemID, quantity in pairs(spot.items) do
    value = value + ns.Log.UnitValue(itemID) * quantity
  end
  local perHour = spot.seconds >= 180 and (value / spot.seconds * 3600) or nil
  return value, perHour
end

function Spots.Name(spot)
  return spot.pool or L["Open water"]
end

---------------------------------------------------------------------------
-- World map pins: plain buttons on the map canvas, drawn only while the
-- map is open.
---------------------------------------------------------------------------

local overlay, pins = nil, {}

local function Canvas()
  local container = WorldMapFrame and WorldMapFrame.ScrollContainer
  return container and container.Child
end

local function PinTooltip(pin)
  local spot = pin.spot
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  GameTooltip:SetText(Spots.Name(spot))
  GameTooltip:AddLine(string.format(L["%d fish caught here"], spot.n), 1, 1, 1)
  local value, perHour = Spots.Value(spot)
  if perHour then
    GameTooltip:AddLine(string.format(L["%s per hour"], Compat.CoinString(perHour)), 1, 1, 1)
  elseif value > 0 then
    GameTooltip:AddLine(string.format(L["Worth %s so far"], Compat.CoinString(value)), 1, 1, 1)
  end
  local rows = {}
  for itemID, quantity in pairs(spot.items) do rows[#rows + 1] = { id = itemID, n = quantity } end
  table.sort(rows, function(a, b) return a.n > b.n end)
  for index = 1, math.min(4, #rows) do
    local name = Compat.GetItemInfo(rows[index].id) or ("item:" .. rows[index].id)
    GameTooltip:AddLine(string.format("%s x%d", name, rows[index].n), 0.7, 0.7, 0.7)
  end
  GameTooltip:Show()
end

function Spots:RefreshPins()
  local canvas = Canvas()
  if not canvas or not WorldMapFrame:IsShown() then return end
  if not overlay then
    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 2000)
  end
  for _, pin in ipairs(pins) do pin:Hide() end
  if not ns.db or not ns.db.mapPins then return end

  local list = ns.chardb.spots[WorldMapFrame:GetMapID() or 0]
  if not list then return end
  local width, height = canvas:GetWidth(), canvas:GetHeight()
  local size = math.max(10, width * 0.016)
  for index = 1, math.min(MAX_PINS, #list) do
    local spot = list[index]
    local pin = pins[index]
    if not pin then
      pin = CreateFrame("Button", nil, overlay)
      pin.icon = pin:CreateTexture(nil, "ARTWORK")
      pin.icon:SetAllPoints()
      pin.icon:SetTexture("Interface\\Icons\\Trade_Fishing")
      pin:SetScript("OnEnter", PinTooltip)
      pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
      pins[index] = pin
    end
    pin.spot = spot
    pin:SetSize(size, size)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", overlay, "TOPLEFT", spot.x * width, -spot.y * height)
    -- Pools stand out; open-water spots sit back.
    pin:SetAlpha(spot.pool and 1 or 0.6)
    pin:Show()
  end
end

function Spots:Init()
  if not WorldMapFrame then return end
  WorldMapFrame:HookScript("OnShow", function() Spots:RefreshPins() end)
  if WorldMapFrame.OnMapChanged then
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Spots:RefreshPins() end)
  end
end

function Spots:ClearMap(mapID)
  ns.chardb.spots[mapID] = nil
  self:RefreshPins()
end
