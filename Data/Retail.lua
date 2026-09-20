local _, ns = ...

local Data = {}
ns.Data = Data

-- Angler's Fishing Raft: toy and the buff it gives.
Data.raft = { item = 85500, spell = 124036 }

-- Lures to pick from automatically, best first. Midnight lure item IDs still
-- need collecting in-game; until then the player picks one with /tb lure.
Data.lures = {}

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
