-- Retail game data. IDs are from Wowhead item, spell, NPC and currency pages.
local _, ns = ...

local Data = {}
ns.Data = Data

-- Angler's Fishing Raft: toy and the buff it gives.
Data.raft = { item = 85500, spell = 124036 }

-- Reusable Oversized Bobber: toy and the "Oversized Bobbers" buff.
Data.oversizedBobber = { item = 202207, spell = 397827 }

-- Crate of Bobbers toys. Only the ones the player owns are ever offered.
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

-- Lures to pick from automatically, best first. Empty on Retail: Midnight
-- lures each target one fish, so the player picks one with /tb lure.
Data.lures = {}

-- Lures Angler's TackleBox can name and list.
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

-- Rare drops worth counting attempts for. A cast counts when it is in scope:
-- on the given continent (pools only, where noted), or when it brought up a
-- fish from the given item ID range. "chance" is a community estimate.
Data.rareDrops = {
  { key = "seaTurtle", name = "Sea Turtle", item = 46109, mountSpell = 64731,
    continent = 113, poolOnly = true, chance = 0.002 },
  { key = "netherEgg", name = "Nether-Warped Egg", item = 268730, mountItem = 260916,
    fishRange = { 238360, 238390 } },
}

-- Hallowfall Fishing Derby quest variants.
Data.derbyQuests = { 82778, 83529, 83530, 83531, 83532 }

-- A hovered world object counts as a fishing pool when its name has one of
-- these words (enUS). Other locales accept any hovered object.
Data.poolWords = {
  "School", "Pool", "Swarm", "Surge", "Debris", "Wreckage", "Patch", "Cargo",
  "Treasures", "Bloom", "Ripple", "Shoal", "Spawn", "Slick", "Waters",
}

---------------------------------------------------------------------------
-- Shipped pool locations: a handful of known spots so a new player sees a
-- pin or two before they have fished anywhere themselves. This is kept
-- deliberately tiny. Fishing pools in modern WoW spawn dynamically rather
-- than at literal fixed points, and Wowhead does not track spawn locations
-- for fishing-pool objects at all -- its own object pages (e.g. Blood in
-- the Water, object=451678, and Royal Ripple, object=451680) say "The
-- location of this object is unknown," which held true even for Royal
-- Ripple, a pool that has existed since Hallowfall shipped in The War
-- Within, over a year before this was written. No fishing guide checked
-- (wow-professions.com, lorewoven.net, boostmatch.gg, wowsaga.com) gives
-- numeric coordinates for pool spawns either; they all point players at
-- in-game tracking tools instead.
--
-- The one entry below is a single community-reported sighting, not a
-- guaranteed respawn point -- it is a starting hint, not a promise the
-- pool will be there. Source: a Blizzard US forum post, "I also found a
-- Royal Ripple at 41, 53 in Hallowfall." Thread: "Anyone found Royal Ripple
-- fishing pool for the Derby yet?" on the Blizzard US forums, General
-- Discussion (thread id 1928171).
-- Corroborated in the same thread by a second poster describing their
-- fishing circuit as the coast "west of Mereldar" (Mereldar sits at
-- roughly 41.4, 50.3 per Warcraft Tavern's Hallowfall coordinate list),
-- which is the same stretch of water:
--   https://us.forums.blizzard.com/en/wow/t/hallowfall-fishing-derby-an-hour-of-my-life-i-wont-get-back/1947546
--
-- mapID 2215 = Hallowfall (Khaz Algar), corroborated by a TomTom "/way
-- #2215" coordinate for "The Undersea" sub-area of the same zone.
-- Coiled Isle (mapID 2512, confirmed by Method's Coiled Filament guide)
-- and every other Midnight zone were researched too, but turned up no
-- citable numeric pool coordinates at all -- see the report for this
-- change for the full list of sources checked. Broader coverage needs
-- someone to actually scout pools in-game and log coordinates; it isn't
-- something web research alone can responsibly produce.
Data.knownPools = {
  [2215] = { -- Hallowfall
    { x = 0.41, y = 0.53, name = "Royal Ripple" },
  },
}
