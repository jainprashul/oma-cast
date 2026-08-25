import QtQuick
import Quickshell.Io

// Subprocess I/O and periodic polling for the oma-cast panel controller.
// Panel.qml owns session state; this component wires fluxcast/hyprctl processes
// and forwards stdout/stderr back through controller callbacks.
Item {
  id: backend
  required property var controller

  property alias doctorProc: doctorProc
  property alias monitorProc: monitorProc
  property alias scanProc: scanProc
  property alias startProc: startProc
  property alias trayProc: trayProc

  // Tick the on-screen elapsed timer while a cast is active.
  Timer {
    interval: 1000
    repeat: true
    running: controller.currentState === "casting"
    onTriggered: controller.elapsedSeconds = controller.elapsedSecondsFromSession()
  }

  // Reconcile UI state with running processes during long-lived operations.
  Timer {
    interval: 5000
    repeat: true
    running: controller.currentState === "casting"
      || controller.currentState === "connecting"
      || controller.currentState === "scanning"
    triggeredOnStart: false
    onTriggered: controller.applyLocalStatus()
  }

  // Dependency and availability check (`fluxcast --doctor-json`).
  Process {
    id: doctorProc
    property string stderrText: ""
    command: [controller.fluxcastBin, "--doctor-json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: controller.doctorRaw = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: doctorProc.stderrText = String(text || "")
    }
    onExited: function(exitCode) {
      controller.onDoctorResult(controller.doctorRaw, exitCode, stderrText)
      stderrText = ""
    }
  }

  // Hyprland output list used to pick which monitor to mirror.
  Process {
    id: monitorProc
    property string stderrText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: controller.monitorsRaw = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: monitorProc.stderrText = String(text || "")
    }
    onExited: function(exitCode) {
      controller.onMonitorResult(controller.monitorsRaw, exitCode, stderrText)
      stderrText = ""
    }
  }

  // Native WFD device discovery (DLNA/Chromecast use the tray instead).
  Process {
    id: scanProc
    property string stderrText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: controller.devicesRaw = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: scanProc.stderrText = String(text || "")
    }
    onExited: function(exitCode) {
      controller.onScanResult(controller.devicesRaw, exitCode, stderrText)
      stderrText = ""
    }
  }

  // Long-running cast process; readiness is detected from log lines, not exit.
  Process {
    id: startProc
    property var stderrLines: []
    stdout: SplitParser {
      onRead: function(line) { controller.onCastLogLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) {
        startProc.stderrLines.push(line)
        // FluxCast may emit the session-ready marker on stderr.
        controller.onCastLogLine(line)
      }
    }
    onRunningChanged: {
      if (running && controller.startInFlight) {
        startProc.stderrLines = []
        controller.onCastStarted()
      }
    }
    onExited: function(exitCode) {
      controller.onCastExited(exitCode, startProc.stderrLines.join("\n"))
      startProc.stderrLines = []
    }
  }

  // Fallback UI for protocols without native in-panel discovery.
  Process {
    id: trayProc
    onExited: controller.trayLaunching = false
  }
}
