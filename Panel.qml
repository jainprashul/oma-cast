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
    { id: "wfd", label: "Miracast" },
    { id: "dlna", label: "DLNA" },
    { id: "chromecast", label: "Chromecast" }
  ]

  readonly property bool isLiveSession: currentState === "casting" || currentState === "connecting"
  readonly property bool isScanning: currentState === "scanning" || scanInFlight
  readonly property bool isBlocked: !fluxcastAvailable && !isLiveSession
  readonly property bool isSetupPhase: !isLiveSession && !isBlocked
  readonly property bool canPickMonitor: monitors.length > 1
  readonly property bool hasDevice: selectedDevice !== null
  readonly property bool canStartCast: isSetupPhase && hasDevice && selectedMonitor !== null && !isScanning && !startInFlight
  readonly property bool primaryBusy: scanInFlight || startInFlight || stopInFlight

  readonly property string statusHeadline: {
    if (isBlocked) return fluxcastDiagnostic !== "" ? fluxcastDiagnostic : "FluxCast unavailable"
    if (displayState === "error") return lastError !== "" ? lastError : "Casting failed"
    if (currentState === "connecting") return "Connecting…"
    if (currentState === "casting") return currentTarget !== "" ? currentTarget : "Casting"
    if (isScanning) return "Looking for displays…"
    if (!hasDevice) return "Choose a TV"
    return "Ready to cast"
  }

  readonly property string statusDetail: {
    if (isBlocked) return lastErrorHint !== "" ? lastErrorHint : "Check dependencies or open the FluxCast tray."
    if (displayState === "error" && lastErrorHint !== "") return lastErrorHint
    if (currentState === "connecting") {
      var connectingParts = ["Waiting for the TV handshake"]
      if (currentTarget !== "") connectingParts.unshift(currentTarget)
      return connectingParts.join(" · ")
    }
    if (isLiveSession) {
      var parts = [Model.protocolLabel(currentProtocol)]
      if (currentMonitor !== "") parts.push(currentMonitor)
      if (currentState === "casting") parts.push(Model.formatElapsed(elapsedSeconds))
      return parts.join(" · ")
    }
    if (isScanning) return "Put the TV in Screen Share or Wireless Display mode."
    if (!hasDevice) return devices.length === 0 ? "Scan to find nearby receivers." : "Select a device below."
    var monitorName = selectedMonitor ? Model.monitorLabel(selectedMonitor) : ""
    return monitorName !== "" ? monitorName + " · " + Model.protocolLabel(selectedProtocol) : Model.protocolLabel(selectedProtocol)
  }

  readonly property string primaryLabel: {
    if (primaryBusy) {
      if (stopInFlight) return "Stopping…"
      if (startInFlight) return "Starting…"
      return "Scanning…"
    }
    if (isLiveSession) return "Stop casting"
    if (isBlocked) return launchTrayFallback ? "Open tray" : "Retry"
    if (!hasDevice || devices.length === 0) return Model.buildScanArgs(selectedProtocol, fluxcastBin) ? "Find TVs" : "Open tray"
    return "Start cast"
  }

  readonly property bool primaryEnabled: !primaryBusy && (isLiveSession || isBlocked || isSetupPhase)

  readonly property color contentForeground: barForeground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

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

    if (!fluxcastAvailable && !running && !startInFlight) {
      if (previousState !== "error") currentState = "unavailable"
      return
    }

    if (running || startInFlight) {
      errorState = false
      if (currentState !== "casting") currentState = "connecting"
      if (currentState === "casting") elapsedSeconds = Model.elapsedSeconds(sessionStartedAt, elapsedSeconds)
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
    currentState = "connecting"
    currentTarget = Model.deviceLabel(device)
    currentMonitor = Model.monitorLabel(monitor)
    currentProtocol = selectedProtocol || configuredProtocol || "wfd"
    var args = Model.buildStartArgs(currentProtocol, device, monitor, root.settings, fluxcastBin)
    startProc.command = ["env", "PYTHONUNBUFFERED=1"].concat(args)
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
    } else if (!startProc.running && !startInFlight && currentState !== "connecting" && currentState !== "casting") {
      currentState = fluxcastAvailable ? "idle" : "unavailable"
    }
    if (!selectedDevice && devices.length > 0) selectedDeviceKey = Model.deviceKey(devices[0])
    if (scanQueued) Qt.callLater(scan)
  }

  function onCastStarted() {
    startInFlight = false
    errorState = false
    currentState = "connecting"
    sessionStartedAt = new Date(0)
    elapsedSeconds = 0
    clearError()
  }

  function onCastLogLine(line) {
    if (!startProc.running || currentState !== "connecting") return
    if (!Model.isSessionReadyLine(line)) return
    currentState = "casting"
    sessionStartedAt = new Date()
    elapsedSeconds = 0
    if (showNotifications) notify("Casting started", currentTarget !== "" ? currentTarget : "FluxCast session active")
  }

  function onCastExited(exitCode, stderrText) {
    var wasStop = stopRequested
    stopRequested = false
    startInFlight = false
    stopInFlight = false

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

  function primaryAction() {
    if (!primaryEnabled) return
    if (isLiveSession) {
      stop()
      return
    }
    if (isBlocked) {
      if (launchTrayFallback) launchTray()
      else refresh()
      return
    }
    if (!hasDevice || devices.length === 0 || !Model.buildScanArgs(selectedProtocol, fluxcastBin)) {
      if (Model.buildScanArgs(selectedProtocol, fluxcastBin)) scan()
      else if (launchTrayFallback) launchTray()
      return
    }
    start()
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
    if (root.bar && typeof root.brar.switchPanelFrom === "function")
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

  onSelectedProtocolChanged: {
    if (devices.length > 0) {
      devices = []
      selectedDeviceKey = ""
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
    stdout: SplitParser {
      onRead: function(line) { root.onCastLogLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) {
        startProc.stderrText += (startProc.stderrText === "" ? "" : "\n") + line
        root.onCastLogLine(line)
      }
    }
    onRunningChanged: {
      if (running && root.startInFlight) {
        startProc.stderrText = ""
        root.onCastStarted()
      }
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
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panelScroll.contentHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          // ---- Hero -------------------------------------------------------
          Item {
            width: parent.width
            height: Math.max(heroIcon.implicitHeight, heroText.implicitHeight)

            Text {
              id: heroIcon
              text: Model.iconForState(root.displayState)
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.fontPx(2.2)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroText
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.statusHeadline
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
              }

              Text {
                width: parent.width
                text: root.statusDetail
                color: root.contentForeground
                opacity: 0.72
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
              }
            }
          }

          // ---- Error banner -----------------------------------------------
          Rectangle {
            visible: root.lastError !== "" && root.displayState === "error"
            width: parent.width
            radius: Style.space(8)
            color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.08)
            border.color: Color.urgent
            border.width: 1
            implicitHeight: errorColumn.implicitHeight + Style.space(12)

            Column {
              id: errorColumn
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.lastErrorHint !== "" ? root.lastErrorHint : "Try scanning again or inspect the FluxCast log."
                color: root.contentForeground
                opacity: 0.85
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
          }

          // ---- Live session card ------------------------------------------
          Rectangle {
            visible: root.isLiveSession
            width: parent.width
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
            border.width: 1
            implicitHeight: liveColumn.implicitHeight + Style.space(14)

            Column {
              id: liveColumn
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: "󰒋"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                  width: parent.width - Style.space(24)
                  spacing: 1

                  Text {
                    width: parent.width
                    text: root.currentTarget !== "" ? root.currentTarget : "Receiver"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: (root.currentMonitor !== "" ? root.currentMonitor : "Display") + " · " + Model.protocolLabel(root.currentProtocol)
                    color: root.contentForeground
                    opacity: 0.7
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }

              Text {
                visible: root.currentState === "connecting"
                width: parent.width
                text: "Connecting…"
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                visible: root.currentState === "casting"
                width: parent.width
                text: Model.formatElapsed(root.elapsedSeconds)
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
            }
          }

          // ---- Setup: protocol + devices + monitor ------------------------
          Column {
            visible: root.isSetupPhase
            width: parent.width
            spacing: Style.space(10)

            Column {
              width: parent.width
              spacing: Style.space(6)
              visible: !root.isScanning

              Text {
                width: parent.width
                text: "Protocol"
                color: root.contentForeground
                opacity: 0.65
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Flow {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.protocolOptions

                  delegate: Button {
                    selected: root.selectedProtocol === modelData.id
                    bordered: true
                    foreground: root.contentForeground
                    text: modelData.label
                    onClicked: {
                      if (root.selectedProtocol === modelData.id) return
                      root.selectedProtocol = modelData.id
                      root.persistSettings({ protocol: modelData.id })
                    }
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: "Receivers"
                  color: root.contentForeground
                  opacity: 0.65
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: Style.space(4); height: 1 }

                Button {
                  id: rescanBtn
                  iconText: "󰑐"
                  tooltipText: root.isScanning ? "Scanning…" : "Scan again"
                  bordered: true
                  foreground: root.contentForeground
                  iconSpinning: root.isScanning
                  opacity: root.isScanning ? 0.6 : 1
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: {
                    if (!root.isScanning) root.scan()
                  }
                }
              }

              Column {
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                  model: root.devices

                  delegate: Button {
                    width: parent.width
                    leftAlign: true
                    selected: Model.deviceKey(modelData) === root.selectedDeviceKey
                    bordered: true
                    foreground: root.contentForeground
                    text: Model.deviceLabel(modelData)
                    onClicked: root.selectedDeviceKey = Model.deviceKey(modelData)
                  }
                }

                Text {
                  visible: root.devices.length === 0
                  width: parent.width
                  text: root.isScanning
                    ? "Scanning for nearby TVs…"
                    : (Model.buildScanArgs(root.selectedProtocol, root.fluxcastBin)
                      ? "No receivers yet. Tap Find TVs to scan."
                      : "Use the tray to discover DLNA or Chromecast devices.")
                  color: root.contentForeground
                  opacity: 0.6
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }

            Column {
              visible: root.canPickMonitor
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: "Screen"
                color: root.contentForeground
                opacity: 0.65
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Flow {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.monitors

                  delegate: Button {
                    selected: Model.monitorKey(modelData) === root.selectedMonitorKey
                    bordered: true
                    foreground: root.contentForeground
                    text: Model.monitorLabel(modelData)
                    onClicked: {
                      root.selectedMonitorKey = Model.monitorKey(modelData)
                      root.persistSettings({ monitor: Model.monitorKey(modelData) })
                    }
                  }
                }
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.contentForeground
          }

          // ---- Primary action + secondary links ---------------------------
          Button {
            width: parent.width
            leftAlign: true
            bordered: true
            active: root.isLiveSession
            selected: root.isLiveSession
            foreground: root.isLiveSession ? Color.urgent : root.contentForeground
            text: root.primaryLabel
            opacity: root.primaryEnabled ? 1 : 0.45
            onClicked: root.primaryAction()
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              visible: root.launchTrayFallback
              text: "Tray"
              bordered: true
              foreground: root.contentForeground
              onClicked: root.launchTray()
            }

            Button {
              text: "Log"
              bordered: true
              foreground: root.contentForeground
              onClicked: root.openLog()
            }

            Button {
              visible: root.isSetupPhase
              text: "Refresh"
              bordered: true
              foreground: root.contentForeground
              opacity: root.doctorInFlight || root.monitorsInFlight ? 0.5 : 1
              onClicked: {
                if (!root.doctorInFlight && !root.monitorsInFlight) root.refresh()
              }
            }
          }
        }
      }
    }
  }
}
