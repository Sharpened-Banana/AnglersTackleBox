# Changelog

## 1.2.1

- **A new welcome tour.** The first-login window is now four short pages: what TackleBox does, picking your key, your first cast, and what's in the box, with a click-through to each compartment. Back and Next step through it, and your first cast moves it on. `/tb welcome` opens it any time.
- **The Briny tab shows your zone.** Your zone's total against its maximum (100 a fish), then this session's Midnight catches, newest first, with each fish's rank, score and the points it has gained this session. Hover a fish for how far it is from the next rank, whether it bites best in open water or pools, its lure and its pools; hover the zone for the fish with the most to gain there. With the Coiled Huntress equipped, the footer shows its venom.
- **More Briny Best in Goals:** Toxic Trophies progress (which of its eight fish still need Trophy), Coiled Huntress venom, and every zone with its total against its maximum, your zone first, each fish tagged open water, pools or lure with the points to its next rank.
- A fish reaching Trophy rank gets its own alert.
- The small window you fish with is now called the **Fishing Companion** everywhere: its title, the settings, the help and the tour.
- A welcome line in chat at every login and reload shows the version and how to open the interface. It can be turned off in the settings.
- `/tb briny` prints what the tracker reads from the journal, for checking it in game.

### Fixes

- Fishing into an Oceanic Vortex wasn't seen as a cast: the key didn't switch to reel in, the Fishing Companion stayed hidden and casts weren't counted. TackleBox now learns a cast like that from its first catch and treats it like normal fishing from then on (`/tb casts` lists what it learned).
- The settings panel stopped partway down: from "Track The Briny Best" on, nothing showed, because two settings shared a name.
- Briny scores no longer get stuck after a catch. The tracker now asks the game to reload the Fishing Journal a few times after each catch, so ranks, rank-up alerts and points gained show up.
- A Lua error, repeated every second, when reading lure timers on Retail 12.x, where Blizzard's own aura-by-name helper is broken.
- A Lua error from the Briny tracker when the game couldn't find the achievement's progress.

## 1.2.0

- Cast, catch and miss cues, in the Alarms compartment: a sound for each moment of a cast, an optional screen glow while the line is out, and green or red flashes on a catch or a miss. All sounds are off by default. The game gives addons no signal for the bite itself, so the splash is still your cue to reel in.
- Five sounds ship with the addon (Plink, Reel click, Chime, Falling tone, Water) for alerts and cues. With SharedMedia or another addon that loads LibSharedMedia, its sounds are listed too, and TackleBox's sounds are offered back to those addons.
- `/tb sound <name> cast|catch|miss` sets a cue sound from chat.
- The Briny Best tracker (Retail): tick "Track The Briny Best" in Goals or the settings. A Briny tab on the session window shows your Anglin' Score out of 2,500, the rank and points gained for the last Midnight fish you caught, and the fish in this zone with the most points left to earn. Goals lists every fish, lowest score first, and a rank-up gets its own alert. Built on BrinyBest by Andrew Edmond (MIT).
- The session window has an X in its corner. It hides the window until your next cast; your session carries on underneath. `/tb hud` still hides it for good.

## 1.1.0

- A /reload no longer ends your fishing session. Session numbers, goal progress and which goals already alerted carry on, and fishing mode turns itself back on. Back within 10 minutes of a logout works the same way; later than that, the session is filed as finished.
- Shopping has By fish and By recipe views. By recipe lists each Cooking recipe that uses a fish you've caught, linked to the dish, with have / need for each fish and how many your fish covers. The Cooking window is now rescanned on every list update, so recipe links appear after one visit.
- New Alarms compartment: session goals moved here from Goals, together with a switch for each kind of alert.
- Coiled Isle is now a section at the bottom of Events instead of its own compartment. The Window compartment's settings moved into the Top Tray as a Fishing Companion section under the double right-click option, and the Top Tray now scrolls.
- Shopping recipes and fish are real links again: hover for the tooltip, shift-click to put one in chat. A recipe list saved before this asks you to open Cooking once more to pick up the links.
- The Journal is now part of the Catch Log: one compartment with By zone and By fish views. `/tb log` opens By zone, and `/tb journal` and `/tb find` open By fish.
- The Shopping tab now fills in on Retail. It was looking for the open Cooking window with a function Blizzard removed in Dragonflight. It also works in every client language, counts only recipes you have learned, and remembers the list across logins.
- The Shopping tab is easier to read: each fish gets its own icon and a clickable, tooltip-able item link, its recipes each get their own line with a bit more room, and a recipe links to its dish too, using the item-link function Blizzard actually ships (the first attempt called one that doesn't exist).
- The box's compartment list now fits inside the box however many compartments there are, instead of the last ones spilling out the bottom. Shopping gets its icon.
- Lure auto-swap, off by default: when your chosen lure runs out and its effect ends, the next press applies the best other lure in your bags. A quiet text alert names it. Restocking your chosen lure switches back.
- Session goals on the Goals tab: set targets for catches, gold and minutes fished, see live progress, and get one alert per goal per session. Goal alerts have their own toggle.
- Catch-rate graph on the Statistics tab: catches per 5 minutes this session against your session average, with a rising, falling or steady trend. Between sessions it shows catches per hour across your last 25 saved sessions. The fishing window shows the current rate too.
- Fish price history, one point a day for up to 14 days, with a price graph on the Gold tab. History starts collecting from this version.
- The auction house no longer scans prices by itself. When prices are out of date it asks first, once per visit.
- Export and import your settings as a copyable string, from the Settings tab or with `/tb export settings` and `/tb import`. Catch data is never included.
- New option to use the same gear, pole, lure and extras settings on all your characters.
- Choose the alert sound from built-in game sounds, or none, with a Test button. `/tb sound` also sets a sound per kind of alert.

## 1.0.2

- New "Send feedback..." button on the Settings tab of the box: shows the GitHub issues link ready to copy.

## 1.0.1

- With fishing mode always on, running out of lures shows the text popup and chat line without the alert sound or screen flash.
- Sunwell Fish no longer triggers the rare catch alert. It is an uncommon fish; only special catches and fish at or above your alert quality alert.
- The fishing key no longer stops working after the mouse leaves the game window mid-press. A key that reads as held for over 1.5 seconds is now treated as stuck.
- New Statistics tab in the box, and a lifetime line for `/tb stats`: casts, catch and miss rates, time fishing and time with the line in the water, casts, catches and gold per hour, catches by quality, the last 24 hours, 7 days and 30 days, and a per-zone breakdown. Existing characters start from their saved sessions. "Line in the water" counts from this version on. Reset statistics starts the totals over.
- Statistics gets a Warband toggle: combined lifetime totals across every character on the account, plus a per-character breakdown once you have more than one.
- New Best Spot tab: ranks your known zones by gold per hour, catch rate or catch count, whichever the data supports, and warns when your current spot is well below your best known rate.
- New Shopping tab: while a Cooking window is open, lists which of your caught fish its recipes still need, how many you have, and roughly how many more casts that is at your own catch rate.
- A first shipped fishing pool pin (Royal Ripple, Hallowfall) shows on the map even before you have fished there yourself, marked separately from your own remembered spots.

## 1.0.0

First release, for Retail (Midnight 12.1) and WoW Forever.

**One-key fishing**
- One key of your choice casts, reels in, and keeps your pole, lure, raft, oversized bobber and bobber toy up. The addon only decides what the key does next; every action is your own keypress.
- Optional double right-click casting. Fishing mode can stay on all the time, and is inert in combat, while mounted, and inside dungeons, raids and PvP.
- Sound, soft-interact and camera changes apply only while you are actually fishing, and everything is restored afterwards, including after a crash.

**The box** (`/tb menu`)
- A tackle-box styled window: Top Tray, Lures, Bobbers, Catch Log, Journal, Gold, Goals, Events, Coiled Isle, Records, Window and Settings.
- A small fishing window with customisable tabs.

**Knowing your fishing**
- Catch log by zone, subzone and pool, with CSV export. Journal pages answer "where do I catch this?" from your own data.
- Fished spots remembered and pinned on the world map.
- Gold per hour by session, zone and spot, a value alert, a sell helper at vendors and the auction house, and fish price refresh through Auctionator. Prices are guarded against troll listings; grey items always count at vendor value.
- Goals: fishing achievements with their missing parts, fishing mounts, rare-drop attempt counters, skill-ups per catch, and the Hallowfall derby's missing fish.
- Events clock, Derby Dasher timer, Captain Tokka's Crew reputation and Coiled Filament progress.
- Personal records, a shareable session summary, an away warning, a minimap button and a data broker feed.
