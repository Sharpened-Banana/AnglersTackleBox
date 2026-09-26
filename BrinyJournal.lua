-- Reads one Fishing Journal fish (Retail): its Anglin' Score, the zones and pools it lives in, and whether
-- open water or pools catch it better. The journal text is localized, so this carries each language's labels.
-- The label tables, text helpers and zone-name corrections are from BrinyBest,
-- Copyright (c) 2026 Andrew Edmond, MIT License: see Licenses/BrinyBest.txt.
local _, ns = ...
local Compat = ns.Compat
if not ns.Data.briny then return end

local Journal = {}
ns.BrinyJournal = Journal

-- Each language's labels, matched as plain text. Header fields may list alternatives, since Blizzard
-- words them differently between fish in some languages.
local LOCALE_PARSE = {
  enUS = {
    scoreLabel = "Anglin' Score",
    rankLabel = "Catch Rank",
    areasHeader = "Areas you can find",
    poolsHeader = "Fishing Pools",
    ratesHeader = "Rates",
    descriptionHeader = "Description",
    specialHeader = "Special",
    pointsWord = "points",
    rankWords = { Guppy = "Guppy", Minnow = "Minnow", Pike = "Pike", Shark = "Shark", Trophy = "Trophy" },
    openWaterWord = "open water",
    poolWord = "pool",
    onlyWord = "only",
  },
  deDE = {
    scoreLabel = "Angelwertung",
    rankLabel = "Fangrang",
    areasHeader = "Verbreitungsgebiete",
    poolsHeader = "Fischschwärme",
    ratesHeader = "Raten",
    descriptionHeader = "Beschreibung",
    specialHeader = "Besondere Verwendung",
    pointsWord = "Punkte",
    rankWords = { ["Guppy"] = "Guppy" },
    openWaterWord = "offenen gewässern",
    poolWord = "teich",
    onlyWord = "nur",
  },
  esES = {
    scoreLabel = "Puntuación de pesca",
    rankLabel = "Rango de la captura",
    areasHeader = "Zonas en las que puedes encontrar",
    poolsHeader = { "Zonas de pesca", "Zona de pesca" },
    ratesHeader = "Frecuencia",
    descriptionHeader = "Descripción",
    specialHeader = "Especial",
    pointsWord = "puntos",
    rankWords = { ["Lebiste"] = "Guppy" },
    openWaterWord = "mar abierto",
    poolWord = "estanque",
    onlyWord = "solo",
  },
  frFR = {
    scoreLabel = "Score de pêche",
    rankLabel = { "Rang de la prise", "Rang de capture" },
    areasHeader = "Poisson présent dans les régions",
    poolsHeader = "Bancs de poissons",
    ratesHeader = "Fréquence",
    descriptionHeader = "Description",
    specialHeader = "Utilisation spéciale",
    rankWords = { ["guppy"] = "Guppy", ["Guppy"] = "Guppy", ["trophée"] = "Trophy", ["Trophée"] = "Trophy" },
    openWaterWord = "étendues d’eau",
    poolWord = "bancs de poissons",
    onlyWord = "uniquement",
  },
  itIT = {
    scoreLabel = "Punteggio di Pesca",
    rankLabel = "Grado di Cattura",
    areasHeader = "Aree in cui si può trovare",
    poolsHeader = "Pozze di Pesca",
    ratesHeader = { "Probabilità", "Frequenza", "Rates" },
    descriptionHeader = "Descrizione",
    specialHeader = "Speciale",
    pointsWord = "punti",
    rankWords = { ["Bavosa"] = "Guppy" },
    openWaterWord = "mare aperto",
    poolWord = "pozze",
    onlyWord = "solo",
  },
  koKR = {
    scoreLabel = "강태공 점수",
    rankLabel = "어획 등급",
    areasHeader = "이 생선을 잡을 수 있는 지역",
    poolsHeader = "낚시 웅덩이",
    ratesHeader = "확률",
    descriptionHeader = "설명",
    specialHeader = "특수",
    pointsWord = "점",
    rankWords = { ["치어"] = "Guppy" },
    openWaterWord = "개방된 수역",
    poolWord = "웅덩이",
  },
  ptBR = {
    scoreLabel = "Pontuação de pescaria",
    rankLabel = "Grau da captura",
    areasHeader = "Áreas de ocorrência",
    poolsHeader = "Pesqueiros",
    ratesHeader = "Frequência",
    descriptionHeader = "Descrição",
    specialHeader = "Especial",
    pointsWord = "pontos",
    rankWords = { ["Lebiste"] = "Guppy" },
    openWaterWord = "águas abertas",
    poolWord = "pesqueiro",
    onlyWord = "apenas",
  },
  ruRU = {
    scoreLabel = "Счет рыбалки",
    rankLabel = { "Уровень улова", "Категория улова" },
    areasHeader = "Зоны обитания",
    poolsHeader = "Косяки рыб",
    ratesHeader = "Распространенность",
    descriptionHeader = "Описание",
    specialHeader = "Особое свойство",
    rankWords = { ["гуппи"] = "Guppy", ["Гуппи"] = "Guppy" },
    openWaterWord = "открытом море",
    poolWord = "прудах",
    onlyWord = "только",
  },
  zhCN = {
    scoreLabel = "钓鱼得分",
    rankLabel = "捕获等级",
    areasHeader = { "可发现此鱼的水域", "可以找到这种鱼的地方" },
    poolsHeader = { "垂钓池", "钓鱼场所" },
    ratesHeader = { "几率", "稀有度" },
    descriptionHeader = "描述",
    specialHeader = "特殊",
    pointsWord = "分",
    rankWords = { ["孔雀鱼"] = "Guppy" },
    openWaterWord = "开阔水域",
    poolWord = "鱼群",
  },
}
LOCALE_PARSE.enGB = LOCALE_PARSE.enUS
LOCALE_PARSE.esMX = {
  scoreLabel = "Puntaje de pesca",
  rankLabel = "Rango de la pesca",
  areasHeader = "Áreas donde puedes encontrar",
  poolsHeader = "Estanques de pesca",
  ratesHeader = "Tasa de captura",
  descriptionHeader = "Descripción",
  specialHeader = "Especial",
  pointsWord = "puntos",
  -- "Lebiestes" = Blizzard typo in the Dirty Darter's esMX text (seen 2026-08-23)
  rankWords = { ["Lebistes"] = "Guppy", ["Lebiste"] = "Guppy", ["Lebiestes"] = "Guppy" },
  openWaterWord = "aguas abiertas",
  poolWord = "estanque",
  onlyWord = "solo",
}
LOCALE_PARSE.zhTW = {
  scoreLabel = "釣魚分數",
  rankLabel = "漁獲等級",
  areasHeader = "可以找到這種魚的地區",
  poolsHeader = "釣魚池",
  ratesHeader = "機率",
  descriptionHeader = "說明",
  specialHeader = "特殊",
  pointsWord = "分",
  rankWords = { ["孔雀魚"] = "Guppy" },
  openWaterWord = "開放水域",
  poolWord = "魚群",
}


local PARSE = LOCALE_PARSE[GetLocale()] or LOCALE_PARSE.enUS
Journal.translated = LOCALE_PARSE[GetLocale()] ~= nil

-- Leading articles vary between fish in some languages ("l'île" / "île"), so they aren't part of a zone's identity.
LOCALE_PARSE.deDE.articlePrefixes = { "der ", "die ", "das " }
LOCALE_PARSE.esES.articlePrefixes = { "el ", "la ", "los ", "las " }
LOCALE_PARSE.esMX.articlePrefixes = LOCALE_PARSE.esES.articlePrefixes
LOCALE_PARSE.frFR.articlePrefixes = { "l’", "l'", "le ", "la ", "les " }
LOCALE_PARSE.itIT.articlePrefixes = { "l’", "l'", "il ", "lo ", "la ", "i ", "gli ", "le " }
LOCALE_PARSE.ptBR.articlePrefixes = { "o ", "a ", "os ", "as " }

local function ParseNumber(text)
  if not text then return nil end
  return tonumber((text:gsub(",", "."):gsub("%.+$", "")))
end

-- lower() plus Latin-1 accented capitals and Cyrillic, which lower() leaves alone.
local function FoldCase(text)
  text = text:lower()
  text = text:gsub("\195([\128-\158])", function(c)
    local b = c:byte()
    if b ~= 0x97 then return "\195" .. string.char(b + 32) end
  end)
  text = text:gsub("\208([\144-\175])", function(c)
    local b = c:byte()
    if b <= 0x9F then return "\208" .. string.char(b + 32) end
    return "\209" .. string.char(b - 32)
  end)
  return text
end

-- A zone's key: case folded, leading article dropped. Used on journal areas and live zone names alike.
function Journal.ZoneKey(name)
  local folded = FoldCase(name)
  for _, article in ipairs(PARSE.articlePrefixes or {}) do
    if folded:sub(1, #article) == article then return folded:sub(#article + 1) end
  end
  return folded
end

local function StartsWith(line, prefixes)
  if type(prefixes) ~= "table" then prefixes = { prefixes } end
  for _, prefix in ipairs(prefixes) do
    if line:sub(1, #prefix) == prefix then return true end
  end
  return false
end

local function FindLabel(text, labels)
  if type(labels) ~= "table" then labels = { labels } end
  for _, label in ipairs(labels) do
    local first, last = text:find(label, 1, true)
    if first then return first, last end
  end
end

-- Whole punctuation sequences only: multibyte letters share bytes with NBSP and "。".
local function StripEnds(text, list, fromEnd)
  local changed = true
  while changed do
    changed = false
    for _, piece in ipairs(list) do
      if fromEnd and #text >= #piece and text:sub(-#piece) == piece then
        text, changed = text:sub(1, -#piece - 1), true
      elseif not fromEnd and text:sub(1, #piece) == piece then
        text, changed = text:sub(#piece + 1), true
      end
    end
  end
  return text
end
local TRAILING = { " ", "\t", ".", ";", ",", "\194\160", "\227\128\130" }
local BULLET = { "-", "\226\128\147", " ", "\t", "\194\160" }

-- List items start with "-", or "–" in French.
local function BulletValue(line)
  if line:sub(1, 1) ~= "-" and line:sub(1, 3) ~= "\226\128\147" then return nil end
  local value = StripEnds(StripEnds(line, BULLET), TRAILING, true)
  return value ~= "" and value or nil
end

local function StripCodes(text)
  return (text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", "")
    :gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------

-- The Coiled Isle's vault names come out garbled in 12.1's journal text. They mean these two
-- maps; the client names them in its own language.
local MAP_ISLE, MAP_VAULTS, MAP_EVERSONG = 2512, 2509, 2395

-- The raw names each language's journal uses, from BrinyBest's harvest of live clients.
-- luacheck: push no max line length
local VAULTS_AND_ISLE = { vaults = true, isle = true }
local ISLE_ONLY = { isle = true }
local GARBLED_AREAS = {
  ["Atal'Utek"] = VAULTS_AND_ISLE,    -- enUS/deDE/esES/esMX/ptBR
  ["Atal'utek"] = VAULTS_AND_ISLE,    -- itIT
  ["Atal\226\128\153Utek"] = VAULTS_AND_ISLE, -- frFR (curly apostrophe)
  ["\236\149\132\237\131\136\236\154\176\237\133\141"] = VAULTS_AND_ISLE, -- koKR 아탈우텍
  ["\208\144\209\130\208\176\208\187'\208\163\209\130\208\181\208\186"] = VAULTS_AND_ISLE, -- ruRU Атал'Утек
  ["\233\152\191\229\161\148\228\185\140\231\137\185\229\133\139"] = VAULTS_AND_ISLE, -- zhCN 阿塔乌特克
  ["\233\152\191\229\161\148\231\131\143\231\137\185\229\133\139"] = VAULTS_AND_ISLE, -- zhTW 阿塔烏特克
  ["Vaults of Ula'tek"] = ISLE_ONLY,
  ["Gew\195\182lbe von Ula'tek"] = ISLE_ONLY,   -- deDE
  ["caveaux d\226\128\153Ula\226\128\153tek"] = ISLE_ONLY, -- frFR
  ["C\195\161maras de Ula'tek"] = ISLE_ONLY,    -- esES
  ["B\195\179vedas de Ula'tek"] = ISLE_ONLY,    -- esMX
  ["Segrete di Ula'tek"] = ISLE_ONLY,             -- itIT
  ["\236\154\184\235\157\188\237\133\141 \234\184\136\234\179\160"] = ISLE_ONLY, -- koKR 울라텍 금고
  ["C\195\162maras de Ula'tek"] = ISLE_ONLY,    -- ptBR
  ["\208\165\209\128\208\176\208\189\208\184\208\187\208\184\209\137\208\176 \208\163\208\187\208\176'\209\130\208\181\208\186"] = ISLE_ONLY, -- ruRU Хранилища Ула'тек
  ["\228\185\140\230\139\137\231\137\185\229\133\139\229\156\176\231\170\159"] = ISLE_ONLY, -- zhCN 乌拉特克地窟
  ["\231\131\143\230\139\137\231\137\185\229\133\139\229\175\182\229\186\171"] = ISLE_ONLY, -- zhTW 烏拉特克寶庫
}
-- luacheck: pop

local function MapName(mapID, fallback)
  local info = C_Map.GetMapInfo(mapID)
  return info and info.name or fallback
end

local function CorrectedAreas(area)
  local fix = GARBLED_AREAS[area]
  if not fix then return { area } end
  local out = {}
  if fix.vaults then out[#out + 1] = MapName(MAP_VAULTS, "Vaults of Atal'Utek") end
  if fix.isle then out[#out + 1] = MapName(MAP_ISLE, "The Coiled Isle") end
  return out
end

-- The Isle of Quel'Danas fishes Eversong Woods' list but is never named in the journal.
local ZONE_ALIASES = { [2424] = MAP_EVERSONG, [2432] = MAP_EVERSONG, [2565] = MAP_EVERSONG }

-- Keys of every name the player is standing in, most specific first: subzone, zone, then each
-- map up the chain.
function Journal.HereKeys()
  local keys, seen = {}, {}
  local function Add(name)
    if not name or name == "" then return end
    local key = Journal.ZoneKey(name)
    if not seen[key] then
      seen[key] = true
      keys[#keys + 1] = key
    end
  end
  Add(GetSubZoneText())
  Add(GetZoneText())
  local mapID, hops = C_Map.GetBestMapForUnit("player"), 0
  while mapID and mapID > 0 and hops < 6 do
    local info = C_Map.GetMapInfo(mapID)
    if not info then break end
    Add(info.name)
    if ZONE_ALIASES[mapID] then Add(MapName(ZONE_ALIASES[mapID])) end
    mapID, hops = info.parentMapID, hops + 1
  end
  return keys
end

---------------------------------------------------------------------------
-- One fish
---------------------------------------------------------------------------

-- Fish with their own lure; the Stargorger won't bite without it. The Snakehead's rate text wrongly
-- claims a lure is needed, so its rates are ignored.
Journal.lures = {
  [1225269] = true, [1225273] = true, [1225274] = true, [1225278] = true,
  [1225284] = true, [1295406] = true, [1295408] = true,
}
Journal.lureRequired = { [1295408] = true }
local IGNORE_RATES = { [1295406] = true }

-- nil while the description, or its score, hasn't loaded. Otherwise { name, score, areas, pools,
-- best = "open" | "pools" | "poolsOnly" | "either" | nil }.
function Journal.Read(spellID)
  local describe = C_Spell and C_Spell.GetSpellDescription
  local text = describe and describe(spellID)
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
  if not text or text == "" or not name or Compat.IsSecret(text) then return nil end
  text = StripCodes(text)
  local _, labelEnd = FindLabel(text, PARSE.scoreLabel)
  if not labelEnd then return nil end
  -- Skip the colon (" : " in French, fullwidth in Chinese) without crossing onto the next line.
  local score = ParseNumber(text:match("^[^%d\r\n]*([%d%.,]+)", labelEnd + 1))
  if not score then return nil end

  local fish = { id = spellID, name = name, score = score, areas = {}, pools = {} }
  local rates, mode, seen = {}, nil, {}
  for raw in text:gmatch("[^\n\r]+") do
    local line = raw:match("^%s*(.-)%s*$")
    if StartsWith(line, PARSE.areasHeader) then
      mode = "areas"
    elseif StartsWith(line, PARSE.poolsHeader) then
      mode = "pools"
    elseif StartsWith(line, PARSE.ratesHeader) then
      mode = "rates"
    elseif StartsWith(line, PARSE.descriptionHeader) or StartsWith(line, PARSE.specialHeader) then
      mode = nil
    else
      local value = BulletValue(line)
      if value and mode == "areas" then
        for _, area in ipairs(CorrectedAreas(value)) do
          if not seen[area] then
            seen[area] = true
            fish.areas[#fish.areas + 1] = area
          end
        end
      elseif value and mode == "pools" then
        fish.pools[#fish.pools + 1] = value
      elseif mode == "rates" and line ~= "" then
        rates[#rates + 1] = value or line -- French sometimes skips the bullet
      end
    end
  end

  -- Every Midnight fish bites in both; the rate text only says where it bites more often.
  if not IGNORE_RATES[spellID] then
    local rateText = table.concat(rates, " "):lower()
    local open = PARSE.openWaterWord and rateText:find(PARSE.openWaterWord, 1, true)
    local pool = PARSE.poolWord and rateText:find(PARSE.poolWord, 1, true)
    if pool and PARSE.onlyWord and rateText:find(PARSE.onlyWord, 1, true) then
      fish.best = "poolsOnly"
    elseif open and pool then
      fish.best = "either"
    elseif open then
      fish.best = "open"
    elseif pool then
      fish.best = "pools"
    end
  end
  return fish
end
