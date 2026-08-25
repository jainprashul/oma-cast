// Parse `fluxcast --status-json` into a normalized session snapshot.
var Text = require("./text.js")
var Protocol = require("./protocol.js")
var Errors = require("./errors.js")

function parseStatusPayload(raw) {
  var parsed = Text.safeJson(raw)
  if (!parsed) {
    return {
      state: "idle",
      protocol: "wfd",
      target: "",
      monitor: "",
      pid: 0,
      startedAtMs: 0,
      elapsedSeconds: 0,
      error: "FluxCast status output was not valid JSON.",
      hint: "Retry refresh or inspect the log."
    }
  }

  var state = Text.normalizeText(parsed.state || parsed.status || "idle").toLowerCase()
  // FluxCast versions use different state names; map to the panel's finite set.
  if (state === "running" || state === "active") state = "casting"
  if (state !== "casting" && state !== "connecting" && state !== "scanning" && state !== "error" && state !== "idle")
    state = "idle"

  var startedAtMs = 0
  var startedAt = parsed.startedAt || parsed.started_at || parsed.started || parsed.startTime
  if (startedAt) {
    var asDate = new Date(startedAt)
    if (!isNaN(asDate.getTime())) startedAtMs = asDate.getTime()
  }

  return {
    state: state,
    protocol: Protocol.normalizeProtocol(parsed.protocol || parsed.mode || "wfd"),
    target: Text.normalizeText(parsed.target || parsed.device || parsed.deviceName || ""),
    monitor: Text.normalizeText(parsed.monitor || parsed.output || parsed.display || ""),
    pid: Number(parsed.pid || 0) || 0,
    startedAtMs: startedAtMs,
    elapsedSeconds: Number(parsed.elapsedSeconds || parsed.elapsed || 0) || 0,
    error: Text.normalizeText(parsed.error || parsed.message || ""),
    hint: Text.normalizeText(parsed.hint || "")
  }
}

function normalizeStatus(raw, exitCode, stderrText) {
  var parsed = parseStatusPayload(raw)
  return Errors.applyExitCode(parsed, "status", exitCode, stderrText, "error")
}

module.exports = {
  parseStatusPayload: parseStatusPayload,
  normalizeStatus: normalizeStatus
}
