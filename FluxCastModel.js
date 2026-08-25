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
  if (protocol === "chromecast") return "chromecast"
  return "wfd"
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
  if (value === "idle") return "󰁐"
  return "󰅚"
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

  var available = parsed.available !== undefined ? !!parsed.available : true
  if (parsed.ok === false || parsed.installed === false || parsed.ready === false) available = false
  if (missing.length > 0) available = false

  var message = normalizeText(parsed.message || parsed.error || parsed.summary || parsed.diagnostic)
  if (message === "" && !available) message = "FluxCast is not ready."

  var hint = normalizeText(parsed.hint || parsed.recovery || parsed.recommendation)
  if (hint === "" && !available) hint = missing.length > 0 ? "Install the missing dependency, then retry." : "Check the FluxCast log or reinstall FluxCast." 

  return {
    available: available,
    version: normalizeText(parsed.version || parsed.fluxcastVersion || ""),
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

function normalizeDevices(raw, exitCode, stderrText) {
  var parsed = parseDevicesPayload(raw)
  if (exitCode !== 0 && parsed.error === "") parsed.error = processFailureMessage("scan", exitCode, stderrText)
  if (exitCode !== 0 && parsed.hint === "") parsed.hint = recoveryHint("scan")
  return { devices: parsed.devices, raw: normalizeText(raw), error: parsed.error, hint: parsed.hint }
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

function normalizeMonitors(raw, exitCode, stderrText) {
  var parsed = parseMonitorsPayload(raw)
  if (exitCode !== 0 && parsed.error === "") parsed.error = processFailureMessage("monitors", exitCode, stderrText)
  if (exitCode !== 0 && parsed.hint === "") parsed.hint = recoveryHint("monitors")
  return { monitors: parsed.monitors, raw: normalizeText(raw), error: parsed.error, hint: parsed.hint }
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

function buildStartArgs(protocol, device, monitor, settings) {
  var args = ["fluxcast", "--start", "--protocol", normalizeProtocol(protocol)]
  var deviceKeyValue = deviceKey(device)
  var monitorKeyValue = monitorKey(monitor)
  if (deviceKeyValue !== "") {
    args.push("--device")
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
  if (normalizeProtocol(protocol) === "wfd" && backend !== "") {
    args.push("--wfd-capture-backend")
    args.push(backend)
  }

  if (normalizeProtocol(protocol) === "wfd" && settingBool(options["wfd-no-audio"], false)) args.push("--wfd-no-audio")
  if (normalizeText(options.profile) !== "") {
    args.push("--profile")
    args.push(normalizeText(options.profile))
  }

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
    stateLabel: stateLabel,
    barTooltip: barTooltip,
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
    buildStartArgs: buildStartArgs,
    processFailureMessage: processFailureMessage,
    recoveryHint: recoveryHint
  }
}
