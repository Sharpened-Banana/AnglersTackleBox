# Tacklebox

One-key fishing for World of Warcraft that remembers what you caught. Retail (Midnight 12.1) first, with Classic Era and Mists Classic TOCs. The full design is in `Tacklebox — WoW Fishing Addon Design.md`.

## How it works

You pick one key. While fishing mode is on, each press of that key does the next right thing: equip the pole (Classic), start the raft, apply a lure, cast, or reel in. The addon only decides what the key does next; your keypress does the action. With fishing mode off the addon is inert: no events, no timers, no bindings, no CVar changes. Even with it on, sound and interact settings only change from your first cast until 30 seconds after you stop, so the mode is safe to leave on all day.

## Install for testing

Symlink the repo into the game's AddOns folder, then `/reload`:

    ln -s "$PWD" "/Applications/World of Warcraft/_retail_/Interface/AddOns/Tacklebox"

## Use

1. `/tb bind` and press the key you want to fish with.
2. `/tb` to turn fishing mode on. It is also in the addon compartment and under Options > Keybindings > AddOns.
3. Press your key to cast, and again when the bobber splashes.

| Command | What it does |
| --- | --- |
| `/tb` | Toggle fishing mode |
| `/tb menu` | Open the Tacklebox window (also: left-click the addon compartment icon) |
| `/tb always [on\|off]` | Keep fishing mode on all the time; `/tb` still pauses it |
| `/tb bind`, `/tb key F`, `/tb key none` | Pick, set or clear the fishing key |
| `/tb lure <link or ID>`, `/tb lure auto`, `/tb lure off` | Choose the lure to keep up |
| `/tb extra <link or ID>` | Add or remove a toy or item to keep up (bobber toys, tea) |
| `/tb raft [on\|off]` | Use the fishing raft |
| `/tb oversized [on\|off]` | Keep the Reusable Oversized Bobber up |
| `/tb bobber [random\|off\|link or ID]` | Bobber toy to keep up; no argument opens the list |
| `/tb doubleclick [on\|off]` | A quick double right-click does the same as the key |
| `/tb set <name>`, `/tb set none` | Equipment set to wear while fishing |
| `/tb hud` | Show or hide the session window |
| `/tb tabs` | Choose and order the session window's tabs (Session always stays first) |
| `/tb log` | Catch log window: per-zone catches, share, value and pools |
| `/tb stats`, `/tb reset` | Print or restart session stats |
| `/tb find <fish>` | Where you catch it, from your own log (no argument opens the Journal) |
| `/tb gold` | Best zones and spots by gold per hour |
| `/tb records`, `/tb share [party\|guild\|say]` | Personal records; post this session to chat |
| `/tb camera save\|on\|off` | Fishing camera zoom preset |
| `/tb pins`, `/tb minimap` | Toggle world map pins and the minimap button |
| `/tb events` | Countdowns to the fishing contests (realm time) |
| `/tb goals` | Progress on unfinished fishing achievements |
| `/tb midnight` | Captain Tokka's Crew reputation and Coiled Filament toward the mount |
| `/tb options` | Open the settings panel |

## Leaving the gold module out of a release

Everything gold-related (rankings, value alert, sell helper, history chart) lives in `Gold.lua`, and nothing else depends on it. To keep it private, remove `Gold.lua` from the three TOC files and add it to `ignore:` in `.pkgmeta`. The Gold compartment and `/tb gold` disappear by themselves.

## Development

    luacheck .
    lua tests/smoke.lua

`tests/smoke.lua` stubs the WoW API and drives one fishing session through the state machine. It checks the wiring, not the game: in-game testing is still needed for anything the stubs assume.
