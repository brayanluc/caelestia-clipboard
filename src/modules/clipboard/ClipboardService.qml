pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    signal itemDeleting(string id)

    property var entries: []
    property int thumbRevision: 0
    property bool autoPaste: false
    property int maxHistory: 100
    property int lastFiniteLimit: 100
    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/caelestia-clipboard`
    readonly property string configPath: `${Quickshell.env("HOME")}/.config/caelestia/clipboard.json`

    function saveSettings(): void {
        const payload = JSON.stringify({
            autoPaste: root.autoPaste,
            maxHistory: root.maxHistory,
            lastFiniteLimit: root.lastFiniteLimit
        }, null, 2);
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\n" "$2" > "$1"', "sh", root.configPath, payload]);
    }

    function toggleAutoPaste(): void {
        root.autoPaste = !root.autoPaste;
        root.saveSettings();
    }

    function setMaxHistory(limit: int): void {
        const clamped = limit <= 0 ? 0 : Math.max(25, Math.min(250, Math.round(limit / 5) * 5));
        if (clamped > 0)
            root.lastFiniteLimit = clamped;
        if (root.maxHistory === clamped)
            return;
        root.maxHistory = clamped;
        root.saveSettings();
        root.reload();
    }

    function toggleUnlimited(): void {
        if (root.maxHistory === 0)
            root.setMaxHistory(root.lastFiniteLimit >= 25 ? root.lastFiniteLimit : 100);
        else
            root.setMaxHistory(0);
    }

    function reload(): void {
        listProc.running = false;
        listProc.running = true;
    }

    function filter(query: string): var {
        const q = query.trim().toLowerCase();
        if (!q)
            return entries;
        return entries.filter(e => {
            if (e.displayText.toLowerCase().includes(q))
                return true;
            if (e.isImage && (`image ${e.ext} ${e.dimensions} ${e.size}`).toLowerCase().includes(q))
                return true;
            return false;
        });
    }

    function copyItem(item): void {
        if (!item)
            return;
        if (root.autoPaste) {
            Quickshell.execDetached([
                "sh", "-c",
                "cliphist decode \"$1\" | wl-copy && sleep 0.07 && cls=$(hyprctl activewindow -j 2>/dev/null | grep -i '\"class\":' | tr '[:upper:]' '[:lower:]'); case \"$cls\" in *kitty*|*ghostty*|*alacritty*|*foot*|*wezterm*|*konsole*) hyprctl dispatch 'hl.dsp.send_shortcut({ mods = \"CTRL SHIFT\", key = \"v\" })' >/dev/null 2>&1 || hyprctl dispatch sendshortcut \"CTRL SHIFT, v,\" >/dev/null 2>&1 ;; *) hyprctl dispatch 'hl.dsp.send_shortcut({ mods = \"CTRL\", key = \"v\" })' >/dev/null 2>&1 || hyprctl dispatch sendshortcut \"CTRL, v,\" >/dev/null 2>&1 ;; esac",
                "sh", item.id
            ]);
        } else {
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", item.id]);
        }
    }

    function deleteItem(item): void {
        if (!item)
            return;
        root.itemDeleting(item.id);
        delProc.command = ["sh", "-c", 'printf "%s\n" "$1" | cliphist delete && rm -f "$HOME/.cache/caelestia-clipboard/$2".*', "sh", item.rawLine, item.id];
        delProc.running = false;
        delProc.running = true;
    }

    function wipeAll(): void {
        wipeProc.running = false;
        wipeProc.running = true;
    }

    Process {
        id: loadProc

        command: ["sh", "-c", 'cat "$HOME/.config/caelestia/clipboard.json" 2>/dev/null || true']
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (raw.length > 0) {
                    try {
                        const cfg = JSON.parse(raw);
                        if (typeof cfg.autoPaste === "boolean")
                            root.autoPaste = cfg.autoPaste;
                        if (typeof cfg.lastFiniteLimit === "number" && cfg.lastFiniteLimit >= 25)
                            root.lastFiniteLimit = Math.min(250, Math.floor(cfg.lastFiniteLimit));
                        if (typeof cfg.maxHistory === "number" && cfg.maxHistory >= 0) {
                            root.maxHistory = Math.floor(cfg.maxHistory);
                            if (root.maxHistory > 0)
                                root.lastFiniteLimit = root.maxHistory;
                        }
                    } catch (e) {}
                }
                root.reload();
            }
        }
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0);
                let parsed = [];
                const imgRe = /^\[\[ binary data (.*?) (png|jpg|jpeg|webp|bmp|gif) (.*?) \]\]$/i;
                for (const line of lines) {
                    const tabIdx = line.indexOf("\t");
                    if (tabIdx === -1)
                        continue;
                    const id = line.slice(0, tabIdx);
                    const content = line.slice(tabIdx + 1);
                    const m = content.match(imgRe);
                    if (m) {
                        const size = m[1];
                        const ext = m[2].toLowerCase();
                        const dimensions = m[3];
                        parsed.push({
                            id: id,
                            rawLine: line,
                            isImage: true,
                            size: size,
                            ext: ext,
                            dimensions: dimensions,
                            displayText: `Image (${dimensions} • ${size})`,
                            thumbPath: `${root.cacheDir}/${id}.${ext}`,
                            isUrl: false,
                            isHexColor: false
                        });
                    } else {
                        const trimmed = content.trim();
                        parsed.push({
                            id: id,
                            rawLine: line,
                            isImage: false,
                            size: "",
                            ext: "",
                            dimensions: "",
                            displayText: content,
                            thumbPath: "",
                            isUrl: /^https?:\/\/\S+$/.test(trimmed),
                            isHexColor: /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(trimmed)
                        });
                    }
                }
                if (root.maxHistory > 0 && parsed.length > root.maxHistory) {
                    const kept = parsed.slice(0, root.maxHistory);
                    const overflow = parsed.slice(root.maxHistory);
                    const overflowLines = overflow.map(e => e.rawLine).join("\n");
                    const overflowIds = overflow.map(e => e.id);
                    trimProc.command = [
                        "sh", "-c",
                        'printf "%s\n" "$1" | cliphist delete >/dev/null 2>&1; shift; dir="$HOME/.cache/caelestia-clipboard"; for id in "$@"; do rm -f "$dir/$id".*; done',
                        "sh", overflowLines, ...overflowIds
                    ];
                    trimProc.running = false;
                    trimProc.running = true;
                    parsed = kept;
                }
                root.entries = parsed;
                const missingSpecs = parsed.filter(e => e.isImage).map(e => `${e.id}:${e.ext}`);
                if (missingSpecs.length > 0) {
                    thumbProc.command = ["sh", "-c", 'dir="$HOME/.cache/caelestia-clipboard"; mkdir -p "$dir"; for item in "$@"; do id="${item%%:*}"; ext="${item#*:}"; out="$dir/$id.$ext"; [ -s "$out" ] || cliphist decode "$id" > "$out" 2>/dev/null; done', "sh", ...missingSpecs];
                    thumbProc.running = false;
                    thumbProc.running = true;
                }
            }
        }
    }

    Process {
        id: trimProc
    }

    Process {
        id: thumbProc
        onExited: root.thumbRevision++
    }

    Process {
        id: delProc
        onExited: root.reload()
    }

    Process {
        id: wipeProc
        command: ["sh", "-c", 'cliphist wipe && rm -rf "$HOME/.cache/caelestia-clipboard"/*']
        onExited: root.reload()
    }

    Component.onCompleted: {
        loadProc.running = true;
    }
}
