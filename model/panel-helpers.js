// Small helpers wired from Panel.qml (log paths, process restart guard).
var Text = require("./text.js")

var SESSION_LOG = "/tmp/fluxcast-cast.log"

function defaultLogFile() {
  return SESSION_LOG
}

function logPathsToOpen(configuredPath) {
  var sessionLog = defaultLogFile()
  var configured = Text.normalizeText(configuredPath)
  if (configured === "") return [sessionLog]
  if (configured === sessionLog) return [sessionLog]
  return [configured, sessionLog]
}

// Block a new start while a cast subprocess is still launching or active.
function canRestartProcess(inFlight, running) {
  return !inFlight || !running
}

module.exports = {
  defaultLogFile: defaultLogFile,
  logPathsToOpen: logPathsToOpen,
  canRestartProcess: canRestartProcess
}
