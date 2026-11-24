#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
HYPR_USER="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/hypr-user.lua"

if [ -d "$CFG_DIR" ]; then
    rm -rf "$CFG_DIR"
    echo "Removed $CFG_DIR (Caelestia will fall back to /etc/xdg/quickshell/caelestia)."
else
    echo "Nothing to remove in $CFG_DIR."
fi

if [ -f "$HYPR_USER" ] && grep -q -- "-- >>> caelestia-clipboard >>>" "$HYPR_USER"; then
    python3 - "$HYPR_USER" << "PYEOF"
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text()
text = re.sub(r"
*-- >>> caelestia-clipboard >>>.*?-- <<< caelestia-clipboard <<<
*", "
", text, flags=re.S)
p.write_text(text.rstrip() + "
")
PYEOF
    echo "Removed caelestia-clipboard keybind from $HYPR_USER"
fi

echo "Restart Quickshell to apply: pkill -x qs; qs -c caelestia -n -d &"
