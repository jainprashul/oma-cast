import QtQuick
import qs.Commons
import "../FluxCastModel.js" as Model

// Active cast summary: target, output, protocol, and connect/elapsed status.
Rectangle {
  id: root
  required property var controller

  visible: controller.isLiveSession
  width: parent.width
  radius: Style.space(8)
  color: Qt.rgba(controller.contentForeground.r, controller.contentForeground.g, controller.contentForeground.b, 0.06)
  border.color: Qt.rgba(controller.contentForeground.r, controller.contentForeground.g, controller.contentForeground.b, 0.14)
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
        color: controller.contentForeground
        font.family: controller.contentFontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        width: parent.width - Style.space(24)
        spacing: 1

        Text {
          width: parent.width
          text: controller.currentTarget !== "" ? controller.currentTarget : "Receiver"
          color: controller.contentForeground
          font.family: controller.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: (controller.currentMonitor !== "" ? controller.currentMonitor : "Display")
            + " · " + Model.protocolLabel(controller.currentProtocol)
          color: controller.contentForeground
          opacity: 0.7
          font.family: controller.contentFontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    Text {
      visible: controller.currentState === "connecting"
      width: parent.width
      text: "Connecting…"
      color: Color.accent
      font.family: controller.contentFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      visible: controller.currentState === "casting"
      width: parent.width
      text: Model.formatElapsed(controller.elapsedSeconds)
      color: Color.accent
      font.family: controller.contentFontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
  }
}
