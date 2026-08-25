// Session lifecycle: log-line detection and panel state resolution.
var Text = require("./text.js")

// True when FluxCast stdout indicates media is flowing (not merely connecting).
function isSessionReadyLine(line) {
  var text = Text.normalizeText(line).toLowerCase()
  if (text === "") return false
  if (text.indexOf("play accepted") !== -1) return true
  if (text.indexOf("media stream started") !== -1) return true
  if (text.indexOf("casting started") !== -1) return true
  if (text.indexOf("output signal sent") !== -1) return true
  return false
}

// Derive the next bar/panel state from subprocess flags and the triggering action.
// "poll" is the periodic refresh path; other actions come from user IPC.
function resolveSessionState(input) {
  var options = input || {}
  var current = Text.normalizeText(options.currentState) || "idle"
  var running = !!options.running || !!options.startInFlight
  var sessionReady = !!options.sessionReady
  var scanInFlight = !!options.scanInFlight
  var available = !!options.fluxcastAvailable
  var action = Text.normalizeText(options.action) || "poll"
  var live = current === "casting" || current === "connecting" || running || sessionReady
  var scanning = current === "scanning" || scanInFlight

  if (action === "exit") return options.errorState ? "error" : (available ? "idle" : "unavailable")

  if (live && (action === "scan" || action === "doctor-fail" || action === "poll")) {
    if (sessionReady || current === "casting") return "casting"
    return running || current === "connecting" ? "connecting" : current
  }

  if (scanning && action === "poll") return "scanning"

  if (action === "scan") return "scanning"
  if (options.errorState) return "error"
  if (!available) return "unavailable"
  return "idle"
}

module.exports = {
  isSessionReadyLine: isSessionReadyLine,
  resolveSessionState: resolveSessionState
}
