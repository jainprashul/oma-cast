// Stable keys and display labels for cast targets and Hyprland outputs.
var Text = require("./text.js")
var Protocol = require("./protocol.js")

// First non-empty field wins — FluxCast and hyprctl use different property names.
function entityKey(entity, fields) {
  if (!entity) return ""
  for (var i = 0; i < fields.length; i++) {
    var value = Text.normalizeText(entity[fields[i]])
    if (value !== "") return value
  }
  return ""
}

function findByKey(list, key, keyFn) {
  var values = Text.arrayOf(list)
  var wanted = Text.normalizeText(key)
  if (wanted === "") return null
  for (var i = 0; i < values.length; i++) {
    if (keyFn(values[i]) === wanted) return values[i]
  }
  return null
}

function deviceKey(device) {
  return entityKey(device, ["selector", "address", "name"])
}

function monitorKey(monitor) {
  return entityKey(monitor, ["selector", "address", "name"])
}

function deviceLabel(device) {
  if (!device) return "Unknown device"
  var name = Text.normalizeText(device.name || device.label || device.displayName)
  if (name !== "") return name
  return Text.normalizeText(device.address || device.selector || "Unknown device")
}

function deviceSubtitle(device) {
  if (!device) return ""
  var parts = []
  if (Text.normalizeText(device.address) !== "") parts.push(Text.normalizeText(device.address))
  if (Text.normalizeText(device.protocol) !== "") parts.push(Protocol.protocolLabel(device.protocol))
  return parts.join(" · ")
}

function monitorLabel(monitor) {
  if (!monitor) return "Unknown monitor"
  var name = Text.normalizeText(monitor.name || monitor.selector || monitor.address)
  var description = Text.normalizeText(monitor.description)
  var size = []
  if (Number(monitor.width) > 0 && Number(monitor.height) > 0)
    size.push(Number(monitor.width) + "x" + Number(monitor.height))
  var parts = []
  if (name !== "") parts.push(name)
  if (description !== "") parts.push(description)
  if (size.length > 0) parts.push(size.join(" "))
  return parts.join(" · ") || "Unknown monitor"
}

function deviceByKey(devices, key) {
  return findByKey(devices, key, deviceKey)
}

function monitorByKey(monitors, key) {
  return findByKey(monitors, key, monitorKey)
}

module.exports = {
  deviceKey: deviceKey,
  monitorKey: monitorKey,
  deviceLabel: deviceLabel,
  deviceSubtitle: deviceSubtitle,
  monitorLabel: monitorLabel,
  deviceByKey: deviceByKey,
  monitorByKey: monitorByKey
}
