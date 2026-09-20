-- Retail game data. IDs are from Wowhead item, spell, NPC and currency pages.
local _, ns = ...

local Data = {}
ns.Data = Data

-- Angler's Fishing Raft: toy and the buff it gives.
Data.raft = { item = 85500, spell = 124036 }

-- Lures to pick from automatically, best first. Empty on Retail: Midnight
-- lures each target one fish, so the player picks one with /tb lure.
Data.lures = {}

-- Lures Tacklebox can name and list.
Data.knownLures = {
  241145, -- Lucky Loa Lure
  241147, -- Blood Hunter Lure
  241149, -- Ominous Octopus Lure
  241150, -- Sunwell Fish Lure
  241151, -- Coiled Stargorger Lure
  277821, -- Ula'tek Snakehead Lure
  281022, -- Eerie Lure
}

-- Midnight lures are buffs, not pole enchants, and last 30 minutes.
Data.lureIsEnchant = false
Data.lureDuration = 1800

-- Catches that get their own alert, by item ID.
Data.special = {
  [268730] = "mount",    -- Nether-Warped Egg
  [238379] = "teleport", -- Warping Wise
  [238377] = "hostile",  -- Blood Hunter
  [238380] = "rare",     -- Null Voidfish
  [238373] = "rare",     -- Ominous Octopus
  [238376] = "rare",     -- Lucky Loa
  [238384] = "rare",     -- Sunwell Fish
}

Data.npcs = {
  birdie = 263682, -- Master Grenadier Birdie: +50 Tokka rep when killed
}

Data.spells = {
  derbyDasher = 456024, -- Hallowfall Fishing Derby: one hour to catch the trophy fish
}

-- 12.1 Coiled Isle. The faction is found by enUS name at runtime.
Data.midnight = {
  factionName = "Captain Tokka's Crew",
  currencyName = "Coiled Filament",
  currencyID = 3546,
  mountCost = 2500, -- Sea-Dwelling Isle Serpent
}

-- Mounts that come from fishing, by summon spell or by the item that teaches them.
Data.mounts = {
  { spell = 64731 },  -- Sea Turtle
  { spell = 118089 }, -- Azure Water Strider
  { spell = 127271 }, -- Crimson Water Strider
  { spell = 214791 }, -- Brinedeep Bottom-Feeder
  { spell = 253711 }, -- Pond Nettle
  { spell = 278803 }, -- Great Sea Ray
  { spell = 448850 }, -- Kah, Legend of the Deep
  { item = 260916 },  -- Nether-Swept Drake
  { item = 275653 },  -- Sea-Dwelling Isle Serpent
}

-- A hovered world object counts as a fishing pool when its name has one of
-- these words (enUS). Other locales accept any hovered object.
Data.poolWords = {
  "School", "Pool", "Swarm", "Surge", "Debris", "Wreckage", "Patch", "Cargo",
  "Treasures", "Bloom", "Ripple", "Shoal", "Spawn", "Slick", "Waters",
}
