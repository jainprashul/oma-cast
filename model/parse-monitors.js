// Normalize monitor lists from FluxCast JSON or `hyprctl monitors -j`.
var Text = require("./text.js")
var Errors = require("./errors.js")

function parseMonitorsPayload(raw) {
  var parsed = Text.safeJson(raw)
  if (!parsed) return { monitors: [], error: "FluxCast monitor output was not valid JSON.", hint: "Reconnect the monitor or retry refresh." }

  var values = Text.arrayOf(parsed.monitors || parsed.displays || parsed.outputs || parsed.items || parsed.data)
  var monitors = []

  for (var i = 0; i < values.length; i++) {
    var monitor = values[i] || {}
    monitors.push({
      name: Text.normalizeText(monitor.name || monitor.selector || monitor.address),
      selector: Text.normalizeText(monitor.selector || monitor.name || monitor.address || ""),
      address: Text.normalizeText(monitor.address || ""),
      description: Text.normalizeText(monitor.description || monitor.label || ""),
      width: Number(monitor.width || monitor.w || 0),
      height: Number(monitor.height || monitor.h || 0)
    })
  }

  return {
    monitors: monitors,
    error: Text.normalizeText(parsed.error || parsed.message || ""),
    hint: Text.normalizeText(parsed.hint || "")
  }
}

// Hyprland returns a top-level JSON array; map name → selector for start args.
function parseHyprctlMonitorsPayload(raw) {
  var parsed = Text.safeJson(raw)
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
      name: Text.normalizeText(monitor.name),
      selector: Text.normalizeText(monitor.name),
      address: "",
      description: Text.normalizeText(monitor.description),
      width: Number(monitor.width || 0),
      height: Number(monitor.height || 0)
    })
  }

  return { monitors: monitors, error: "", hint: "" }
}

function normalizeMonitors(raw, exitCode, stderrText) {
  var parsed = parseMonitorsPayload(raw)
  if (parsed.monitors.length > 0) {
    return Errors.applyExitCode({
      monitors: parsed.monitors,
      raw: Text.normalizeText(raw),
      error: parsed.error,
      hint: parsed.hint
    }, "monitors", exitCode, stderrText, "error")
  }

  var hypr = parseHyprctlMonitorsPayload(raw)
  if (exitCode !== 0 && hypr.error === "")
    hypr.error = Errors.processFailureMessage("monitors", exitCode, stderrText)
  if (exitCode !== 0 && hypr.hint === "") hypr.hint = Errors.recoveryHint("monitors")
  return { monitors: hypr.monitors, raw: Text.normalizeText(raw), error: hypr.error, hint: hypr.hint }
}

module.exports = {
  parseMonitorsPayload: parseMonitorsPayload,
  parseHyprctlMonitorsPayload: parseHyprctlMonitorsPayload,
  normalizeMonitors: normalizeMonitors
}
