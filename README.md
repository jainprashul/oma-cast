# Oma Cast

Oma Cast is an Omarchy `bar-widget` plugin for controlling FluxCast screen mirroring.

## Dependency

- `fluxcast` (tested with v0.2.3)

## Plugin contract

- `oma-cast.toggle`
- `oma-cast.open`
- `oma-cast.close`
- `oma-cast.scan`
- `oma-cast.start`
- `oma-cast.stop`
- `oma-cast.refresh`

## FluxCast integration

This plugin targets the **installed FluxCast CLI**, not a hypothetical JSON control API.

| Action | Command |
|---|---|
| Doctor | `fluxcast --doctor-json` |
| Scan (WFD) | `fluxcast --wfd-scan` |
| Monitors | `hyprctl monitors -j` |
| Start | long-running `fluxcast --protocol …` |
| Stop | terminate the session process started by oma-cast |
| Status | tracked locally from the oma-cast session process |

DLNA and Chromecast discovery still require **Launch tray** (`fluxcast --tray`) because FluxCast does not expose scan JSON for those protocols yet.

## Config

Optional inline settings in `shell.json` or the plugin entry:

- `protocol`: `wfd`, `dlna`, or `chromecast`
- `monitor`: last selected monitor selector
- `scan-on-open`: `true` or `false`
- `show-notifications`: `true` or `false`
- `launch-tray-fallback`: `true` or `false`
- `log-file`: FluxCast log path

## Notes

- FluxCast is treated as an external dependency and is not bundled here.
- All FluxCast commands use argv arrays, not shell interpolation.
