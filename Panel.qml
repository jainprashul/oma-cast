import QtQuick
import Quickshell
import qs.Ui
import "FluxCastModel.js" as Model
import "panel"

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
  property bool sessionReady: false
  property string doctorRaw: ""
  property string devicesRaw: ""
  property string monitorsRaw: ""
  property date sessionStartedAt: new Date(0)

  readonly property bool scanOnOpen: Model.settingBool(setting("scan-on-open", true), true)
  readonly property bool showNotifications: Model.settingBool(setting("show-notifications", true), true)
  readonly property bool launchTrayFallback: Model.settingBool(setting("launch-tray-fallback", true), true)
  readonly property string configuredProtocol: Model.normalizeProtocol(setting("protocol", "wfd"))
  readonly property string configuredMonitor: Model.normalizeText(setting("monitor", ""))
  readonly property string configuredLogFile: Model.normalizeText(setting("log-file", Model.defaultLogFile()))

  readonly property var selectedDevice: Model.deviceByKey(devices, selectedDeviceKey)
  readonly property var selectedMonitor: Model.monitorByKey(monitors, selectedMonitorKey)
  readonly property string displayState: errorState ? "error" : currentState
  readonly property var protocolOptions: [
    { id: "wfd", label: "Miracast" },
    { id: "dlna", label: "DLNA" },
    { id: "chromecast", label: "Chromecast" }
  ]

  readonly property bool isLiveSession: currentState === "casting" || currentState === "connecting" || startInFlight || sessionReady
  readonly property bool isScanning: !isLiveSession && (currentState === "scanning" || scanInFlight)
  readonly property bool isBlocked: !fluxcastAvailable && !isLiveSession
  readonly property bool isSetupPhase: !isLiveSession && !isBlocked
  readonly property bool canPickMonitor: monitors.length > 1
  readonly property bool hasDevice: selectedDevice !== null
  readonly property bool canStartCast: isSetupPhase && hasDevice && selectedMonitor !== null && !isScanning && !startInFlight
  readonly property bool primaryBusy: scanInFlight || startInFlight || stopInFlight
  readonly property bool nativeScanSupported: Model.buildScanArgs(selectedProtocol, fluxcastBin) !== null

  readonly property string statusHeadline: {
    if (isBlocked) return fluxcastDiagnostic !== "" ? fluxcastDiagnostic : "FluxCast unavailable"
    if (displayState === "error") return lastError !== "" ? lastError : "Casting failed"
    if (currentState === "connecting" && !sessionReady) return "Connecting…"
    if (currentState === "casting" || sessionReady) return currentTarget !== "" ? currentTarget : "Casting"
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
    if (stopInFlight) return "Stopping…"
    if (isLiveSession) return "Stop casting"
    if (primaryBusy) {
      if (startInFlight) return "Starting…"
      return "Scanning…"
    }
    if (isBlocked) return launchTrayFallback ? "Open tray" : "Retry"
    if (!hasDevice || devices.length === 0) return nativeScanSupported ? "Find TVs" : "Open tray"
    return "Start cast"
  }

  readonly property bool primaryEnabled: (isLiveSession && !stopInFlight) || (!primaryBusy && (isBlocked || isSetupPhase))

  readonly property color contentForeground: barForeground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function elapsedSecondsFromSession() {
    return Model.elapsedSeconds(sessionStartedAt, elapsedSeconds)
  }

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

  function runProcess(proc, command) {
    proc.running = false
    proc.command = command
    proc.running = true
  }

  function notify(title, body) {
    if (!showNotifications) return
    Quickshell.execDetached(["notify-send", Model.normalizeText(title), Model.normalizeText(body)])
  }

  function launchTray() {
    if (!launchTrayFallback || trayLaunching) return
    trayLaunching = true
    runProcess(backend.trayProc, [fluxcastBin, "--tray"])
  }

  function refresh() {
    var doctorBusy = !Model.canRestartProcess(doctorInFlight, backend.doctorProc.running === true)
    var monitorBusy = !Model.canRestartProcess(monitorsInFlight, backend.monitorProc.running === true)
    if (doctorBusy || monitorBusy) {
      refreshQueued = true
      return
    }

    refreshQueued = false
    requestDoctor()
    requestMonitors()
    applyLocalStatus()
  }

  function requestDoctor() {
    if (!Model.canRestartProcess(doctorInFlight, backend.doctorProc.running === true)) return
    doctorInFlight = true
    runProcess(backend.doctorProc, [fluxcastBin, "--doctor-json"])
  }

  function requestMonitors() {
    if (!Model.canRestartProcess(monitorsInFlight, backend.monitorProc.running === true)) return
    monitorsInFlight = true
    runProcess(backend.monitorProc, ["hyprctl", "monitors", "-j"])
  }

  function sessionSnapshot(action) {
    return {
      currentState: currentState,
      running: backend.startProc.running === true,
      startInFlight: startInFlight,
      sessionReady: sessionReady,
      scanInFlight: scanInFlight,
      fluxcastAvailable: fluxcastAvailable,
      errorState: errorState,
      action: action || "poll"
    }
  }

  function applyLocalStatus() {
    var running = backend.startProc.running === true
    currentState = Model.resolveSessionState(sessionSnapshot("poll"))
    if (currentState === "casting") elapsedSeconds = elapsedSecondsFromSession()
    if (running || startInFlight || sessionReady) errorState = false
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
    currentState = Model.resolveSessionState(sessionSnapshot("scan"))
    runProcess(backend.scanProc, args)
  }

  function stop() {
    if (stopInFlight) return
    if (!isLiveSession && !backend.startProc.running) return
    stopInFlight = true
    stopRequested = true
    backend.startProc.running = false
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
    sessionReady = false
    currentState = "connecting"
    currentTarget = Model.deviceLabel(device)
    currentMonitor = Model.monitorLabel(monitor)
    currentProtocol = selectedProtocol || configuredProtocol || "wfd"
    var args = Model.buildStartArgs(currentProtocol, device, monitor, root.settings, fluxcastBin)
    runProcess(backend.startProc, ["env", "PYTHONUNBUFFERED=1"].concat(args))
  }

  function onDoctorResult(parsed, exitCode, stderrText) {
    doctorInFlight = false
    var result = Model.normalizeDoctor(parsed, exitCode, stderrText)
    fluxcastAvailable = result.available
    fluxcastVersion = result.version
    fluxcastDiagnostic = result.message

    if (result.available) {
      dependencyNotificationShown = false
      if (!isLiveSession && !backend.startProc.running && currentState === "unavailable")
        currentState = "idle"
    } else if (!isLiveSession && !backend.startProc.running) {
      currentState = Model.resolveSessionState(sessionSnapshot("doctor-fail"))
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
      if (!isLiveSession && !backend.startProc.running) {
        errorState = true
        currentState = "error"
        setError(result.error, result.hint)
      }
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
      if (!isLiveSession && !backend.startProc.running) {
        errorState = true
        currentState = "error"
        setError(result.error, result.hint)
      }
    } else if (!isLiveSession && !backend.startProc.running && !startInFlight) {
      currentState = fluxcastAvailable ? "idle" : "unavailable"
    }
    if (!selectedDevice && devices.length > 0) selectedDeviceKey = Model.deviceKey(devices[0])
    if (scanQueued) Qt.callLater(scan)
  }

  function onCastStarted() {
    startInFlight = false
    errorState = false
    sessionStartedAt = new Date(0)
    elapsedSeconds = 0
    clearError()
  }

  function onCastLogLine(line) {
    if (!backend.startProc.running || sessionReady) return
    if (!Model.isSessionReadyLine(line)) return
    sessionReady = true
    currentState = "casting"
    sessionStartedAt = new Date()
    elapsedSeconds = 0
    if (showNotifications) notify("Casting started", currentTarget !== "" ? currentTarget : "FluxCast session active")
  }

  function onCastExited(exitCode, stderrText) {
    var wasStop = stopRequested
    stopRequested = false
    sessionReady = false
    startInFlight = false
    stopInFlight = false
    currentTarget = ""
    currentMonitor = ""
    elapsedSeconds = 0
    sessionStartedAt = new Date(0)

    if (wasStop) {
      errorState = false
      currentState = Model.resolveSessionState(sessionSnapshot("exit"))
      if (showNotifications) notify("Casting stopped", "FluxCast session ended")
      return
    }

    if (exitCode !== 0) {
      errorState = true
      currentState = Model.resolveSessionState(sessionSnapshot("exit"))
      setError(Model.processFailureMessage("start", exitCode, stderrText), Model.recoveryHint("start"))
      if (showNotifications) notify("Casting failed", lastError)
      return
    }

    errorState = false
    currentState = Model.resolveSessionState(sessionSnapshot("exit"))
  }

  function openLog() {
    var paths = Model.logPathsToOpen(expandPath(configuredLogFile))
    Quickshell.execDetached([
      "bash",
      "-lc",
      'for p in "$@"; do if [ -e "$p" ]; then exec xdg-open "$p"; fi; done; notify-send -a "Oma Cast" "FluxCast log" "No log file yet. Cast once, then try again."',
      "oma-cast-open-log"
    ].concat(paths))
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
      startRunning: backend.startProc.running,
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
    if (!hasDevice || devices.length === 0 || !nativeScanSupported) {
      if (nativeScanSupported) scan()
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
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  Component.onCompleted: {
    syncFromSettings()
    refresh()
  }

  onOpenedChanged: {
    if (opened && scanOnOpen && !isLiveSession && !backend.startProc.running) Qt.callLater(scan)
  }

  onSettingsChanged: syncFromSettings()

  onSelectedProtocolChanged: {
    if (devices.length > 0) {
      devices = []
      selectedDeviceKey = ""
    }
  }

  PanelBackend {
    id: backend
    controller: root
  }

  PanelContent {
    controller: root
  }
}
