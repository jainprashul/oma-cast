import QtQuick
import qs.Commons

// Recovery hint shown only while the controller is in the error display state.
Rectangle {
  id: root
  required property var controller

  visible: controller.lastError !== "" && controller.displayState === "error"
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
      text: controller.lastErrorHint !== "" ? controller.lastErrorHint : "Try scanning again or inspect the FluxCast log."
      color: controller.contentForeground
      opacity: 0.85
      font.family: controller.contentFontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }
}
