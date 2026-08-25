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
| `log-file` | path | `/tmp/fluxcast-cast.log` (FluxCast session log) |
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

## 🏗️ Build

Shared logic lives in `model/*.js` (Node modules). QML imports a single generated library:

| Source | Generated | Used by |
|---|---|---|
| `model/*.js` | `model/qml-bundle.js` | QML `.pragma library` |
| `FluxCastModel.node.js` + bundle | `FluxCastModel.js` | `Panel.qml`, `BarWidget.qml` |

Regenerate after editing any file under `model/`:

```bash
node scripts/build-qml-model.cjs
```

Run the model tests (no build required — tests load `FluxCastModel.node.js` directly):

```bash
node FluxCastModel.test.js
```

`FluxCastModel.js` and `model/qml-bundle.js` are gitignored (edit `model/*.js` only). Run the build before validate or rsync. To publish, force-add the generated files so `omarchy plugin add` gets a complete tree:

```bash
git add -f FluxCastModel.js model/qml-bundle.js
```

---

## 🛠️ Maintainer notes (publishing)

Omarchy has **no plugin registry**. Publishing is: a public git repo with `manifest.json` at the root. Users clone default-branch **HEAD**; they do not install from tags or GitHub Releases.

```bash
omarchy plugin add https://github.com/jainprashul/oma-cast --enable
```

That clones into `~/.config/omarchy/plugins/io.github.jainprashul.omacast/`. Updates are a **fast-forward-only** pull of `origin HEAD`:

```bash
omarchy plugin update io.github.jainprashul.omacast
```

### Before every push to `master`

1. **Keep `manifest.json` at the repo root.** Required: `schemaVersion` (JSON number `1`, not `"1"`), `id`, `name`, `version`, `kinds`, `entryPoints`.
2. **Never change `id`** (`io.github.jainprashul.omacast`) after people have installed it. A new id is a different plugin; they must `plugin remove` then `plugin add` again.
3. **Bump `version`** in `manifest.json` for each published change. The installer ignores it; it is for humans and `omarchy plugin list`.
4. **Build** generated QML artifacts (see [Build](#-build)):
   ```bash
   node scripts/build-qml-model.cjs
   node FluxCastModel.test.js
   ```
5. **Validate** (same checks `plugin add` / `plugin update` run; they refuse or roll back on failure):
   ```bash
   omarchy plugin validate .
   ```
6. **Keep `master` public and cloneable without credentials.** The add/update CLIs set `GIT_TERMINAL_PROMPT=0`. HTTPS URL: `https://github.com/jainprashul/oma-cast` (`.git` suffix optional; `https` / `ssh` / `git` only).
7. **No symlinks** anywhere in the tree (validation rejects them). **Do not force-push or rewrite `master`** — installed checkouts cannot fast-forward past that.

Do not bundle FluxCast. Keep it as an external CLI dependency; README install instructions must stay accurate for the tested FluxCast version.

### Ship a version

```bash
# 1. Bump "version" in manifest.json
# 2. Update README if user-facing behavior or FluxCast version changed
node scripts/build-qml-model.cjs
node FluxCastModel.test.js
omarchy plugin validate .
git add manifest.json README.md
git add -f FluxCastModel.js model/qml-bundle.js
git commit -m "Release 0.x.y: <why>"
git push origin master
```

GitHub Releases/tags are optional (changelog for humans only). Installed users still get whatever is on `master` HEAD.

### Local test without publishing

Develop in this checkout, then copy into the install dir — **do not symlink** (forbidden):

```bash
node scripts/build-qml-model.cjs
rsync -a --delete --exclude .git ./ ~/.config/omarchy/plugins/io.github.jainprashul.omacast/
omarchy-shell shell rescanPlugins
```

Saves under `~/.config/omarchy/plugins/` hot-reload. Force a rescan if the widget does not pick up changes.

---

## 📜 License
MIT © 2026 Prashul Jain. See [LICENSE](LICENSE).
