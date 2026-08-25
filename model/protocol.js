// Canonical casting protocol names for the panel and FluxCast CLI flags.
var Text = require("./text.js")

// Collapse aliases (miracast, cast, …) into wfd | dlna | chromecast.
function normalizeProtocol(value) {
  var protocol = Text.normalizeText(value).toLowerCase()
  if (protocol === "miracast" || protocol === "wfd") return "wfd"
  if (protocol === "dlna") return "dlna"
  if (protocol === "chromecast" || protocol === "cast") return "chromecast"
  return "wfd"
}

// FluxCast uses "cast" on the command line; the panel uses "chromecast".
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

module.exports = {
  normalizeProtocol: normalizeProtocol,
  fluxcastProtocol: fluxcastProtocol,
  protocolLabel: protocolLabel
}
