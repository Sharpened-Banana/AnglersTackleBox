local _, ns = ...

local Data = {}
ns.Data = Data

-- Angler's Fishing Raft. Where the item doesn't exist it is simply never
-- found, so the raft option does nothing.
Data.raft = { item = 85500, spell = 124036 }

-- Lures to pick from automatically, best first.
Data.lures = {
  6533, -- Aquadynamic Fish Attractor (+100)
  6532, -- Bright Baubles (+75)
  7307, -- Flesh Eating Worm (+75)
  6811, -- Aquadynamic Fish Lens (+50)
  6530, -- Nightcrawlers (+50)
  6529, -- Shiny Bauble (+25)
}

-- Classic lures are temporary enchants on the pole and last 10 minutes.
Data.lureIsEnchant = true
Data.lureDuration = 600

Data.knownLures = Data.lures

Data.special = {}
Data.bobberToys = {}
Data.bobberDuration = 3600
Data.rareDrops = {}
Data.derbyQuests = {}
Data.npcs = {}
Data.spells = {}
Data.mounts = {}
Data.poolWords = {
  "School", "Pool", "Swarm", "Debris", "Wreckage", "Patch", "Slick", "Waters",
}
