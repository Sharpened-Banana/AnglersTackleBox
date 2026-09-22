-- Graph: a small chart drawn with plain textures, for the Statistics and
-- Gold compartments. Bars, or a line through the points where the client
-- can draw lines (Texture lines via CreateLine); without them a line graph
-- falls back to bars. An optional flat reference line (an average, say)
-- runs across the whole width. No libraries.
local _, ns = ...

local Graph = {}
ns.Graph = Graph

local SOLID = "Interface\\Buttons\\WHITE8x8"
local DOT = 4

local function Solid(frame, layer, color, alpha)
  local texture = frame:CreateTexture(nil, layer)
  texture:SetTexture(SOLID)
  texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
  return texture
end

-- A line object, or nil where the client cannot draw one.
local function NewLine(frame, color)
  if not frame.CreateLine then return nil end
  local ok, line = pcall(frame.CreateLine, frame, nil, "ARTWORK")
  if not ok or not line or not line.SetStartPoint then return nil end
  line:SetThickness(2)
  line:SetColorTexture(color[1], color[2], color[3], 1)
  return line
end

-- The largest value, or 0.
function Graph.Peak(values)
  local peak = 0
  for _, value in ipairs(values) do
    if value > peak then peak = value end
  end
  return peak
end

local Methods = {}

local function Pooled(pool, index, make)
  local item = pool[index]
  if not item then
    item = make()
    pool[index] = item
  end
  return item
end

-- Draws `values` (numbers, left to right). opts:
--   mode = "bars" (default) or "line"
--   floor = the value at the bottom edge (default 0; a price graph uses
--           a little under its lowest point so the movement shows)
--   reference = a value to mark with a flat line across the graph
--   tooltip = function(index, value) returning lines for GameTooltip
--   empty = text shown in the middle when there is nothing to draw
function Methods:SetValues(values, opts)
  opts = opts or {}
  local hasData = false
  for _, value in ipairs(values) do
    if value > (opts.floor or 0) then hasData = true break end
  end
  self.empty:SetText(opts.empty or "")
  self.empty:SetShown(not hasData and opts.empty ~= nil)
  self.values, self.tooltip = values, opts.tooltip
  local count, width, height = #values, self.width, self.height
  local floor = opts.floor or 0
  local top = math.max(Graph.Peak(values), opts.reference or 0)
  local span = top - floor
  local slot = count > 0 and width / count or width
  local function Y(value)
    if span <= 0 then return value > floor and height - 1 or 1 end
    return math.max(1, math.min(height - 1, (value - floor) / span * (height - 2) + 1))
  end

  -- Lines where the client has them; otherwise the line graph is bars.
  if self.canLine == nil then
    local probe = NewLine(self.frame, self.color)
    self.canLine = probe ~= nil
    if probe then
      probe:Hide()
      self.lines[1] = probe
    end
  end
  local useLine = opts.mode == "line" and count > 1 and self.canLine
  local bars, lines, dots, hits = 0, 0, 0, 0
  for index, value in ipairs(values) do
    local x = (index - 1) * slot
    local y = Y(value)
    if useLine then
      dots = dots + 1
      local dot = Pooled(self.dots, dots, function() return Solid(self.frame, "OVERLAY", self.color) end)
      dot:SetSize(DOT, DOT)
      dot:ClearAllPoints()
      dot:SetPoint("CENTER", self.frame, "BOTTOMLEFT", x + slot / 2, y)
      dot:Show()
      if index > 1 then
        lines = lines + 1
        local line = Pooled(self.lines, lines, function() return NewLine(self.frame, self.color) end)
        line:SetStartPoint("BOTTOMLEFT", self.frame, x - slot / 2, Y(values[index - 1]))
        line:SetEndPoint("BOTTOMLEFT", self.frame, x + slot / 2, y)
        line:Show()
      end
    elseif value > floor then
      bars = bars + 1
      local bar = Pooled(self.bars, bars, function() return Solid(self.frame, "ARTWORK", self.color) end)
      bar:ClearAllPoints()
      bar:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x + 1, 0)
      bar:SetSize(math.max(1, slot - 2), y)
      bar:Show()
    end
    if self.tooltip then
      hits = hits + 1
      local hit = Pooled(self.hits, hits, function()
        local frame = CreateFrame("Frame", nil, self.frame)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(hover)
          local text = self.tooltip and self.tooltip(hover.index, self.values[hover.index])
          if not text or not text[1] then return end
          GameTooltip:SetOwner(hover, "ANCHOR_TOP")
          GameTooltip:SetText(text[1])
          for n = 2, #text do GameTooltip:AddLine(text[n], 1, 1, 1) end
          GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return frame
      end)
      hit.index = index
      hit:ClearAllPoints()
      hit:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, 0)
      hit:SetSize(math.max(1, slot), height)
      hit:Show()
    end
  end
  for index = bars + 1, #self.bars do self.bars[index]:Hide() end
  for index = lines + 1, #self.lines do self.lines[index]:Hide() end
  for index = dots + 1, #self.dots do self.dots[index]:Hide() end
  for index = hits + 1, #self.hits do self.hits[index]:Hide() end

  local reference = opts.reference
  self.reference:SetShown(reference ~= nil and reference > floor and count > 0)
  if reference and reference > floor then
    self.reference:ClearAllPoints()
    self.reference:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, Y(reference))
    self.reference:SetSize(width, 1)
  end
  return useLine
end

function Methods:Clear(text)
  return self:SetValues({}, { empty = text })
end

-- A graph of the given size inside `parent`; place it with graph.frame.
-- color is the bar and line colour, background an optional { r, g, b, a }.
function Graph.New(parent, width, height, color, background)
  local graph = setmetatable({
    width = width, height = height, color = color or { 0.85, 0.66, 0.22 },
    bars = {}, lines = {}, dots = {}, hits = {},
  }, { __index = Methods })
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  graph.frame = frame
  if background then
    Solid(frame, "BACKGROUND", background, background[4] or 0.2):SetAllPoints()
  end
  -- A baseline so an empty graph still reads as a graph.
  local base = Solid(frame, "BORDER", graph.color, 0.6)
  base:SetPoint("BOTTOMLEFT")
  base:SetPoint("BOTTOMRIGHT")
  base:SetHeight(1)
  graph.reference = Solid(frame, "OVERLAY", { 1, 1, 1 }, 0.35)
  graph.reference:Hide()
  graph.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  graph.empty:SetPoint("CENTER")
  graph.empty:Hide()
  return graph
end
