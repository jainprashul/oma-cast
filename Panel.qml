import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "FluxCastModel.js" as Model

Panel {
  id: root
  moduleName: "oma-cast"
  ipcTarget: "oma-cast"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string fluxcastBin: home !== "" ? home + "/.local/bin/fluxcast" : "fluxcast"

  property bool fluxcastAvailable: false
  property string fluxcastVersion: ""
  property string fluxcastDiagnostic: ""
  property string currentState: "unavailable"
  property string currentProtocol: "wfd"
  property string currentTarget: ""
  property string currentMonitor: ""
  property int currentPid: 0
  property int elapsedSeconds: 0
  property var devices: []
  property var monitors: []
  property string selectedProtocol: "wfd"
  property string selectedDeviceKey: ""
  property string selectedMonitorKey: ""
  property string lastError: ""
  property string lastErrorHint: ""
  property bool errorState: false
  property bool scanInFlight: false
  property bool startInFlight: false
  property bool stopInFlight: false
  property bool doctorInFlight: false
  property bool monitorsInFlight: false
  property bool scanQueued: false
  property bool refreshQueued: false
  property bool trayLaunching: false
  property bool trayFallbackShown: false
  property bool monitorWarningShown: false
  property bool protocolWarningShown: false
  property bool dependencyNotificationShown: false
  property bool stopRequested: false
  property string doctorRaw: ""
  property string statusRaw: ""
  property string devicesRaw: ""
  property string monitorsRaw: ""
  property date sessionStartedAt: new Date(0)

  readonly property bool scanOnOpen: Model.settingBool(setting("scan-on-open", true), true)
  readonly property bool showNotifications: Model.settingBool(setting("show-notifications", true), true)
  readonly property bool launchTrayFallback: Model.settingBool(setting("launch-tray-fallback", true), true)
  readonly property string configuredProtocol: Model.normalizeProtocol(setting("protocol", "wfd"))
  readonly property string configuredMonitor: Model.normalizeText(setting("monitor", ""))
  readonly property string configuredLogFile: Model.normalizeText(setting("log-file", "~/.local/state/fluxcast/fluxcast.log"))

  readonly property bool openedForLayout: opened

  readonly property bool structuredReady: fluxcastAvailable && currentState !== "unavailable"
  readonly property var selectedDevice: Model.deviceByKey(devices, selectedDeviceKey)
  readonly property var selectedMonitor: Model.monitorByKey(monitors, selectedMonitorKey)
  readonly property string displayState: errorState ? "error" : currentState
  readonly property var protocolOptions: [
    { id: "wfd", label: "Miracast / WFD" },
    { id: "dlna", label: "DLNA" },
    { id: "chromecast", label: "Chromecast" }
  ]

  readonly property int contentItemCount: devices.length + monitors.length

  function expandPath(path) {
    var value = Model.normalizeText(path)
    if (value === "") return ""
    if (value === "~") return home
    if (value.indexOf("~/") === 0) return home + value.substring(1)
    if (value.indexOf("$HOME/") === 0) return home + value.substring(5)
    if (value.charAt(0) !== "/") return home + "/" + value
    return value
  }

  function persistSettings(extra) {
    var next = { id: root.moduleName }
    if (root.settings) {
      for (var key in root.settings) if (key !== "id") next[key] = root.settings[key]
    }
    if (extra) {
      for (var name in extra) next[name] = extra[name]
    }
    root.settings = next
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  function setError(message, hint) {
    root.lastError = Model.normalizeText(message)
    root.lastErrorHint = Model.normalizeText(hint)
  }

  function clearError() {
    root.lastError = ""
    root.lastErrorHint = ""
    errorState = false
  }

  function notify(title, body) {
    if (!showNotifications) return
    notificationProc.command = ["notify-send", Model.normalizeText(title), Model.normalizeText(body)]
    notificationProc.running = true
  }

  function launchTray() {
    if (!launchTrayFallback || trayLaunching) return
    trayLaunching = true
    trayProc.command = [fluxcastBin, "--tray"]
    trayProc.running = true
  }

  function refresh() {
    if (doctorInFlight || monitorsInFlight) {
      refreshQueued = true
      return
    }

    refreshQueued = false
    requestDoctor()
    requestMonitors()
    applyLocalStatus()
  }

  function requestDoctor() {
    if (doctorInFlight) return
    doctorInFlight = true
    doctorProc.command = [fluxcastBin, "--doctor-json"]
    doctorProc.running = true
  }

  function requestMonitors() {
    if (monitorsInFlight) return
    monitorsInFlight = true
    monitorProc.command = ["hyprctl", "monitors", "-j"]
    monitorProc.running = true
  }

  function applyLocalStatus() {
    var running = startProc.running === true
    var previousState = currentState

    if (!fluxcastAvailable && !running) {
      if (previousState !== "error") currentState = "unavailable"
      return
    }

    if (running) {
      errorState = false
      if (currentState !== "casting" && currentState !== "connecting") currentState = "connecting"
      elapsedSeconds = Model.elapsedSeconds(sessionStartedAt, elapsedSeconds)
      return
    }

    if (previousState === "casting" || previousState === "connecting") {
      currentTarget = ""
      currentMonitor = ""
      currentPid = 0
      elapsedSeconds = 0
    }
    if (!errorState && !startInFlight && !scanInFlight)
      currentState = fluxcastAvailable ? "idle" : "unavailable"
  }

  function scan() {
    if (scanInFlight) {
      scanQueued = true
      return
    }

    var protocol = selectedProtocol || configuredProtocol || "wfd"
    var args = Model.buildScanArgs(protocol, fluxcastBin)
    if (!args) {
      setError("Native scan is only available for Miracast / WFD.", "Use Launch tray for DLNA or Chromecast discovery.")
      if (launchTrayFallback) launchTray()
      return
    }

    scanInFlight = true
    scanQueued = false
    currentState = "scanning"
    scanProc.command = args
    scanProc.running = true
  }

  function stop() {
    if (stopInFlight) return
    if (!startProc.running && currentState !== "casting" && currentState !== "connecting") return
    stopInFlight = true
    stopRequested = true
    startProc.running = false
  }

  function pickBestDevice() {
    if (!selectedDevice && devices.length > 0) {
      selectedDeviceKey = Model.deviceKey(devices[0])
      return devices[0]
    }
    return selectedDevice
  }

  function pickBestMonitor() {
    if (selectedMonitor) return selectedMonitor
    if (configuredMonitor !== "") {
      var configured = Model.monitorByKey(monitors, configuredMonitor)
      if (configured) {
        selectedMonitorKey = Model.monitorKey(configured)
        return configured
      }
      if (!monitorWarningShown) {
        monitorWarningShown = true
        setError("Configured monitor is not available.", "Choose another output or update omarchy/fluxcast settings.")
      }
    }
    if (monitors.length > 0) {
      selectedMonitorKey = Model.monitorKey(monitors[0])
      return monitors[0]
    }
    return null
  }

  function start() {
    if (startInFlight) return

    var device = pickBestDevice()
    var monitor = pickBestMonitor()
    if (!device) {
      currentState = fluxcastAvailable ? "idle" : "unavailable"
      setError("Choose a casting device first.", "Open the panel, scan, then select a device.")
      open()
      return
    }

    if (!monitor) {
      setError("Choose a monitor first.", "Connect a display or pick another output.")
      open()
      return
    }

    clearError()
    startInFlight = true
    currentTarget = Model.deviceLabel(device)
    currentMonitor = Model.monitorLabel(monitor)
    currentProtocol = selectedProtocol || configuredProtocol || "wfd"
    var args = Model.buildStartArgs(currentProtocol, device, monitor, root.settings, fluxcastBin)
    startProc.command = args
    startProc.running = true
  }

  function onDoctorResult(parsed, exitCode, stderrText) {
    doctorInFlight = false
    var result = Model.normalizeDoctor(parsed, exitCode, stderrText)
    fluxcastAvailable = result.available
    fluxcastVersion = result.version
    fluxcastDiagnostic = result.message

    if (result.available) {
      dependencyNotificationShown = false
    } else {
      if (currentState !== "unavailable" && currentState !== "idle") currentState = "unavailable"
      if (result.message !== "") setError(result.message, result.hint)
      if (result.missing.length > 0 && showNotifications && !dependencyNotificationShown) {
        dependencyNotificationShown = true
        notify("FluxCast dependencies are missing", result.missing.join(", "))
      }
      if (launchTrayFallback && !trayLaunching && !trayFallbackShown) {
        trayFallbackShown = true
        launchTray()
      }
    }
    if (refreshQueued && !doctorInFlight && !monitorsInFlight) Qt.callLater(refresh)
  }

  function onMonitorResult(parsed, exitCode, stderrText) {
    monitorsInFlight = false
    var result = Model.normalizeMonitors(parsed, exitCode, stderrText)
    monitors = result.monitors
    monitorsRaw = result.raw
    if (result.error !== "") {
      errorState = true
      currentState = "error"
      setError(result.error, result.hint)
    }
    if (configuredMonitor !== "" && !selectedMonitor && !monitorWarningShown) {
      monitorWarningShown = true
      setError("Configured monitor is not available.", "Select a monitor from the list and start again.")
    } else if (configuredMonitor !== "" && selectedMonitor && lastError === "Configured monitor is not available.") {
      clearError()
    }
    if (!selectedMonitorKey && monitors.length > 0) selectedMonitorKey = Model.monitorKey(monitors[0])
    if (refreshQueued && !doctorInFlight && !monitorsInFlight) Qt.callLater(refresh)
  }

  function onScanResult(parsed, exitCode, stderrText) {
    scanInFlight = false
    var result = Model.normalizeDevices(parsed, exitCode, stderrText)
    devices = result.devices
    devicesRaw = result.raw
    if (result.error !== "") {
      errorState = true
      currentState = "error"
      setError(result.error, result.hint)
    } else if (!startProc.running) {
      currentState = fluxcastAvailable ? "idle" : "unavailable"
    }
    if (!selectedDevice && devices.length > 0) selectedDeviceKey = Model.deviceKey(devices[0])
    if (scanQueued) Qt.callLater(scan)
  }

  function onCastStarted() {
    startInFlight = false
    errorState = false
    currentState = "connecting"
    sessionStartedAt = new Date()
    clearError()
    connectingTimer.restart()
  }

  function onCastExited(exitCode, stderrText) {
    var wasStop = stopRequested
    stopRequested = false
    startInFlight = false
    stopInFlight = false
    connectingTimer.stop()

    if (wasStop) {
      errorState = false
      currentState = "idle"
      currentTarget = ""
      currentMonitor = ""
      currentPid = 0
      elapsedSeconds = 0
      if (showNotifications) notify("Casting stopped", "FluxCast session ended")
      applyLocalStatus()
      return
    }

    if (exitCode !== 0) {
      errorState = true
      currentState = "error"
      setError(Model.processFailureMessage("start", exitCode, stderrText), Model.recoveryHint("start"))
      if (showNotifications) notify("Casting failed", lastError)
      return
    }

    currentState = fluxcastAvailable ? "idle" : "unavailable"
    currentTarget = ""
    currentMonitor = ""
    currentPid = 0
    elapsedSeconds = 0
  }

  function openLog() {
    var path = expandPath(configuredLogFile)
    if (path === "") path = expandPath("~/.local/state/fluxcast")
    openLogProc.command = ["xdg-open", path]
    openLogProc.running = true
  }

  function syncFromSettings() {
    var rawProtocol = Model.normalizeText(setting("protocol", "wfd"))
    selectedProtocol = Model.normalizeProtocol(rawProtocol)
    var rawProtocolLower = rawProtocol.toLowerCase()
    var protocolAllowed = rawProtocolLower === "wfd" || rawProtocolLower === "miracast" || rawProtocolLower === "dlna" || rawProtocolLower === "chromecast"
    if (rawProtocol !== "" && !protocolAllowed && !protocolWarningShown) {
      protocolWarningShown = true
      setError("Invalid protocol in configuration.", "Using Miracast / WFD instead.")
    } else if (rawProtocol === "" || protocolAllowed) {
      protocolWarningShown = false
    }
    if (configuredMonitor !== "") selectedMonitorKey = configuredMonitor
    monitorWarningShown = false
  }

  function debugState() {
    return JSON.stringify({
      fluxcastAvailable: fluxcastAvailable,
      fluxcastBin: fluxcastBin,
      currentState: currentState,
      lastError: lastError,
      lastErrorHint: lastErrorHint,
      devices: devices.length,
      monitors: monitors.length,
      selectedDeviceKey: selectedDeviceKey,
      selectedMonitorKey: selectedMonitorKey,
      scanInFlight: scanInFlight,
      startInFlight: startInFlight,
      startRunning: startProc.running,
      doctorInFlight: doctorInFlight,
      monitorsInFlight: monitorsInFlight
    })
  }

  function open() {
    root.controller.show()
    refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  Component.onCompleted: {
    syncFromSettings()
    refresh()
  }

  onOpenedChanged: {
    if (opened && scanOnOpen) Qt.callLater(scan)
  }

  onSettingsChanged: syncFromSettings()

  Timer {
    id: connectingTimer
    interval: 2000
    repeat: false
    onTriggered: {
      if (startProc.running && root.currentState === "connecting") {
        root.currentState = "casting"
        if (root.showNotifications) root.notify("Casting started", root.currentTarget !== "" ? root.currentTarget : "FluxCast session active")
      }
    }
  }

  Timer {
    id: elapsedTimer
    interval: 1000
    repeat: true
    running: root.currentState === "casting"
    onTriggered: root.elapsedSeconds = Model.elapsedSeconds(root.sessionStartedAt, root.elapsedSeconds)
  }

  Timer {
    id: statusTimer
    interval: 5000
    repeat: true
    running: root.opened || root.currentState === "casting" || root.currentState === "connecting" || root.currentState === "scanning"
    triggeredOnStart: false
    onTriggered: root.applyLocalStatus()
  }

  Process {
    id: doctorProc
    property string stderrText: ""
    command: [root.fluxcastBin, "--doctor-json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.doctorRaw = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: doctorProc.stderrText = String(text || "")
    }
    onExited: function(exitCode) {
      root.onDoctorResult(doctorRaw, exitCode, stderrText)
      stderrText = ""
    }
  }

  Process {
    id: monitorProc
    property string stderrText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.monitorsRaw = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: monitorProc.stderrText = String(text || "")
    }
    onExited: function(exitCode) {
      root.onMonitorResult(monitorsRaw, exitCode, stderrText)
      stderrText = ""
    }
  }

  Process {
    id: scanProc
    property string stderrText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.devicesRaw = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: scanProc.stderrText = String(text || "")
    }
    onExited: function(exitCode) {
      root.onScanResult(devicesRaw, exitCode, stderrText)
      stderrText = ""
    }
  }

  Process {
    id: startProc
    property string stderrText: ""
    stderr: StdioCollector {
      onStreamFinished: startProc.stderrText = String(text || "")
    }
    onRunningChanged: {
      if (running && root.startInFlight) root.onCastStarted()
    }
    onExited: function(exitCode) {
      root.onCastExited(exitCode, stderrText)
      stderrText = ""
    }
  }

  Process {
    id: notificationProc
  }

  Process {
    id: trayProc
    onExited: trayLaunching = false
  }

  Process {
    id: openLogProc
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: Model.iconForState(root.currentState)
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.displaySmall
          }

          Column {
            width: parent.width - (Style.space(28))
            spacing: 2

            Text {
              width: parent.width
              text: root.fluxcastAvailable ? "FluxCast ready" : (root.fluxcastDiagnostic !== "" ? root.fluxcastDiagnostic : "FluxCast unavailable")
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              text: Model.statusSummary(root.currentState, root.currentProtocol, root.currentTarget, root.currentMonitor, root.elapsedSeconds)
              color: root.barForeground
              opacity: 0.8
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.protocolOptions

            delegate: Button {
              selected: root.selectedProtocol === modelData.id
              bordered: true
              foreground: root.barForeground
              text: modelData.label
              onClicked: {
                root.selectedProtocol = modelData.id
                root.persistSettings({ protocol: modelData.id })
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "Devices"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        ScrollView {
          width: parent.width
          height: Math.min(Style.space(180), devicesColumn.implicitHeight + Style.space(12))

          Column {
            id: devicesColumn
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.devices

              delegate: Button {
                width: parent.width
                leftAlign: true
                selected: Model.deviceKey(modelData) === root.selectedDeviceKey
                bordered: true
                foreground: root.barForeground
                text: Model.deviceLabel(modelData)
                onClicked: root.selectedDeviceKey = Model.deviceKey(modelData)
              }
            }

            Text {
              visible: root.devices.length === 0
              width: parent.width
              text: root.scanInFlight ? "Scanning for Miracast devices..." : "No devices found"
              color: root.barForeground
              opacity: 0.75
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Text {
          width: parent.width
          text: "Monitors"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        ScrollView {
          width: parent.width
          height: Math.min(Style.space(160), monitorsColumn.implicitHeight + Style.space(12))

          Column {
            id: monitorsColumn
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.monitors

              delegate: Button {
                width: parent.width
                leftAlign: true
                selected: Model.monitorKey(modelData) === root.selectedMonitorKey
                bordered: true
                foreground: root.barForeground
                text: Model.monitorLabel(modelData)
                onClicked: {
                  root.selectedMonitorKey = Model.monitorKey(modelData)
                  root.persistSettings({ monitor: Model.monitorKey(modelData) })
                }
              }
            }

            Text {
              visible: root.monitors.length === 0
              width: parent.width
              text: "No monitors detected"
              color: root.barForeground
              opacity: 0.75
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Button {
            text: root.scanInFlight ? "Scanning" : "Scan"
            enabled: !root.scanInFlight
            onClicked: root.scan()
          }

          Button {
            text: "Refresh"
            onClicked: root.refresh()
          }

          Button {
            text: root.startInFlight ? "Starting" : "Start"
            enabled: !root.startInFlight
            onClicked: root.start()
          }

          Button {
            text: root.stopInFlight ? "Stopping" : "Stop"
            enabled: root.currentState === "casting" || root.currentState === "connecting"
            onClicked: root.stop()
          }

          Button {
            text: "Open log"
            onClicked: root.openLog()
          }

          Button {
            visible: root.launchTrayFallback
            text: "Launch tray"
            onClicked: root.launchTray()
          }
        }

        Column {
          width: parent.width
          spacing: 2

          Text {
            width: parent.width
            text: "Current target: " + (root.currentTarget !== "" ? root.currentTarget : "None")
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "Current monitor: " + (root.currentMonitor !== "" ? root.currentMonitor : "None")
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "Elapsed: " + Model.formatElapsed(root.elapsedSeconds)
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Rectangle {
          visible: root.lastError !== ""
          width: parent.width
          radius: Style.space(8)
          color: "transparent"
          border.color: Color.urgent
          border.width: 1

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(6)
            spacing: 2

            Text {
              width: parent.width
              text: root.lastError
              color: Color.urgent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Text {
              visible: root.lastErrorHint !== ""
              width: parent.width
              text: root.lastErrorHint
              color: root.barForeground
              opacity: 0.8
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
