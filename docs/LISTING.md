# Store listing text (CurseForge and Wago)

**Summary (one line):** One-key fishing that remembers what you caught: catch log, gold per hour, map pins, goals and a tackle-box window. Retail and WoW Forever.

**Project image:** `art/logo-512.png` (square; `art/logo-1024.png` if the site wants larger, `art/logo.svg` is the source).

**Categories:** Professions, Fishing (if offered), Map & Minimap, Auction & Economy.

---

## Description

**Angler's TackleBox** puts your whole fishing routine on one key, and keeps a record of everything that comes out of the water.

### One key does the fishing
Pick any key. While fishing mode is on, each press does the next right thing: equip the pole, apply your lure, use your oversized bobber or bobber toy, start the raft, cast, and reel in on the splash. The addon only chooses what the key does next. Every action is your own keypress, which is exactly what Blizzard's rules allow. Nothing is automated and nothing clicks for you.

- Works with a key, or a quick double right-click.
- Leave fishing mode on all day if you like. It steps aside in combat, while mounted, and inside dungeons, raids and PvP.
- Sound and interact settings change only while you are actually fishing, and are always put back, even after a crash.

### It remembers
- **Catch log** with two views: by zone, subzone and pool with CSV export, and by fish, a page per fish answering "where do I catch this?" from your own catches.
- **Map pins** for every spot you have fished, with what you caught there.
- **Gold**: session gold and gold per hour, your best zones and best individual spots, an alert for valuable catches, a sell helper at vendors and the auction house, and a 30-session chart. Uses Auctionator or TSM prices when you have them, guarded against troll listings.
- **Goals**: fishing achievements with their missing parts, fishing mounts, rare-drop attempt counters (Sea Turtle, Nether-Warped Egg), and skill-ups per catch.
- **Midnight**: Captain Tokka's Crew reputation, Coiled Filament progress, Master Grenadier Birdie alerts, Derby Dasher timer.
- **Records** and a one-click session summary for chat.

### The box
`/tb menu` opens a tackle-box styled window with a compartment for everything above. While you fish, a small window shows your session, with tabs you choose.

### Getting started
1. `/tb bind` and press the key you want to fish with.
2. `/tb` to turn fishing mode on (or make it always on in the box).
3. Face some water and press your key. Press it again on the splash.

`/atb` works wherever `/tb` does.

### Notes
- No libraries bundled. LibDataBroker and LibDBIcon are used if another addon provides them.
- Optional: Auctionator or TradeSkillMaster for auction prices.
- Not related to the addon "Tacklebox" by earl_parvisjam. The two can be installed side by side.
