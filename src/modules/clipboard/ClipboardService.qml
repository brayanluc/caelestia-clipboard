pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var entries: []
    property int thumbRevision: 0
    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/caelestia-clipboard`

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
            if (e.isImage && (`imagem ${e.ext} ${e.dimensions} ${e.size}`).toLowerCase().includes(q))
                return true;
            return false;
        });
    }

    function copyItem(item): void {
        if (!item)
            return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", item.id]);
    }

    function deleteItem(item): void {
        if (!item)
            return;
        delProc.command = ["sh", "-c", 'printf "%s\n" "$1" | cliphist delete && rm -f "$HOME/.cache/caelestia-clipboard/$2".*', "sh", item.rawLine, item.id];
        delProc.running = false;
        delProc.running = true;
    }

    function wipeAll(): void {
        wipeProc.running = false;
        wipeProc.running = true;
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0);
                const parsed = [];
                const missingSpecs = [];
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
                            displayText: `Imagem (${dimensions} • ${size})`,
                            thumbPath: `${root.cacheDir}/${id}.${ext}`,
                            isUrl: false,
                            isHexColor: false
                        });
                        missingSpecs.push(`${id}:${ext}`);
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
                root.entries = parsed;
                if (missingSpecs.length > 0) {
                    thumbProc.command = ["sh", "-c", 'dir="$HOME/.cache/caelestia-clipboard"; mkdir -p "$dir"; for item in "$@"; do id="${item%%:*}"; ext="${item#*:}"; out="$dir/$id.$ext"; [ -s "$out" ] || cliphist decode "$id" > "$out" 2>/dev/null; done', "sh", ...missingSpecs];
                    thumbProc.running = false;
                    thumbProc.running = true;
                }
            }
        }
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

    Component.onCompleted: reload()
}
