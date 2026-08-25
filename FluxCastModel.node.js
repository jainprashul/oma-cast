var text = require("./model/text.js")
var protocol = require("./model/protocol.js")
var format = require("./model/format.js")
var errors = require("./model/errors.js")
var entities = require("./model/entities.js")
var session = require("./model/session.js")
var presentation = require("./model/presentation.js")
var parseDoctor = require("./model/parse-doctor.js")
var parseDevices = require("./model/parse-devices.js")
var parseMonitors = require("./model/parse-monitors.js")
var parseStatus = require("./model/parse-status.js")
var cli = require("./model/cli.js")
var panelHelpers = require("./model/panel-helpers.js")

module.exports = {
  normalizeText: text.normalizeText,
  settingBool: text.settingBool,
  safeJson: text.safeJson,
  arrayOf: text.arrayOf,
  normalizeProtocol: protocol.normalizeProtocol,
  fluxcastProtocol: protocol.fluxcastProtocol,
  protocolLabel: protocol.protocolLabel,
  formatElapsed: format.formatElapsed,
  elapsedSeconds: format.elapsedSeconds,
  processFailureMessage: errors.processFailureMessage,
  recoveryHint: errors.recoveryHint,
  deviceKey: entities.deviceKey,
  monitorKey: entities.monitorKey,
  deviceLabel: entities.deviceLabel,
  deviceSubtitle: entities.deviceSubtitle,
  monitorLabel: entities.monitorLabel,
  deviceByKey: entities.deviceByKey,
  monitorByKey: entities.monitorByKey,
  isSessionReadyLine: session.isSessionReadyLine,
  resolveSessionState: session.resolveSessionState,
  barIcon: presentation.barIcon,
  iconForState: presentation.iconForState,
  stateLabel: presentation.stateLabel,
  barTooltip: presentation.barTooltip,
  statusSummary: presentation.statusSummary,
  normalizeDoctor: parseDoctor.normalizeDoctor,
  normalizeDevices: parseDevices.normalizeDevices,
  normalizeMonitors: parseMonitors.normalizeMonitors,
  normalizeStatus: parseStatus.normalizeStatus,
  parseWfdScanOutput: parseDevices.parseWfdScanOutput,
  parseHyprctlMonitorsPayload: parseMonitors.parseHyprctlMonitorsPayload,
  buildScanArgs: cli.buildScanArgs,
  buildStartArgs: cli.buildStartArgs,
  defaultLogFile: panelHelpers.defaultLogFile,
  logPathsToOpen: panelHelpers.logPathsToOpen,
  canRestartProcess: panelHelpers.canRestartProcess
}
