# caelestia-clipboard

Native QML clipboard history drawer for **Caelestia Shell** (Quickshell + Hyprland), powered by `cliphist`.

## Preview

<img width="1252" height="969" alt="caelestia-clipboard-03" src="https://github.com/user-attachments/assets/99abec03-14d5-4404-a495-0cf06f08db99" /> <img width="1251" height="969" alt="caelestia-clipboard-04" src="https://github.com/user-attachments/assets/25f84cee-af04-4609-b7bb-7533a8fb4a21" /> <img width="1254" height="970" alt="caelestia-clipboard-05" src="https://github.com/user-attachments/assets/8ce006f7-2c83-477c-aa3a-b82d25cf7969" />


## Features

- **100% Native Look & Feel:** Uses Caelestia `BlobGroup` concave borders, elastic deformation, `SearchBar`, ripple effects, and real-time Material You dynamic palette.
- **Smart Image Preview:** Renders async thumbnails in the list and smoothly expands a large preview card above the list only when an image entry is highlighted.
- **Auto-Paste Toggle:** One-click pill toggle in the bottom bar to automatically paste (`Ctrl+V` / `Ctrl+Shift+V`) right after selecting an entry.
- **Configurable History Limit:** Built-in history cap selector (`25`, `50`, `100`, `250`, or unlimited `∞`) that automatically prunes older entries.
- **Rich Entry Types:** Automatically detects images (with ID, resolution, and file size), URLs, hex colors (with live color swatch), and plain text.
- **Non-Destructive Overlay:** Installs into `~/.config/quickshell/caelestia` using symlinks to `/etc/xdg/quickshell/caelestia`, keeping system updates safe.

## Requirements

- [caelestia-shell](https://github.com/caelestia-dots/shell)
- `cliphist` (with `wl-paste --watch cliphist store` running in your Hyprland autostart)
- `wl-clipboard` (`wl-copy`)
- `python3`

## Installation

### Quick Install (One-Liner)

Installs the QML overlay into `~/.config/quickshell/caelestia/`, checks dependencies, and configures `SUPER + V` if free (without leaving a cloned repository on disk):

```bash
git clone --depth 1 [https://github.com/brayanluc/caelestia-clipboard.git](https://github.com/brayanluc/caelestia-clipboard.git) /tmp/caelestia-clipboard && /tmp/caelestia-clipboard/install.sh && rm -rf /tmp/caelestia-clipboard
```

Restart Quickshell to apply:

```bash
pkill -x qs; qs -c caelestia -n -d &
```

### Arch / CachyOS Package (`makepkg`)

Install as a `pacman`-managed package with a `systemd --user` setup service and a `pacman` hook that keeps the overlay intact across `caelestia-shell` updates:

```bash
git clone --depth 1 [https://github.com/brayanluc/caelestia-clipboard.git](https://github.com/brayanluc/caelestia-clipboard.git) /tmp/caelestia-clipboard
cd /tmp/caelestia-clipboard/aur
makepkg -si
rm -rf /tmp/caelestia-clipboard
```

> **Note:** `aur/PKGBUILD` is ready to publish as `caelestia-clipboard-git` once AUR new account registration reopens.

## Keybind Setup (Hyprland)

Trigger the drawer via Caelestia IPC:

```bash
caelestia shell drawers toggle clipboard
```

Example for `~/.config/caelestia/hypr-user.lua` (if `SUPER + V` is already in use, prepend `pcall(hl.unbind, "SUPER + V")`):

```lua
hl.bind("SUPER + V", hl.dsp.exec_cmd("caelestia shell drawers toggle clipboard"))
```

## Controls Inside the Drawer

- `Up` / `Down` / `Tab` / `Ctrl+J` / `Ctrl+K`: Navigate entries
- `Enter` or Click: Copy selected entry (and auto-paste if toggled on)
- `Delete` or `Ctrl+D`: Delete selected entry from history
- `Esc` or Click Outside: Close drawer

## Uninstall

If installed via the quick install script:

```bash
git clone --depth 1 [https://github.com/brayanluc/caelestia-clipboard.git](https://github.com/brayanluc/caelestia-clipboard.git) /tmp/caelestia-clipboard && /tmp/caelestia-clipboard/uninstall.sh && rm -rf /tmp/caelestia-clipboard
pkill -x qs; qs -c caelestia -n -d &
```

If installed via `makepkg`:

```bash
sudo pacman -Rns caelestia-clipboard-git
rm -rf ~/.config/quickshell/caelestia
pkill -x qs; qs -c caelestia -n -d &
```
