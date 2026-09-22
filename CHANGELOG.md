# Changelog

## 1.1.0

- The Shopping tab now fills in on Retail. It was looking for the open Cooking window with a function Blizzard removed in Dragonflight. It also works in every client language, counts only recipes you have learned, and remembers the list across logins.
- The box's compartment list now fits inside the box however many compartments there are, instead of the last ones spilling out the bottom. Shopping gets its icon.
- Lure auto-swap, off by default: when your chosen lure runs out and its effect ends, the next press applies the best other lure in your bags. A quiet text alert names it. Restocking your chosen lure switches back.
- Session goals on the Goals tab: set targets for catches, gold and minutes fished, see live progress, and get one alert per goal per session. Goal alerts have their own toggle.
- Catch-rate graph on the Statistics tab: catches per 5 minutes this session against your session average, with a rising, falling or steady trend. The fishing window shows the current rate too.
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
