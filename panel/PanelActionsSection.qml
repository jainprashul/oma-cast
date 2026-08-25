import QtQuick
import qs.Ui
import qs.Commons

// Primary CTA (scan / start / stop) plus tray, log, and refresh shortcuts.
Column {
  id: root
  required property var controller

  width: parent.width
  spacing: Style.space(12)

  Button {
    width: parent.width
    leftAlign: true
    bordered: true
    active: controller.isLiveSession
    selected: controller.isLiveSession
    foreground: controller.isLiveSession ? Color.urgent : controller.contentForeground
    text: controller.primaryLabel
    opacity: controller.primaryEnabled ? 1 : 0.45
    onClicked: controller.primaryAction()
  }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Button {
      visible: controller.launchTrayFallback
      text: "Tray"
      bordered: true
      foreground: controller.contentForeground
      onClicked: controller.launchTray()
    }

    Button {
      text: "Log"
      bordered: true
      foreground: controller.contentForeground
      tooltipText: "Open the FluxCast session log"
      onClicked: controller.openLog()
    }

    Button {
      visible: !controller.isLiveSession
      text: "Refresh"
      bordered: true
      foreground: controller.contentForeground
      iconText: "󰑐"
      iconSpinning: controller.doctorInFlight || controller.monitorsInFlight
      opacity: controller.doctorInFlight || controller.monitorsInFlight ? 0.7 : 1
      tooltipText: "Reload FluxCast diagnostics and displays"
      onClicked: controller.refresh()
    }
  }
}
