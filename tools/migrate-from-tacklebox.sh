#!/bin/sh
# One-off: moves a development install from the old name (Tacklebox) to
# Angler's TackleBox. Swaps the AddOns symlink and copies saved variables to
# the new names. Never overwrites, never deletes saved data, and only touches
# files that are recognisably this addon's (another addon is also called
# Tacklebox). Pass --dry-run to see what it would do.
set -e
WOW="${WOW_DIR:-/Applications/World of Warcraft}"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
DRY=""; [ "$1" = "--dry-run" ] && DRY="echo would:"

if pgrep -f "World of Warcraft" >/dev/null 2>&1; then
  echo "Quit World of Warcraft first: it rewrites saved variables when it exits."; exit 1
fi

for client in _retail_ _classic_beta_; do
  addons="$WOW/$client/Interface/AddOns"
  old="$addons/Tacklebox"; new="$addons/AnglersTackleBox"
  if [ -L "$old" ] && [ "$(cd "$old" && pwd -P)" = "$REPO" ]; then
    $DRY rm "$old"
    [ -e "$new" ] || $DRY ln -s "$REPO" "$new"
    echo "$client: addon link renamed"
  fi

  find "$WOW/$client/WTF" -path "*SavedVariables/Tacklebox.lua" 2>/dev/null | while read -r file; do
    target="$(dirname "$file")/AnglersTackleBox.lua"
    if [ -e "$target" ]; then echo "kept existing: $target"; continue; fi
    # Ours has these keys; the other Tacklebox addon's file would not.
    if grep -q "^TackleboxDB = " "$file" && grep -q '"cvarBackup"' "$file"; then :
    elif grep -q "^TackleboxCharDB = " "$file" && grep -q '"lureEnabled"' "$file"; then :
    else echo "skipped (not this addon's): $file"; continue; fi
    if [ -n "$DRY" ]; then echo "would: copy $file -> $target"; continue; fi
    sed -e 's/^TackleboxDB = /AnglersTackleBoxDB = /' -e 's/^TackleboxCharDB = /AnglersTackleBoxCharDB = /' "$file" > "$target"
    echo "copied: $target"
  done
done
echo "Done. The old Tacklebox.lua files are left in place as a backup."
