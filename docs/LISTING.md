# Store listing text (CurseForge and Wago)

**Summary (one line):** One-key fishing that remembers what you caught: catch log, gold per hour, trend graphs, session goals, a cooking shopping list and a tackle-box window. Retail and WoW Forever.

**Project image:** `art/logo-512.png` (square; `art/logo-1024.png` if the site wants larger, `art/logo.svg` is the source).

**Categories:** Professions, Fishing (if offered), Map & Minimap, Auction & Economy.

**Screenshots:** see `docs/SCREENSHOTS.md` for the shot list and captions.

---

## Description

**Angler's TackleBox** puts your whole fishing routine on one key, and keeps a record of everything that comes out of the water.

### One key does the fishing
Pick any key. While fishing mode is on, each press does the next right thing: equip the pole, apply your lure, use your oversized bobber or bobber toy, start the raft, cast, and reel in on the splash. The addon only chooses what the key does next. Every action is your own keypress, which is exactly what Blizzard's rules allow. Nothing is automated and nothing clicks for you.

- Works with a key, or a quick double right-click.
- Leave fishing mode on all day if you like. It steps aside in combat, while mounted, and inside dungeons, raids and PvP.
- A `/reload` doesn't end your session: your numbers, goals and fishing mode carry on.
- **Lure auto-swap** (optional): when your chosen lure runs out, the next press applies the best other lure in your bags.
- Sound and interact settings change only while you are actually fishing, and are always put back, even after a crash.

### It remembers
- **Catch log** with two views: by zone, subzone and pool with CSV export, and by fish, a page per fish answering "where do I catch this?" from your own catches.
- **Map pins** for every spot you have fished, with what you caught there.
- **Gold**: session gold and gold per hour, your best zones and spots, an alert for valuable catches, a sell helper at vendors and the auction house, a 30-session chart, and a **price history graph** per fish. Uses Auctionator or TSM prices, guarded against troll listings. Stale prices are refreshed only when you say so.
- **Statistics**: lifetime and warband totals, and a **catch-rate graph** that shows whether your spot is drying up.
- **Best Spot**: your zones ranked by gold per hour or catch rate.
- **Shopping list**: open Cooking once and see which recipes need fish you've caught, by fish or by recipe, with clickable links and how many casts you still need.
- **Goals**: fishing achievements with their missing parts, fishing mounts, rare-drop attempt counters (Sea Turtle, Nether-Warped Egg), and skill-ups per catch.
- **Events**: fishing contest countdowns, plus Midnight's Captain Tokka's Crew reputation, Coiled Filament progress, Derby Dasher timer and Master Grenadier Birdie alerts.
- **Records** and a one-click session summary for chat.

### Alarms
Set session goals for catches, gold or minutes fished and get one alert when you reach each. Choose which kinds of event alert you, and pick the alert sound from the game's own sounds, or none.

### The box
`/tb menu` opens a tackle-box styled window with a compartment for everything above. While you fish, a small Fishing Companion window shows your session, with tabs you choose in the Top Tray.

### Settings travel with you
Export your settings as a string and import them anywhere, or use one set of gear, pole and lure settings on all your characters.

### Getting started
1. `/tb bind` and press the key you want to fish with.
2. `/tb` to turn fishing mode on (or make it always on in the box).
3. Face some water and press your key. Press it again on the splash.

`/atb` works wherever `/tb` does. Found a bug or have an idea? Settings > Send feedback.

### Notes
- No libraries bundled. LibDataBroker and LibDBIcon are used if another addon provides them.
- Optional: Auctionator or TradeSkillMaster for auction prices.
- Not related to the addon "Tacklebox" by earl_parvisjam. The two can be installed side by side.
