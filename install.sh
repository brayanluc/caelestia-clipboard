#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYS_DIR="/etc/xdg/quickshell/caelestia"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
HYPR_USER="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/hypr-user.lua"
BIND_MODE="${1:-auto}"

if [ ! -d "$SYS_DIR" ]; then
    echo "Error: $SYS_DIR not found. Is caelestia-shell installed?"
    exit 1
fi

for dep in cliphist wl-copy wl-paste python3; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Warning: $dep not found in PATH."
    fi
done

if ! pgrep -u "$USER" -f "cliphist store" >/dev/null 2>&1; then
    echo "Warning: cliphist watcher is not running. Add 'wl-paste --watch cliphist store' to your Hyprland autostart."
fi

rm -rf "$CFG_DIR"
mkdir -p "$CFG_DIR/components" "$CFG_DIR/modules/drawers"

for item in "$SYS_DIR"/*; do
    base="$(basename "$item")"
    case "$base" in
        components|modules) continue ;;
        *) ln -s "$item" "$CFG_DIR/$base" ;;
    esac
done

for item in "$SYS_DIR/components"/*; do
    base="$(basename "$item")"
    [ "$base" = "ScreenState.qml" ] && continue
    ln -s "$item" "$CFG_DIR/components/$base"
done

for item in "$SYS_DIR/modules"/*; do
    base="$(basename "$item")"
    [ "$base" = "drawers" ] && continue
    ln -s "$item" "$CFG_DIR/modules/$base"
done
cp -r "$REPO_DIR/src/modules/clipboard" "$CFG_DIR/modules/clipboard"

for item in "$SYS_DIR/modules/drawers"/*; do
    base="$(basename "$item")"
    case "$base" in
        ContentWindow.qml|Panels.qml|Regions.qml) continue ;;
        *) ln -s "$item" "$CFG_DIR/modules/drawers/$base" ;;
    esac
done

python3 - "$SYS_DIR" "$CFG_DIR" << "PYEOF"
import sys
from pathlib import Path

sys_dir = Path(sys.argv[1])
cfg_dir = Path(sys.argv[2])

def patch_file(rel_path, replacements):
    text = (sys_dir / rel_path).read_text()
    for old, new in replacements:
        assert old in text, f"Patch anchor not found in {rel_path}: {old!r}"
        text = text.replace(old, new, 1)
    (cfg_dir / rel_path).write_text(text)

patch_file("components/ScreenState.qml", [
    ("    property bool sidebar
", "    property bool sidebar
    property bool clipboard
"),
])

patch_file("modules/drawers/Panels.qml", [
    ("import qs.modules.launcher as Launcher
", "import qs.modules.clipboard as Clipboard
import qs.modules.launcher as Launcher
"),
    ("    readonly property alias launcher: launcher
", "    readonly property alias clipboard: clipboard
    readonly property alias launcher: launcher
"),
    ("    Launcher.Wrapper {
        id: launcher
", "    Clipboard.Wrapper {
        id: clipboard

        screen: root.screen
        screenState: root.screenState
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Launcher.Wrapper {
        id: launcher
"),
])

patch_file("modules/drawers/ContentWindow.qml", [
    ("        screenState.launcher = false;
", "        screenState.clipboard = false;
        screenState.launcher = false;
"),
    ("WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None", "WlrLayershell.keyboardFocus: screenState.launcher || screenState.session || screenState.clipboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None"),
    ("if ((s.launcher && conf.launcher.enabled) || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))", "if ((s.launcher && conf.launcher.enabled) || s.clipboard || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))"),
    ("            root.screenState.launcher = false;
", "            root.screenState.clipboard = false;
            root.screenState.launcher = false;
"),
    ("        PanelBg {
            id: launcherBg

            panel: panels.launcher
            deformAmount: 0.1
        }
", "        PanelBg {
            id: clipboardBg

            panel: panels.clipboard
            deformAmount: 0.1
        }

        PanelBg {
            id: launcherBg

            panel: panels.launcher
            deformAmount: 0.1
        }
"),
    ("            launcher.transform: Matrix4x4 {
                matrix: launcherBg.deformMatrix
            }
", "            clipboard.transform: Matrix4x4 {
                matrix: clipboardBg.deformMatrix
            }
            launcher.transform: Matrix4x4 {
                matrix: launcherBg.deformMatrix
            }
"),
])

patch_file("modules/drawers/Regions.qml", [
    ("    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }
", "    R {
        panel: root.panels.clipboard
        y: root.win.height - height
        height: panel.height * (1 - root.panels.clipboard.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }
"),
])
PYEOF

if [ -f "$HYPR_USER" ] && command -v hyprctl >/dev/null 2>&1; then
    python3 - "$HYPR_USER" "$BIND_MODE" << "PYEOF"
import json, subprocess, sys
from pathlib import Path

hypr_user = Path(sys.argv[1])
mode = sys.argv[2]
marker_start = "-- >>> caelestia-clipboard >>>"
marker_end = "-- <<< caelestia-clipboard <<<"

content = hypr_user.read_text()
if marker_start in content or "drawers toggle clipboard" in content:
    print("Keybind for caelestia-clipboard is already configured.")
    sys.exit(0)

try:
    binds = json.loads(subprocess.check_output(["hyprctl", "binds", "-j"], stderr=subprocess.DEVNULL))
except Exception:
    binds = []

super_v_in_use = any(
    b.get("modmask") == 64 and b.get("key", "").lower() == "v" and b.get("submap", "") == ""
    for b in binds
)

apply_bind = False
unbind_first = False

if not super_v_in_use:
    apply_bind = True
elif mode == "--replace-bind":
    apply_bind = True
    unbind_first = True
elif mode == "--skip-bind":
    apply_bind = False
elif sys.stdin.isatty():
    ans = input("SUPER + V is already bound in Hyprland/Caelestia. Replace it with caelestia-clipboard? [y/N] ").strip().lower()
    if ans in ("y", "yes", "s", "sim"):
        apply_bind = True
        unbind_first = True
    else:
        print("Skipped keybind setup. Bind 'caelestia shell drawers toggle clipboard' manually.")
else:
    print("SUPER + V is already in use; skipped automatic keybind override.")

if apply_bind:
    lines = [marker_start]
    if unbind_first:
        lines.append("pcall(hl.unbind, "SUPER + V")")
    lines.append("hl.bind("SUPER + V", hl.dsp.exec_cmd("caelestia shell drawers toggle clipboard"))")
    lines.append(marker_end)
    sep = "" if content.endswith("

") else ("
" if content.endswith("
") else "

")
    hypr_user.write_text(content + sep + "
".join(lines) + "
")
    print(f"Added SUPER + V keybind to {hypr_user}")
PYEOF
fi

echo "caelestia-clipboard installed in $CFG_DIR"
echo "Restart Quickshell to apply: pkill -x qs; qs -c caelestia -n -d &"
