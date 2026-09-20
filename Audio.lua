-- Focus Audio: the game fires no event for the bobber splash, so the splash
-- sound is the bite cue. Boost it while the player is actually fishing; Core
-- restores every CVar when that ends, on mode off, on combat and on logout.
local _, ns = ...

local Audio = ns:NewModule("Audio")

function Audio:Focus()
  local opts = ns.db.audio
  if not opts.enabled then return end
  local CVars = ns.CVars
  CVars:Set("Sound_EnableAllSound", 1)
  CVars:Set("Sound_EnableSFX", 1)
  CVars:Set("Sound_SFXVolume", opts.sfxVolume)
  if opts.muteMusic then CVars:Set("Sound_MusicVolume", 0) end
  if opts.muteAmbience then CVars:Set("Sound_AmbienceVolume", 0) end
  if opts.backgroundSound then CVars:Set("Sound_EnableSoundWhenGameIsInBG", 1) end
end
