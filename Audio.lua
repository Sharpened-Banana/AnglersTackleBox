-- Focus Audio: no event fires for the bobber splash, so its sound is the bite cue; boost it
-- while fishing. Core restores every CVar when fishing ends, on mode off, combat and logout.
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
