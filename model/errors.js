// User-facing messages when a FluxCast subprocess exits non-zero.
var Text = require("./text.js")

function processFailureMessage(operation, exitCode, stderrText) {
  var stderr = Text.normalizeText(stderrText)
  if (stderr !== "") return "FluxCast " + operation + " failed: " + stderr
  return "FluxCast " + operation + " failed with exit code " + exitCode + "."
}

function recoveryHint(operation) {
  if (operation === "doctor") return "Check that FluxCast, wf-recorder, ffmpeg, and Wi-Fi Direct support are installed."
  if (operation === "scan") return "Make sure the Wi-Fi Direct adapter is available and retry scan."
  if (operation === "status") return "Refresh the panel or inspect the FluxCast log."
  if (operation === "stop") return "If FluxCast is still active, stop it from the tray or retry stop."
  if (operation === "start") return "Review the selected device and monitor, then try again."
  return "Review the selected device and monitor, then try again."
}

// Enrich a parsed result in place; only fills empty error/hint fields.
function applyExitCode(result, operation, exitCode, stderrText, messageKey) {
  if (exitCode === 0) return result
  if (Text.normalizeText(result[messageKey]) === "")
    result[messageKey] = processFailureMessage(operation, exitCode, stderrText)
  if (Text.normalizeText(result.hint) === "")
    result.hint = recoveryHint(operation)
  return result
}

module.exports = {
  processFailureMessage: processFailureMessage,
  recoveryHint: recoveryHint,
  applyExitCode: applyExitCode
}
