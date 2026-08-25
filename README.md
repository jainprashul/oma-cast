# Oma Cast

Oma Cast is an Omarchy `bar-widget` plugin for controlling FluxCast screen mirroring.

## Dependency

- `fluxcast`

## Plugin contract

- `oma-cast.toggle`
- `oma-cast.open`
- `oma-cast.close`
- `oma-cast.scan`
- `oma-cast.start`
- `oma-cast.stop`
- `oma-cast.refresh`

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
