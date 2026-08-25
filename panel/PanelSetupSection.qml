import QtQuick
import qs.Ui
import qs.Commons
import "../FluxCastModel.js" as Model

// Pre-cast configuration: protocol, receiver list, and monitor picker.
Column {
  id: root
  required property var controller

  visible: controller.isSetupPhase
  width: parent.width
  spacing: Style.space(10)

  // Hide protocol switching while a scan is in flight to avoid stale device lists.
  Column {
    width: parent.width
    spacing: Style.space(6)
    visible: !controller.isScanning

    Text {
      width: parent.width
      text: "Protocol"
      color: controller.contentForeground
      opacity: 0.65
      font.family: controller.contentFontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Flow {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: controller.protocolOptions

        delegate: Button {
          selected: controller.selectedProtocol === modelData.id
          bordered: true
          foreground: controller.contentForeground
          text: modelData.label
          onClicked: {
            if (controller.selectedProtocol === modelData.id) return
            controller.selectedProtocol = modelData.id
            controller.persistSettings({ protocol: modelData.id })
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
        color: controller.contentForeground
        opacity: 0.65
        font.family: controller.contentFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      Item { width: Style.space(4); height: 1 }

      Button {
        iconText: "󰑐"
        tooltipText: controller.isScanning ? "Scanning…" : "Scan again"
        bordered: true
        foreground: controller.contentForeground
        iconSpinning: controller.isScanning
        opacity: controller.isScanning ? 0.6 : 1
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
          if (!controller.isScanning) controller.scan()
        }
      }
    }

    Column {
      width: parent.width
      spacing: Style.space(4)

      Repeater {
        model: controller.devices

        delegate: Button {
          width: parent.width
          leftAlign: true
          selected: Model.deviceKey(modelData) === controller.selectedDeviceKey
          bordered: true
          foreground: controller.contentForeground
          text: Model.deviceLabel(modelData)
          onClicked: controller.selectedDeviceKey = Model.deviceKey(modelData)
        }
      }

      Text {
        visible: controller.devices.length === 0
        width: parent.width
        text: controller.isScanning
          ? "Scanning for nearby TVs…"
          : (controller.nativeScanSupported
            ? "No receivers yet. Tap Find TVs to scan."
            : "Use the tray to discover DLNA or Chromecast devices.")
        color: controller.contentForeground
        opacity: 0.6
        font.family: controller.contentFontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  // Only show monitor selection when more than one Hyprland output exists.
  Column {
    visible: controller.canPickMonitor
    width: parent.width
    spacing: Style.space(6)

    Text {
      width: parent.width
      text: "Screen"
      color: controller.contentForeground
      opacity: 0.65
      font.family: controller.contentFontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Flow {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: controller.monitors

        delegate: Button {
          selected: Model.monitorKey(modelData) === controller.selectedMonitorKey
          bordered: true
          foreground: controller.contentForeground
          text: Model.monitorLabel(modelData)
          onClicked: {
            controller.selectedMonitorKey = Model.monitorKey(modelData)
            controller.persistSettings({ monitor: Model.monitorKey(modelData) })
          }
        }
      }
    }
  }
}
