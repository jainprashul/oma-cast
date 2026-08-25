// Parse `fluxcast --doctor-json` into availability, version, and missing deps.
var Text = require("./text.js")
var Errors = require("./errors.js")

function parseDoctorPayload(raw) {
  var parsed = Text.safeJson(raw)
  if (!parsed) {
    return {
      available: false,
      version: "",
      message: "FluxCast did not return valid diagnostics.",
      missing: [],
      hint: "Run `fluxcast --doctor-json` in a terminal to inspect the failure."
    }
  }

  var missing = []
  if (Array.isArray(parsed.missing)) missing = parsed.missing.slice()
  else if (Array.isArray(parsed.missingDependencies)) missing = parsed.missingDependencies.slice()
  else if (Array.isArray(parsed.dependenciesMissing)) missing = parsed.dependenciesMissing.slice()

  var checks = Text.arrayOf(parsed.checks)
  var hasFail = false
  for (var i = 0; i < checks.length; i++) {
    var check = checks[i] || {}
    var status = Text.normalizeText(check.status).toLowerCase()
    if (status === "fail") {
      hasFail = true
      missing.push(Text.normalizeText(check.name || check.message || "dependency"))
    }
  }

  // Doctor JSON shape varies by FluxCast version; infer readiness from several flags.
  var available = parsed.available !== undefined ? !!parsed.available : !hasFail
  if (parsed.ok === false || parsed.installed === false || parsed.ready === false) available = false
  if (hasFail) available = false

  var message = Text.normalizeText(parsed.message || parsed.error || parsed.summary || parsed.diagnostic)
  if (message === "" && !available) message = "FluxCast is not ready."
  if (message === "" && parsed.wfd_candidate === false)
    message = Text.normalizeText(parsed.summary || "Miracast/WFD is not confirmed yet.")

  var version = Text.normalizeText(parsed.version || parsed.fluxcastVersion || "")
  if (version === "") {
    for (var j = 0; j < checks.length; j++) {
      var runtime = checks[j] || {}
      if (Text.normalizeText(runtime.name).toLowerCase() === "python") {
        version = Text.normalizeText(runtime.detail || runtime.message)
        break
      }
    }
  }

  var hint = Text.normalizeText(parsed.hint || parsed.recovery || parsed.recommendation)
  if (hint === "" && !available)
    hint = missing.length > 0 ? "Install the missing dependency, then retry." : "Check the FluxCast log or reinstall FluxCast."
  if (hint === "" && parsed.wfd_candidate === false)
    hint = "Fix the warn/fail rows in doctor output, then retry scan."

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
  return Errors.applyExitCode(parsed, "doctor", exitCode, stderrText, "message")
}

module.exports = {
  parseDoctorPayload: parseDoctorPayload,
  normalizeDoctor: normalizeDoctor
}
