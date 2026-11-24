# caelestia-clipboard

Native QML clipboard history drawer for **Caelestia Shell** (Quickshell + Hyprland), powered by `cliphist`.

## Features

- **100% Native Look & Feel:** Uses Caelestia `BlobGroup` concave borders, elastic deformation, `SearchBar`, ripple effects, and real-time Material You dynamic palette.
- **Smart Image Preview:** Renders async thumbnails in the list and smoothly expands a large preview card above the list only when an image entry is highlighted.
- **Auto-Paste Toggle:** One-click pill toggle in the bottom bar to automatically paste (`Ctrl+V`) right after selecting an entry.
- **Configurable History Limit:** Built-in history cap selector (`25`, `50`, `100`, `250`, or unlimited `∞`) that automatically prunes older entries.
- **Rich Entry Types:** Automatically detects images (with ID, resolution, and file size), URLs, hex colors (with live color swatch), and plain text.
- **Non-Destructive Overlay:** Installs into `~/.config/quickshell/caelestia` using symlinks to `/etc/xdg/quickshell/caelestia`, keeping system updates safe.

## Requirements

- [caelestia-shell](https://github.com/caelestia-dots/shell)
- `cliphist` (with `wl-paste --watch cliphist store` running in your Hyprland autostart)
- `wl-clipboard` (`wl-copy`)
- `python3`

## Installation

```bash
git clone [https://github.com/brayanluc/caelestia-clipboard.git](https://github.com/brayanluc/caelestia-clipboard.git)
cd caelestia-clipboard
./install.sh
```

Restart Quickshell after installing (and re-run `./install.sh` whenever `caelestia-shell` receives a system update):

```bash
pkill -x qs; qs -c caelestia -n -d &
```

## Keybind Setup (Hyprland)

Trigger the drawer via Caelestia IPC:

```bash
caelestia shell drawers toggle clipboard
```

Example for `~/.config/caelestia/hypr-user.lua`:

```lua
hl.bind({ "SUPER" }, "V", "exec", "caelestia shell drawers toggle clipboard")
```

## Controls Inside the Drawer

- `Up` / `Down` / `Tab` / `Ctrl+J` / `Ctrl+K`: Navigate entries
- `Enter` or Click: Copy selected entry (and auto-paste if toggled on)
- `Delete` or `Ctrl+D`: Delete selected entry from history
- `Esc` or Click Outside: Close drawer

## Uninstall

```bash
./uninstall.sh
pkill -x qs; qs -c caelestia -n -d &
```
