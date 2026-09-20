local _, ns = ...

local Data = {}
ns.Data = Data

-- Angler's Fishing Raft: toy and the buff it gives.
Data.raft = { item = 85500, spell = 124036 }

-- Lures to pick from automatically, best first. Empty on Retail: Midnight
-- lures each target one fish, so the player picks one with /tb lure.
Data.lures = {}

-- Midnight lures Tacklebox can name and list. Each targets one fish, so
-- none is "best": the player picks. IDs confirmed on Wowhead; the rest
-- (Blood Hunter, Amani Angler's Ward, the 12.1 lures) still need collecting.
Data.knownLures = {
  241145, -- Lucky Loa Lure
  241149, -- Ominous Octopus Lure
  241150, -- Sunwell Fish Lure
}

-- 12.1 Coiled Isle. Found by enUS name at runtime until the IDs are known.
Data.midnight = {
  factionName = "Captain Tokka's Crew",
  currencyName = "Coiled Filament",
  mountCost = 2500, -- Sea-Dwelling Isle Serpent
}

-- Midnight lures are buffs, not pole enchants, and last 30 minutes.
Data.lureIsEnchant = false
Data.lureDuration = 1800

-- Catches that get their own alert. Keyed by enUS item name until the item
-- IDs are collected; other locales fall back to the quality-based alert.
Data.special = {
  ["Nether-Warped Egg"] = "mount",
  ["Warping Wise"] = "teleport",
  ["Blood Hunter"] = "hostile",
  ["Null Voidfish"] = "rare",
  ["Ominous Octopus"] = "rare",
}
