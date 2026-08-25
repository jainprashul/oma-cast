function normalizeText(value) {
  if (value === undefined || value === null) return ""
  return String(value).trim()
}

function settingBool(value, fallback) {
  if (value === undefined || value === null || value === "") return !!fallback
  if (typeof value === "boolean") return value
  var text = String(value).trim().toLowerCase()
  return text === "1" || text === "true" || text === "yes" || text === "on"
}

function normalizeProtocol(value) {
  var protocol = normalizeText(value).toLowerCase()
  if (protocol === "miracast" || protocol === "wfd") return "wfd"
  if (protocol === "dlna") return "dlna"
  if (protocol === "chromecast" || protocol === "cast") return "chromecast"
  return "wfd"
}

function fluxcastProtocol(value) {
  var protocol = normalizeProtocol(value)
  if (protocol === "chromecast") return "cast"
  return protocol
}

function protocolLabel(value) {
  var protocol = normalizeProtocol(value)
  if (protocol === "dlna") return "DLNA"
  if (protocol === "chromecast") return "Chromecast"
  return "Miracast / WFD"
}

function iconForState(state) {
  var value = normalizeText(state)
  if (value === "casting") return "󰿎"
  if (value === "connecting") return "󰐊"
  if (value === "scanning") return "󰄬"
  if (value === "error") return "󰅙"
  if (value === "idle") return "󰄘"
  return "󰅚"
}

function barIconVisible(opened, displayState) {
  return true
}

function stateLabel(state) {
  var value = normalizeText(state)
  if (value === "casting") return "Casting"
  if (value === "connecting") return "Connecting"
  if (value === "scanning") return "Scanning"
  if (value === "error") return "Error"
  if (value === "idle") return "Idle"
  return "Unavailable"
}

function barTooltip(state, target, protocol, elapsedSeconds) {
  var label = stateLabel(state)
  if (normalizeText(state) === "casting") {
    var parts = [label, protocolLabel(protocol)]
    if (normalizeText(target) !== "") parts.push(normalizeText(target))
    parts.push(formatElapsed(elapsedSeconds))
    return parts.join(" · ")
  }
  if (normalizeText(state) === "error") return label
  return label + " · Open Oma Cast"
}

function isSessionReadyLine(line) {
  var text = normalizeText(line).toLowerCase()
  if (text === "") return false
  if (text.indexOf("play accepted") !== -1) return true
  if (text.indexOf("media stream started") !== -1) return true
  if (text.indexOf("casting started") !== -1) return true
  if (text.indexOf("output signal sent") !== -1) return true
  if (text.indexOf("hls source is producing segments") !== -1) return true
  return false
}

function resolveSessionState(input) {
  var options = input || {}
  var current = normalizeText(options.currentState) || "idle"
  var running = !!options.running || !!options.startInFlight
  var sessionReady = !!options.sessionReady
  var available = !!options.fluxcastAvailable
  var action = normalizeText(options.action) || "poll"
  var live = current === "casting" || current === "connecting" || running || sessionReady

  if (action === "exit") return options.errorState ? "error" : (available ? "idle" : "unavailable")

  if (live && (action === "scan" || action === "doctor-fail" || action === "monitor-error" || action === "poll")) {
    if (sessionReady || current === "casting") return "casting"
    return running || current === "connecting" || options.startInFlight ? "connecting" : current
  }

  if (action === "scan") return "scanning"
  if (options.errorState) return "error"
  if (!available) return "unavailable"
  return "idle"
}

function statusSummary(state, protocol, target, monitor, elapsedSeconds) {
  var parts = [stateLabel(state), protocolLabel(protocol)]
  if (normalizeText(target) !== "") parts.push(normalizeText(target))
  if (normalizeText(monitor) !== "") parts.push(normalizeText(monitor))
  if (normalizeText(state) === "casting") parts.push(formatElapsed(elapsedSeconds))
  return parts.join(" · ")
}

function formatElapsed(seconds) {
  var value = Math.max(0, Math.floor(Number(seconds) || 0))
  var hours = Math.floor(value / 3600)
  var minutes = Math.floor((value % 3600) / 60)
  var secs = value % 60
  function pad(n) { return n < 10 ? "0" + n : String(n) }
  if (hours > 0) return hours + ":" + pad(minutes) + ":" + pad(secs)
  return pad(minutes) + ":" + pad(secs)
}

function safeJson(raw) {
  var text = normalizeText(raw)
  if (text === "") return null
  try {
    return JSON.parse(text)
  } catch (e) {
    return null
  }
}

function arrayOf(value) {
  return Array.isArray(value) ? value : []
}

function deviceKey(device) {
  if (!device) return ""
  return normalizeText(device.selector || device.address || device.name || "")
}

function monitorKey(monitor) {
  if (!monitor) return ""
  return normalizeText(monitor.selector || monitor.address || monitor.name || "")
}

function deviceLabel(device) {
  if (!device) return "Unknown device"
  var name = normalizeText(device.name || device.label || device.displayName)
  if (name !== "") return name + (device.address ? "" : "")
  return normalizeText(device.address || device.selector || "Unknown device")
}

function deviceSubtitle(device) {
  if (!device) return ""
  var parts = []
  if (normalizeText(device.address) !== "") parts.push(normalizeText(device.address))
  if (normalizeText(device.protocol) !== "") parts.push(protocolLabel(device.protocol))
  return parts.join(" · ")
}

function monitorLabel(monitor) {
  if (!monitor) return "Unknown monitor"
  var name = normalizeText(monitor.name || monitor.selector || monitor.address)
  var description = normalizeText(monitor.description)
  var size = []
  if (Number(monitor.width) > 0 && Number(monitor.height) > 0) size.push(Number(monitor.width) + "x" + Number(monitor.height))
  var parts = []
  if (name !== "") parts.push(name)
  if (description !== "") parts.push(description)
  if (size.length > 0) parts.push(size.join(" "))
  return parts.join(" · ") || "Unknown monitor"
}

function deviceByKey(devices, key) {
  var list = arrayOf(devices)
  var wanted = normalizeText(key)
  if (wanted === "") return null
  for (var i = 0; i < list.length; i++) {
    if (deviceKey(list[i]) === wanted) return list[i]
  }
  return null
}

function monitorByKey(monitors, key) {
  var list = arrayOf(monitors)
  var wanted = normalizeText(key)
  if (wanted === "") return null
  for (var i = 0; i < list.length; i++) {
    if (monitorKey(list[i]) === wanted) return list[i]
  }
  return null
}

function parseDoctorPayload(raw) {
  var parsed = safeJson(raw)
  if (!parsed) return { available: false, version: "", message: "FluxCast did not return valid diagnostics.", missing: [], hint: "Run `fluxcast --doctor-json` in a terminal to inspect the failure." }

  var missing = []
  if (Array.isArray(parsed.missing)) missing = parsed.missing.slice()
  else if (Array.isArray(parsed.missingDependencies)) missing = parsed.missingDependencies.slice()
  else if (Array.isArray(parsed.dependenciesMissing)) missing = parsed.dependenciesMissing.slice()

  var checks = arrayOf(parsed.checks)
  var hasFail = false
  for (var i = 0; i < checks.length; i++) {
    var check = checks[i] || {}
    var status = normalizeText(check.status).toLowerCase()
    if (status === "fail") {
      hasFail = true
      missing.push(normalizeText(check.name || check.message || "dependency"))
    }
  }

  var available = parsed.available !== undefined ? !!parsed.available : !hasFail
  if (parsed.ok === false || parsed.installed === false || parsed.ready === false) available = false
  if (hasFail) available = false
  if (missing.length > 0 && hasFail) available = false

  var message = normalizeText(parsed.message || parsed.error || parsed.summary || parsed.diagnostic)
  if (message === "" && !available) message = "FluxCast is not ready."
  if (message === "" && parsed.wfd_candidate === false) message = normalizeText(parsed.summary || "Miracast/WFD is not confirmed yet.")

  var version = normalizeText(parsed.version || parsed.fluxcastVersion || "")
  if (version === "") {
    for (var j = 0; j < checks.length; j++) {
      var runtime = checks[j] || {}
      if (normalizeText(runtime.name).toLowerCase() === "python") {
        version = normalizeText(runtime.detail || runtime.message)
        break
      }
    }
  }

  var hint = normalizeText(parsed.hint || parsed.recovery || parsed.recommendation)
  if (hint === "" && !available) hint = missing.length > 0 ? "Install the missing dependency, then retry." : "Check the FluxCast log or reinstall FluxCast."
  if (hint === "" && parsed.wfd_candidate === false) hint = "Fix the warn/fail rows in doctor output, then retry scan."

  return {
    available: available,
    version: version,
    message: message,
    missing: missing,
    hint: hint
  }
}

function normalizeDoctor(raw, exitCode, stderrText) {
  var parsed = parseDoctorPayload(raw)
  if (exitCode !== 0 && parsed.message === "") parsed.message = processFailureMessage("doctor", exitCode, stderrText)
  if (exitCode !== 0 && parsed.hint === "") parsed.hint = recoveryHint("doctor")
  return parsed
}

function parseDevicesPayload(raw) {
  var parsed = safeJson(raw)
  if (!parsed) return { devices: [], error: "FluxCast scan output was not valid JSON.", hint: "Rescan or open the FluxCast log." }

  var values = arrayOf(parsed.devices || parsed.results || parsed.items || parsed.data)
  var protocol = normalizeProtocol(parsed.protocol || parsed.mode || "wfd")
  var devices = []

  for (var i = 0; i < values.length; i++) {
    var device = values[i] || {}
    var next = {
      name: normalizeText(device.name || device.label || device.displayName || device.title),
      address: normalizeText(device.address || device.mac || device.selector || ""),
      selector: normalizeText(device.selector || device.address || device.mac || device.name || ""),
      protocol: normalizeProtocol(device.protocol || protocol)
    }
    if (next.name === "") next.name = next.address !== "" ? next.address : "Unknown device"
    devices.push(next)
  }

  return {
    devices: devices,
    error: normalizeText(parsed.error || parsed.message || ""),
    hint: normalizeText(parsed.hint || "")
  }
}

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
    var tail = normalizeText(match[3]).replace(/\s+via\s+.*$/i, "")
    devices.push({
      name: tail !== "" ? tail : address,
      address: address,
      selector: index,
      protocol: "wfd"
    })
  }

  var error = ""
  var errorMatch = text.match(/ERROR:\s*(.+)/)
  if (errorMatch) error = normalizeText(errorMatch[1])

  return { devices: devices, error: error, hint: "" }
}

function normalizeDevices(raw, exitCode, stderrText) {
  var combined = normalizeText(raw)
  if (normalizeText(stderrText) !== "") combined = combined + "\n" + normalizeText(stderrText)

  var parsed = parseDevicesPayload(raw)
  if (parsed.devices.length > 0) {
    if (exitCode !== 0 && parsed.error === "") parsed.error = processFailureMessage("scan", exitCode, stderrText)
    if (exitCode !== 0 && parsed.hint === "") parsed.hint = recoveryHint("scan")
    return { devices: parsed.devices, raw: normalizeText(raw), error: parsed.error, hint: parsed.hint }
  }

  var scan = parseWfdScanOutput(combined)
  var error = scan.error
  if (exitCode !== 0 && error === "") error = processFailureMessage("scan", exitCode, stderrText)
  var hint = scan.hint
  if (exitCode !== 0 && hint === "") hint = recoveryHint("scan")
  if (exitCode === 0 && scan.devices.length === 0 && error === "") {
    error = "No Wi-Fi Direct peers found."
    hint = "Put the TV into Screen Share or Wireless Display mode, then scan again."
  }
  return { devices: scan.devices, raw: combined, error: error, hint: hint }
}

function parseMonitorsPayload(raw) {
  var parsed = safeJson(raw)
  if (!parsed) return { monitors: [], error: "FluxCast monitor output was not valid JSON.", hint: "Reconnect the monitor or retry refresh." }

  var values = arrayOf(parsed.monitors || parsed.displays || parsed.outputs || parsed.items || parsed.data)
  var monitors = []

  for (var i = 0; i < values.length; i++) {
    var monitor = values[i] || {}
    monitors.push({
      name: normalizeText(monitor.name || monitor.selector || monitor.address),
      selector: normalizeText(monitor.selector || monitor.name || monitor.address || ""),
      address: normalizeText(monitor.address || ""),
      description: normalizeText(monitor.description || monitor.label || ""),
      width: Number(monitor.width || monitor.w || 0),
      height: Number(monitor.height || monitor.h || 0)
    })
  }

  return {
    monitors: monitors,
    error: normalizeText(parsed.error || parsed.message || ""),
    hint: normalizeText(parsed.hint || "")
  }
}

function parseHyprctlMonitorsPayload(raw) {
  var parsed = safeJson(raw)
  if (!parsed || !Array.isArray(parsed)) {
    return {
      monitors: [],
      error: "Could not read monitors from hyprctl.",
      hint: "Make sure Hyprland is running, then refresh."
    }
  }

  var monitors = []
  for (var i = 0; i < parsed.length; i++) {
    var monitor = parsed[i] || {}
    monitors.push({
      name: normalizeText(monitor.name),
      selector: normalizeText(monitor.name),
      address: "",
      description: normalizeText(monitor.description),
      width: Number(monitor.width || 0),
      height: Number(monitor.height || 0)
    })
  }

  return { monitors: monitors, error: "", hint: "" }
}

function normalizeMonitors(raw, exitCode, stderrText) {
  var parsed = parseMonitorsPayload(raw)
  if (parsed.monitors.length > 0) {
    if (exitCode !== 0 && parsed.error === "") parsed.error = processFailureMessage("monitors", exitCode, stderrText)
    if (exitCode !== 0 && parsed.hint === "") parsed.hint = recoveryHint("monitors")
    return { monitors: parsed.monitors, raw: normalizeText(raw), error: parsed.error, hint: parsed.hint }
  }

  var hypr = parseHyprctlMonitorsPayload(raw)
  if (exitCode !== 0 && hypr.error === "") hypr.error = processFailureMessage("monitors", exitCode, stderrText)
  if (exitCode !== 0 && hypr.hint === "") hypr.hint = recoveryHint("monitors")
  return { monitors: hypr.monitors, raw: normalizeText(raw), error: hypr.error, hint: hypr.hint }
}

function parseStatusPayload(raw) {
  var parsed = safeJson(raw)
  if (!parsed) return { state: "idle", protocol: "wfd", target: "", monitor: "", pid: 0, startedAtMs: 0, elapsedSeconds: 0, error: "FluxCast status output was not valid JSON.", hint: "Retry refresh or inspect the log." }

  var state = normalizeText(parsed.state || parsed.status || "idle").toLowerCase()
  if (state === "running") state = "casting"
  if (state === "active") state = "casting"
  if (state !== "casting" && state !== "connecting" && state !== "scanning" && state !== "error" && state !== "idle") state = "idle"

  var startedAtMs = 0
  var startedAt = parsed.startedAt || parsed.started_at || parsed.started || parsed.startTime
  if (startedAt) {
    var asDate = new Date(startedAt)
    if (!isNaN(asDate.getTime())) startedAtMs = asDate.getTime()
  }

  return {
    state: state,
    protocol: normalizeProtocol(parsed.protocol || parsed.mode || "wfd"),
    target: normalizeText(parsed.target || parsed.device || parsed.deviceName || ""),
    monitor: normalizeText(parsed.monitor || parsed.output || parsed.display || ""),
    pid: Number(parsed.pid || 0) || 0,
    startedAtMs: startedAtMs,
    elapsedSeconds: Number(parsed.elapsedSeconds || parsed.elapsed || 0) || 0,
    error: normalizeText(parsed.error || parsed.message || ""),
    hint: normalizeText(parsed.hint || "")
  }
}

function normalizeStatus(raw, exitCode, stderrText) {
  var parsed = parseStatusPayload(raw)
  if (exitCode !== 0 && parsed.error === "") parsed.error = processFailureMessage("status", exitCode, stderrText)
  if (exitCode !== 0 && parsed.hint === "") parsed.hint = recoveryHint("status")
  return parsed
}

function elapsedSeconds(startedAt, fallbackSeconds) {
  var elapsed = Number(fallbackSeconds || 0)
  if (startedAt && startedAt.getTime && startedAt.getTime() > 0) {
    var diff = Math.floor((Date.now() - startedAt.getTime()) / 1000)
    if (isFinite(diff) && diff >= 0) elapsed = diff
  }
  return Math.max(0, Math.floor(elapsed))
}

function buildScanArgs(protocol, fluxcastBin) {
  var binary = normalizeText(fluxcastBin) || "fluxcast"
  if (normalizeProtocol(protocol) === "wfd") return [binary, "--wfd-scan"]
  return null
}

function buildStartArgs(protocol, device, monitor, settings, fluxcastBin) {
  var binary = normalizeText(fluxcastBin) || "fluxcast"
  var proto = fluxcastProtocol(protocol)
  var args = [binary, "--protocol", proto]
  var deviceKeyValue = deviceKey(device)
  var monitorKeyValue = monitorKey(monitor)

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

  var bitrate = normalizeText(options.bitrate)
  if (bitrate !== "") {
    args.push("--bitrate")
    args.push(bitrate)
  }

  var backend = normalizeText(options["wfd-capture-backend"])
  if (proto === "wfd" && backend !== "") {
    args.push("--wfd-capture-backend")
    args.push(backend)
  }

  if (proto === "wfd" && settingBool(options["wfd-no-audio"], false)) args.push("--wfd-no-audio")
  if (proto === "wfd" && settingBool(options["wfd-aosp-pmt-pid"], false)) args.push("--wfd-aosp-pmt-pid")

  return args
}

function processFailureMessage(operation, exitCode, stderrText) {
  var stderr = normalizeText(stderrText)
  if (stderr !== "") return "FluxCast " + operation + " failed: " + stderr
  return "FluxCast " + operation + " failed with exit code " + exitCode + "."
}

function recoveryHint(operation) {
  if (operation === "doctor") return "Check that FluxCast, wf-recorder, ffmpeg, and Wi-Fi Direct support are installed."
  if (operation === "scan") return "Make sure the Wi-Fi Direct adapter is available and retry scan."
  if (operation === "status") return "Refresh the panel or inspect the FluxCast log."
  if (operation === "stop") return "If FluxCast is still active, stop it from the tray or retry stop."
  return "Review the selected device and monitor, then try again."
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeText: normalizeText,
    settingBool: settingBool,
    normalizeProtocol: normalizeProtocol,
    protocolLabel: protocolLabel,
    iconForState: iconForState,
    barIconVisible: barIconVisible,
    stateLabel: stateLabel,
    barTooltip: barTooltip,
    isSessionReadyLine: isSessionReadyLine,
    resolveSessionState: resolveSessionState,
    statusSummary: statusSummary,
    formatElapsed: formatElapsed,
    safeJson: safeJson,
    deviceKey: deviceKey,
    monitorKey: monitorKey,
    deviceLabel: deviceLabel,
    deviceSubtitle: deviceSubtitle,
    monitorLabel: monitorLabel,
    deviceByKey: deviceByKey,
    monitorByKey: monitorByKey,
    normalizeDoctor: normalizeDoctor,
    normalizeDevices: normalizeDevices,
    normalizeMonitors: normalizeMonitors,
    normalizeStatus: normalizeStatus,
    elapsedSeconds: elapsedSeconds,
    fluxcastProtocol: fluxcastProtocol,
    buildScanArgs: buildScanArgs,
    buildStartArgs: buildStartArgs,
    parseWfdScanOutput: parseWfdScanOutput,
    parseHyprctlMonitorsPayload: parseHyprctlMonitorsPayload,
    processFailureMessage: processFailureMessage,
    recoveryHint: recoveryHint
  }
}
