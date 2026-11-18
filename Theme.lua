-- Colour themes. Every window takes its colours from Theme.C, whose tables are changed in place
-- when the theme changes, and paints through Theme:Paint, which remembers what it painted so a new
-- theme or opacity shows at once, with no /reload.
local _, ns = ...
local L = ns.L

local Theme = ns:NewModule("Theme")

-- shell/lid/seam: the box; tray/trayLifted/ridge/ink: the tab strip and its lettering;
-- brass: fittings and highlights; steel: the handle; well: behind the contents; title: lid lettering;
-- hud: the Fishing Companion's background; label: its row names; header: report headings;
-- chat: the addon's name in chat (a hex string).
Theme.list = {
  {
    key = "tacklebox", name = L["Tackle Box"],
    shell = { 0.11, 0.22, 0.16 }, lid = { 0.16, 0.33, 0.23 }, seam = { 0.03, 0.07, 0.05 },
    tray = { 0.78, 0.72, 0.56 }, trayLifted = { 0.93, 0.88, 0.72 }, ridge = { 0.52, 0.47, 0.34 },
    ink = { 0.22, 0.16, 0.08 }, brass = { 0.85, 0.66, 0.22 }, steel = { 0.35, 0.36, 0.38 },
    well = { 0.04, 0.08, 0.06 }, title = { 0.93, 0.88, 0.72 }, hud = { 0, 0, 0 },
    label = { 1, 0.82, 0 }, header = { 1, 0.82, 0 }, chat = "4fc3f7",
  },
  {
    key = "deepsea", name = L["Deep Sea"],
    shell = { 0.06, 0.13, 0.24 }, lid = { 0.09, 0.20, 0.36 }, seam = { 0.02, 0.04, 0.09 },
    tray = { 0.55, 0.72, 0.78 }, trayLifted = { 0.75, 0.90, 0.94 }, ridge = { 0.33, 0.48, 0.55 },
    ink = { 0.05, 0.14, 0.22 }, brass = { 0.25, 0.80, 0.75 }, steel = { 0.32, 0.38, 0.45 },
    well = { 0.02, 0.05, 0.10 }, title = { 0.75, 0.90, 0.94 }, hud = { 0.02, 0.06, 0.12 },
    label = { 0.45, 0.88, 0.84 }, header = { 0.45, 0.88, 0.84 }, chat = "40ccbf",
  },
  {
    key = "parchment", name = L["Parchment"],
    shell = { 0.62, 0.52, 0.36 }, lid = { 0.72, 0.62, 0.44 }, seam = { 0.25, 0.18, 0.10 },
    tray = { 0.90, 0.84, 0.68 }, trayLifted = { 0.98, 0.94, 0.82 }, ridge = { 0.60, 0.52, 0.36 },
    ink = { 0.25, 0.16, 0.07 }, brass = { 0.80, 0.45, 0.20 }, steel = { 0.42, 0.38, 0.32 },
    well = { 0.16, 0.11, 0.07 }, title = { 0.20, 0.12, 0.05 }, hud = { 0.14, 0.10, 0.06 },
    label = { 0.95, 0.80, 0.50 }, header = { 0.95, 0.80, 0.50 }, chat = "e6b873",
  },
  {
    key = "midnight", name = L["Midnight"],
    shell = { 0.07, 0.06, 0.12 }, lid = { 0.12, 0.10, 0.20 }, seam = { 0.02, 0.02, 0.04 },
    tray = { 0.60, 0.56, 0.74 }, trayLifted = { 0.82, 0.78, 0.95 }, ridge = { 0.40, 0.36, 0.54 },
    ink = { 0.10, 0.07, 0.20 }, brass = { 0.66, 0.45, 0.95 }, steel = { 0.34, 0.33, 0.42 },
    well = { 0.03, 0.03, 0.06 }, title = { 0.82, 0.78, 0.95 }, hud = { 0.03, 0.02, 0.07 },
    label = { 0.78, 0.65, 1 }, header = { 0.78, 0.65, 1 }, chat = "b48cff",
  },
  {
    key = "contrast", name = L["High Contrast"],
    shell = { 0, 0, 0 }, lid = { 0.10, 0.10, 0.10 }, seam = { 1, 1, 1 },
    tray = { 1, 1, 1 }, trayLifted = { 1, 1, 0.60 }, ridge = { 0.60, 0.60, 0.60 },
    ink = { 0, 0, 0 }, brass = { 1, 0.90, 0 }, steel = { 0.70, 0.70, 0.70 },
    well = { 0, 0, 0 }, title = { 1, 1, 1 }, hud = { 0, 0, 0 },
    label = { 1, 1, 0 }, header = { 1, 1, 0 }, chat = "ffff00",
  },
  {
    key = "forever", name = L["Forever Stone"],
    shell = { 0.20, 0.19, 0.18 }, lid = { 0.28, 0.26, 0.24 }, seam = { 0.06, 0.05, 0.05 },
    tray = { 0.62, 0.58, 0.50 }, trayLifted = { 0.80, 0.76, 0.66 }, ridge = { 0.42, 0.39, 0.33 },
    ink = { 0.12, 0.10, 0.07 }, brass = { 1, 0.82, 0 }, steel = { 0.40, 0.40, 0.42 },
    well = { 0.06, 0.05, 0.05 }, title = { 1, 0.82, 0 }, hud = { 0.05, 0.04, 0.04 },
    label = { 1, 0.82, 0 }, header = { 1, 0.82, 0 }, chat = "ffd100",
  },
  {
    key = "retail", name = L["Modern Slate"],
    shell = { 0.10, 0.11, 0.14 }, lid = { 0.15, 0.17, 0.22 }, seam = { 0.03, 0.03, 0.04 },
    tray = { 0.62, 0.66, 0.74 }, trayLifted = { 0.84, 0.88, 0.95 }, ridge = { 0.42, 0.46, 0.54 },
    ink = { 0.08, 0.10, 0.15 }, brass = { 0.25, 0.60, 1 }, steel = { 0.36, 0.38, 0.44 },
    well = { 0.04, 0.04, 0.06 }, title = { 0.84, 0.88, 0.95 }, hud = { 0.03, 0.04, 0.06 },
    label = { 0.55, 0.78, 1 }, header = { 0.55, 0.78, 1 }, chat = "8cc7ff",
  },
}

Theme.MIN_OPACITY = 0.3

local byKey = {}
for _, theme in ipairs(Theme.list) do byKey[theme.key] = theme end

-- The live palette: the default theme's colours until the saved one is loaded.
local C = {}
Theme.C = C
for name, value in pairs(Theme.list[1]) do
  if type(value) == "table" then C[name] = { value[1], value[2], value[3] } end
end
C.chat = Theme.list[1].chat

function Theme:Valid(key) return byKey[key] ~= nil end

function Theme:Current()
  return byKey[ns.db and ns.db.theme] or Theme.list[1]
end

function Theme:Choices()
  local choices = {}
  for index, theme in ipairs(Theme.list) do choices[index] = { key = theme.key, label = theme.name } end
  return choices
end

-- How see-through the windows' backgrounds are; lettering stays solid.
function Theme:Opacity()
  local value = tonumber(ns.db and ns.db.windowOpacity) or 1
  return math.max(Theme.MIN_OPACITY, math.min(1, value))
end

function Theme:Hex(name)
  if name == "chat" then return C.chat end
  local color = C[name] or C.brass
  local function Byte(value) return math.floor(value * 255 + 0.5) end
  return string.format("%02x%02x%02x", Byte(color[1]), Byte(color[2]), Byte(color[3]))
end

-- Paints are kept by the thing painted, so a frame that goes away takes its entries with it.
local paints = setmetatable({}, { __mode = "k" })

local function Draw(target, paint)
  local color, alpha = paint.color, paint.alpha
  if paint.window then alpha = alpha * Theme:Opacity() end
  target[paint.method](target, color[1], color[2], color[3], alpha)
end

-- Colour 'target' by calling target[method](r, g, b, a) now and again whenever the theme changes.
-- 'window' marks a background, which the window-opacity setting fades.
function Theme:Paint(target, method, color, alpha, window)
  local paint = { method = method, color = color, alpha = alpha or 1, window = window }
  paints[target] = paints[target] or {}
  paints[target][method] = paint
  Draw(target, paint)
  return target
end

function Theme:Repaint()
  for target, byMethod in pairs(paints) do
    for _, paint in pairs(byMethod) do Draw(target, paint) end
  end
  if ns.HUD then ns.HUD:UpdateVisibility() end
  if ns.Menu and ns.Menu.Refresh then ns.Menu:Refresh() end
end

-- Copy the chosen theme into the live palette, in place, and repaint.
function Theme:Apply()
  local theme = self:Current()
  for name, value in pairs(theme) do
    if type(value) == "table" and C[name] then
      C[name][1], C[name][2], C[name][3] = value[1], value[2], value[3]
    end
  end
  C.chat = theme.chat
  self:Repaint()
end

function Theme:Init() self:Apply() end

function Theme:Set(key)
  if not byKey[key] then return false end
  ns.db.theme = key
  self:Apply()
  return true
end

function Theme:SetOpacity(value)
  ns.db.windowOpacity = math.max(Theme.MIN_OPACITY, math.min(1, tonumber(value) or 1))
  self:Repaint()
end
