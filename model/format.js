// Human-readable elapsed timers for the bar tooltip and panel summary.

function formatElapsed(seconds) {
  var value = Math.max(0, Math.floor(Number(seconds) || 0))
  var hours = Math.floor(value / 3600)
  var minutes = Math.floor((value % 3600) / 60)
  var secs = value % 60
  function pad(n) { return n < 10 ? "0" + n : String(n) }
  if (hours > 0) return hours + ":" + pad(minutes) + ":" + pad(secs)
  return pad(minutes) + ":" + pad(secs)
}

// Prefer a live Date when the panel tracks start time; fall back to FluxCast status JSON.
function elapsedSeconds(startedAt, fallbackSeconds) {
  var elapsed = Number(fallbackSeconds || 0)
  if (startedAt && startedAt.getTime && startedAt.getTime() > 0) {
    var diff = Math.floor((Date.now() - startedAt.getTime()) / 1000)
    if (isFinite(diff) && diff >= 0) elapsed = diff
  }
  return Math.max(0, Math.floor(elapsed))
}

module.exports = {
  formatElapsed: formatElapsed,
  elapsedSeconds: elapsedSeconds
}
