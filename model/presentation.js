// Bar icon, tooltip, and panel summary strings derived from session state.
var Text = require("./text.js")
var Protocol = require("./protocol.js")
var Format = require("./format.js")

var STATE_META = {
  casting: { label: "Casting", icon: "󰿎" },
  connecting: { label: "Connecting", icon: "󰐊" },
  scanning: { label: "Scanning", icon: "󰄬" },
  error: { label: "Error", icon: "󰅙" },
  idle: { label: "Idle", icon: "󰄘" }
}

function stateMeta(state) {
  var value = Text.normalizeText(state)
  return STATE_META[value] || { label: "Unavailable", icon: "󰅚" }
}

function iconForState(state) {
  return stateMeta(state).icon
}

function stateLabel(state) {
  return stateMeta(state).label
}

function barTooltip(state, target, protocol, elapsedSeconds) {
  var value = Text.normalizeText(state)
  var label = stateLabel(value)
  if (value === "casting") {
    var parts = [label, Protocol.protocolLabel(protocol)]
    var targetText = Text.normalizeText(target)
    if (targetText !== "") parts.push(targetText)
    parts.push(Format.formatElapsed(elapsedSeconds))
    return parts.join(" · ")
  }
  if (value === "error") return label
  return label + " · Open Oma Cast"
}

function statusSummary(state, protocol, target, monitor, elapsedSeconds) {
  var parts = [stateLabel(state), Protocol.protocolLabel(protocol)]
  var targetText = Text.normalizeText(target)
  var monitorText = Text.normalizeText(monitor)
  if (targetText !== "") parts.push(targetText)
  if (monitorText !== "") parts.push(monitorText)
  if (Text.normalizeText(state) === "casting") parts.push(Format.formatElapsed(elapsedSeconds))
  return parts.join(" · ")
}

module.exports = {
  iconForState: iconForState,
  stateLabel: stateLabel,
  barTooltip: barTooltip,
  statusSummary: statusSummary
}
