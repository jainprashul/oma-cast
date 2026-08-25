// Normalize FluxCast scan output: JSON when available, WFD text scan as fallback.
var Text = require("./text.js")
var Protocol = require("./protocol.js")
var Errors = require("./errors.js")

function parseDevicesPayload(raw) {
  var parsed = Text.safeJson(raw)
  if (!parsed) return { devices: [], error: "FluxCast scan output was not valid JSON.", hint: "Rescan or open the FluxCast log." }

  var values = Text.arrayOf(parsed.devices || parsed.results || parsed.items || parsed.data)
  var protocol = Protocol.normalizeProtocol(parsed.protocol || parsed.mode || "wfd")
  var devices = []

  for (var i = 0; i < values.length; i++) {
    var device = values[i] || {}
    var next = {
      name: Text.normalizeText(device.name || device.label || device.displayName || device.title),
      address: Text.normalizeText(device.address || device.mac || device.selector || ""),
      selector: Text.normalizeText(device.selector || device.address || device.mac || device.name || ""),
      protocol: Protocol.normalizeProtocol(device.protocol || protocol)
    }
    if (next.name === "") next.name = next.address !== "" ? next.address : "Unknown device"
    devices.push(next)
  }

  return {
    devices: devices,
    error: Text.normalizeText(parsed.error || parsed.message || ""),
    hint: Text.normalizeText(parsed.hint || "")
  }
}

// Parse `fluxcast --wfd-scan` plain-text lines: `[0] aa:bb:cc:dd:ee:ff Name`.
function parseWfdScanOutput(raw) {
  var text = String(raw || "")
  var devices = []
  var lines = text.split(/\r?\n/)
  var peerRe = /^\s*\[(\d+)\]\s+([0-9a-fA-F:]{17})(.*)$/

  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(peerRe)
    if (!match) continue
    var index = match[1]
    var address = match[2]
    var tail = Text.normalizeText(match[3]).replace(/\s+via\s+.*$/i, "")
    devices.push({
      name: tail !== "" ? tail : address,
      address: address,
      selector: index,
      protocol: "wfd"
    })
  }

  var error = ""
  var errorMatch = text.match(/ERROR:\s*(.+)/)
  if (errorMatch) error = Text.normalizeText(errorMatch[1])

  return { devices: devices, error: error, hint: "" }
}

// Try JSON first; if empty, parse WFD text and apply scan-specific empty-state hints.
function normalizeDevices(raw, exitCode, stderrText) {
  var stderr = Text.normalizeText(stderrText)
  var combined = Text.normalizeText(raw)
  if (stderr !== "") combined = combined + "\n" + stderr

  var parsed = parseDevicesPayload(raw)
  if (parsed.devices.length > 0) {
    return Errors.applyExitCode({
      devices: parsed.devices,
      raw: Text.normalizeText(raw),
      error: parsed.error,
      hint: parsed.hint
    }, "scan", exitCode, stderrText, "error")
  }

  var scan = parseWfdScanOutput(combined)
  var error = scan.error
  if (exitCode !== 0 && error === "") error = Errors.processFailureMessage("scan", exitCode, stderrText)
  var hint = scan.hint
  if (exitCode !== 0 && hint === "") hint = Errors.recoveryHint("scan")
  if (exitCode === 0 && scan.devices.length === 0 && error === "") {
    error = "No Wi-Fi Direct peers found."
    hint = "Put the TV into Screen Share or Wireless Display mode, then scan again."
  }
  return { devices: scan.devices, raw: combined, error: error, hint: hint }
}

module.exports = {
  parseDevicesPayload: parseDevicesPayload,
  parseWfdScanOutput: parseWfdScanOutput,
  normalizeDevices: normalizeDevices
}
