#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYS_DIR="/etc/xdg/quickshell/caelestia"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"

if [ ! -d "$SYS_DIR" ]; then
    echo "Error: $SYS_DIR not found. Is caelestia-shell installed?"
    exit 1
fi

for dep in cliphist wl-copy python3; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Warning: $dep not found in PATH."
    fi
done

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
ln -s "$REPO_DIR/src/modules/clipboard" "$CFG_DIR/modules/clipboard"

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
    ("    property bool sidebar\n", "    property bool sidebar\n    property bool clipboard\n"),
])

patch_file("modules/drawers/Panels.qml", [
    ("import qs.modules.launcher as Launcher\n", "import qs.modules.clipboard as Clipboard\nimport qs.modules.launcher as Launcher\n"),
    ("    readonly property alias launcher: launcher\n", "    readonly property alias clipboard: clipboard\n    readonly property alias launcher: launcher\n"),
    ("    Launcher.Wrapper {\n        id: launcher\n", "    Clipboard.Wrapper {\n        id: clipboard\n\n        screen: root.screen\n        screenState: root.screenState\n        panels: root\n\n        anchors.horizontalCenter: parent.horizontalCenter\n        anchors.bottom: parent.bottom\n    }\n\n    Launcher.Wrapper {\n        id: launcher\n"),
])

patch_file("modules/drawers/ContentWindow.qml", [
    ("        screenState.launcher = false;\n", "        screenState.clipboard = false;\n        screenState.launcher = false;\n"),
    ("WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None", "WlrLayershell.keyboardFocus: screenState.launcher || screenState.session || screenState.clipboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None"),
    ("if ((s.launcher && conf.launcher.enabled) || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))", "if ((s.launcher && conf.launcher.enabled) || s.clipboard || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))"),
    ("            root.screenState.launcher = false;\n", "            root.screenState.clipboard = false;\n            root.screenState.launcher = false;\n"),
    ("        PanelBg {\n            id: launcherBg\n\n            panel: panels.launcher\n            deformAmount: 0.1\n        }\n", "        PanelBg {\n            id: clipboardBg\n\n            panel: panels.clipboard\n            deformAmount: 0.1\n        }\n\n        PanelBg {\n            id: launcherBg\n\n            panel: panels.launcher\n            deformAmount: 0.1\n        }\n"),
    ("            launcher.transform: Matrix4x4 {\n                matrix: launcherBg.deformMatrix\n            }\n", "            clipboard.transform: Matrix4x4 {\n                matrix: clipboardBg.deformMatrix\n            }\n            launcher.transform: Matrix4x4 {\n                matrix: launcherBg.deformMatrix\n            }\n"),
])

patch_file("modules/drawers/Regions.qml", [
    ("    R {\n        panel: root.panels.launcher\n        y: root.win.height - height\n        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness\n    }\n", "    R {\n        panel: root.panels.clipboard\n        y: root.win.height - height\n        height: panel.height * (1 - root.panels.clipboard.offsetScale) + root.borderThickness\n    }\n\n    R {\n        panel: root.panels.launcher\n        y: root.win.height - height\n        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness\n    }\n"),
])
PYEOF

echo "caelestia-clipboard installed in $CFG_DIR"
echo "Restart Quickshell to apply: pkill -x qs; qs -c caelestia -n -d &"
