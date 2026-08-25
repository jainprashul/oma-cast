# 📡 Oma Cast — Omarchy Status Bar Plugin

[![Omarchy Plugin](https://img.shields.io/badge/Omarchy-Plugin-blue)](https://omarchy.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![FluxCast](https://img.shields.io/badge/FluxCast-v0.2.3-green)](https://github.com/IlyaP358/fluxcast)

**Oma Cast** (`io.github.jainprashul.omacast`) is a bar widget and popup panel for **Omarchy Linux** and **Hyprland**. It controls [FluxCast](https://github.com/IlyaP358/fluxcast) from the status bar so you can scan nearby TVs, pick a monitor, and start or stop screen mirroring in one click.

---

## ✨ Features

* **📡 1-Click Screen Mirroring:** Scan receivers, choose a protocol, pick a Hyprland output, and start casting from a compact bar popup.
* **📺 Multi-Protocol Support:**
  * **Miracast / Wi-Fi Direct (WFD):** Native scan and start from the panel (primary path).
  * **DLNA:** Fallback for TVs that prefer UPnP playback.
  * **Chromecast:** Experimental Cast path via FluxCast (`--protocol cast`).
* **🖥️ Hardware-Aware Monitor Picker:** Reads live outputs from `hyprctl monitors -j` and remembers the last selected screen.
* **🔔 Live Session Status:** Connecting / casting states, elapsed time, desktop notifications, and a 1-click stop action.
* **🩺 FluxCast Diagnostics:** Runs `fluxcast --doctor-json` on open/refresh, surfaces missing dependencies, and can fall back to the FluxCast tray.
* **🪟 Hyprland + Omarchy IPC:** Bar clicks plus `oma-cast.*` IPC handlers for toggle, scan, start, stop, and refresh.

---

## 📦 Prerequisites

1. **FluxCast** (tested with v0.2.3), installed as `~/.local/bin/fluxcast`:
   ```bash
   # Arch / Omarchy (AUR)
   yay -S fluxcast-git

   # or PyPI
   pip install fluxcast
   sudo fluxcast-install-system
   ```
   Confirm it is on PATH:
   ```bash
   fluxcast --doctor-json
   ```

2. **Hyprland capture tools** (for Miracast on Omarchy / wlroots):
   ```bash
   sudo pacman -S wf-recorder ffmpeg
   ```

3. **Firewall (optional):**
   If a firewall is active, allow the Miracast RTSP port (7236/tcp):
   ```bash
   # UFW
   sudo ufw allow 7236/tcp comment 'Miracast-RTSP'

   # firewalld (FluxCast can also open this for the session automatically)
   sudo firewall-cmd --add-port=7236/tcp
   ```

DLNA and Chromecast discovery still require **Launch tray** (`fluxcast --tray`) because FluxCast does not expose scan JSON for those protocols yet.

---

## 🚀 Installation & Removal

### Installation via Omarchy CLI
```bash
omarchy plugin add https://github.com/jainprashul/oma-cast --enable
```

### Removal
```bash
omarchy plugin remove io.github.jainprashul.omacast --yes
```

---

## 🖱️ Bar & IPC

| Input | Action |
|---|---|
| Left click | Toggle the panel |
| Right click | Stop if casting, otherwise toggle |
| Middle click | Refresh diagnostics and monitors |

IPC contract (`IpcHandler` target `oma-cast`):

* `oma-cast.toggle`
* `oma-cast.open`
* `oma-cast.close`
* `oma-cast.scan`
* `oma-cast.start`
* `oma-cast.stop`
* `oma-cast.refresh`
* `oma-cast.status`

---

## ⚙️ Config

Optional inline settings in `shell.json` or the plugin entry:

| Key | Values | Default |
|---|---|---|
| `protocol` | `wfd`, `dlna`, `chromecast` | `wfd` |
| `monitor` | Hyprland output name, e.g. `eDP-1` | last selected |
| `scan-on-open` | `true` / `false` | `true` |
| `show-notifications` | `true` / `false` | `true` |
| `launch-tray-fallback` | `true` / `false` | `true` |
| `log-file` | path | `~/.local/state/fluxcast/fluxcast.log` |
| `fps` | number | FluxCast default |
| `bitrate` | e.g. `4M` | FluxCast default |
| `wfd-capture-backend` | `auto`, `portal`, `wf-recorder`, `x11grab`, `gst-x11` | FluxCast default |
| `wfd-no-audio` | `true` / `false` | `false` |
| `wfd-aosp-pmt-pid` | `true` / `false` | `false` |

---

## 🔌 FluxCast integration

This plugin targets the **installed FluxCast CLI**, not a hypothetical JSON control API. FluxCast is an external dependency and is not bundled here. All commands use argv arrays, not shell interpolation.

| Action | Command |
|---|---|
| Doctor | `fluxcast --doctor-json` |
| Scan (WFD) | `fluxcast --wfd-scan` |
| Monitors | `hyprctl monitors -j` |
| Start | long-running `fluxcast --protocol …` |
| Stop | terminate the session process started by oma-cast |
| Status | tracked locally from the oma-cast session process |

---

## 📜 License
MIT © 2026 Prashul Jain. See [LICENSE](LICENSE).
