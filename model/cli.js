// Build argv arrays for FluxCast scan and start subprocesses.
var Text = require("./text.js")
var Protocol = require("./protocol.js")
var Entities = require("./entities.js")

function resolveFluxcastBin(fluxcastBin) {
  return Text.normalizeText(fluxcastBin) || "fluxcast"
}

// Only WFD exposes a CLI scan today; DLNA/Chromecast use the FluxCast tray.
function buildScanArgs(protocol, fluxcastBin) {
  var binary = resolveFluxcastBin(fluxcastBin)
  if (Protocol.normalizeProtocol(protocol) === "wfd") return [binary, "--wfd-scan"]
  return null
}

function buildStartArgs(protocol, device, monitor, settings, fluxcastBin) {
  var binary = resolveFluxcastBin(fluxcastBin)
  var proto = Protocol.fluxcastProtocol(protocol)
  var args = [binary, "--protocol", proto]
  var deviceKeyValue = Entities.deviceKey(device)
  var monitorKeyValue = Entities.monitorKey(monitor)

  // WFD peers are indexed by scan slot; other protocols match by device name.
  if (proto === "wfd") {
    if (deviceKeyValue !== "") {
      args.push("--wfd-peer")
      args.push(deviceKeyValue)
    }
  } else if (deviceKeyValue !== "") {
    args.push("--device-name")
    args.push(deviceKeyValue)
  }

  if (monitorKeyValue !== "") {
    args.push("--monitor")
    args.push(monitorKeyValue)
  }

  var options = settings || {}
  var fps = Number(options.fps || 0)
  if (isFinite(fps) && fps > 0) {
    args.push("--fps")
    args.push(String(Math.round(fps)))
  }

  var bitrate = Text.normalizeText(options.bitrate)
  if (bitrate !== "") {
    args.push("--bitrate")
    args.push(bitrate)
  }

  var backend = Text.normalizeText(options["wfd-capture-backend"])
  if (proto === "wfd" && backend !== "") {
    args.push("--wfd-capture-backend")
    args.push(backend)
  }

  if (proto === "wfd" && Text.settingBool(options["wfd-no-audio"], false)) args.push("--wfd-no-audio")
  if (proto === "wfd" && Text.settingBool(options["wfd-aosp-pmt-pid"], false)) args.push("--wfd-aosp-pmt-pid")

  return args
}

module.exports = {
  buildScanArgs: buildScanArgs,
  buildStartArgs: buildStartArgs
}
