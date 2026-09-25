-- Retail game data. IDs are from Wowhead item, spell, NPC and currency pages.
local _, ns = ...

local Data = {}
ns.Data = Data

-- Angler's Fishing Raft: toy and the buff it gives.
Data.raft = { item = 85500, spell = 124036 }

-- Reusable Oversized Bobber: toy and the "Oversized Bobbers" buff.
Data.oversizedBobber = { item = 202207, spell = 397827 }

-- Crate of Bobbers toys; only owned ones are offered.
Data.bobberToys = {
  142528, -- Can of Worms
  142529, -- Cat Head
  142530, -- Tugboat
  142531, -- Squeaky Duck
  142532, -- Murloc Head
  143662, -- Wooden Pepe
  147307, -- Carved Wooden Helm
  147308, -- Enchanted Bobber
  147309, -- Face of the Forest
  147310, -- Floating Totem
  147311, -- Replica Gondola
  147312, -- Demon Noggin
}
Data.bobberDuration = 3600

-- Auto-pick lures, best first. Empty: Midnight lures each target one fish,
-- so the player picks with /tb lure.
Data.lures = {}

-- Lures the addon can name and list.
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
}

Data.npcs = {
  birdie = 263682, -- Master Grenadier Birdie: +50 Tokka rep when killed
}

Data.spells = {
  derbyDasher = 456024, -- Hallowfall Fishing Derby one-hour buff
}

-- 12.1 Coiled Isle. The faction is found by enUS name at runtime.
Data.midnight = {
  factionName = "Captain Tokka's Crew",
  currencyName = "Coiled Filament",
  currencyID = 3546,
  mountCost = 2500, -- Sea-Dwelling Isle Serpent
}

-- The Briny Best (12.1): 2,500 Midnight Anglin' Score in the Fishing Journal. Each journal fish is a
-- dummy recipe spell whose description carries its live score (0-100) and catch rank. IDs from
-- BrinyBest by Andrew Edmond (MIT). The six Cursed Oddities carry no score and are left out.
Data.briny = {
  achievement = 63510,
  target = 2500,
  fish = {
    1225282, -- Arcane Wyrmfish
    1295409, -- Dirty Darter
    1225275, -- Gore Guppy
    1225270, -- Lynxfish
    1225269, -- Root Crab
    1225245, -- Sin'dorei Swarmer
    1295404, -- Spotted Killifish
    1295405, -- Toxic Tlhapi
    1225266, -- Bloomtail Minnow
    1225276, -- Fungalskin Pike
    1225267, -- Hollow Grouper
    1295410, -- Polluted Puffer
    1225277, -- Restored Songfish
    1225272, -- Shimmer Spinefish
    1225271, -- Shimmersiren
    1295407, -- Sulfurous Sludgefish
    1225278, -- Sunwell Fish
    1225281, -- Tender Lumifin
    1295411, -- Blightswarmer
    1225274, -- Blood Hunter
    1295408, -- Coiled Stargorger
    1225283, -- Eversong Trout
    1225284, -- Lucky Loa
    1225268, -- Null Voidfish
    1225273, -- Ominous Octopus
    1225280, -- Twisted Tetra
    1295406, -- Ula'tek Snakehead
    1225279, -- Warping Wise
  },
}

-- Fishing mounts, by summon spell or teaching item.
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

-- Rare drops to count attempts for. A cast counts if on the continent (pools
-- only where noted) or if it caught a fish in fishRange. chance is a community estimate.
Data.rareDrops = {
  { key = "seaTurtle", name = "Sea Turtle", item = 46109, mountSpell = 64731,
    continent = 113, poolOnly = true, chance = 0.002 },
  { key = "netherEgg", name = "Nether-Warped Egg", item = 268730, mountItem = 260916,
    fishRange = { 238360, 238390 } },
}

-- Hallowfall Fishing Derby quest variants.
Data.derbyQuests = { 82778, 83529, 83530, 83531, 83532 }

-- A hovered object is a pool if its name has one of these enUS words.
-- Other locales accept any hovered object.
Data.poolWords = {
  "School", "Pool", "Swarm", "Surge", "Debris", "Wreckage", "Patch", "Cargo",
  "Treasures", "Bloom", "Ripple", "Shoal", "Spawn", "Slick", "Waters",
}

---------------------------------------------------------------------------
-- Shipped pool locations: a starter pin or two for new players. Kept tiny on
-- purpose: modern pools spawn dynamically, and neither Wowhead ("location of
-- this object is unknown") nor fishing guides publish pool coordinates.
-- Add only citable, in-game-scouted coordinates; never invent them.
--
-- Royal Ripple at 41, 53 is one community sighting, a hint not a respawn
-- point: Blizzard US forums General Discussion thread 1928171, corroborated
-- by "west of Mereldar" (~41.4, 50.3) in:
--   https://us.forums.blizzard.com/en/wow/t/hallowfall-fishing-derby-an-hour-of-my-life-i-wont-get-back/1947546
-- mapID 2215 = Hallowfall. Coiled Isle (mapID 2512) and other Midnight zones
-- turned up no citable coordinates.
Data.knownPools = {
  [2215] = { -- Hallowfall
    { x = 0.41, y = 0.53, name = "Royal Ripple" },
  },
}
