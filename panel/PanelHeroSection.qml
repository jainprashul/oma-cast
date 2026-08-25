import QtQuick
import qs.Commons
import "../FluxCastModel.js" as Model

// Primary status row: state icon plus headline/detail from the controller.
Item {
  id: root
  required property var controller

  width: parent.width
  height: Math.max(heroIcon.implicitHeight, heroText.implicitHeight)

  Text {
    id: heroIcon
    text: Model.iconForState(controller.displayState)
    color: controller.contentForeground
    font.family: controller.contentFontFamily
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
      text: controller.statusHeadline
      color: controller.contentForeground
      font.family: controller.contentFontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      wrapMode: Text.WordWrap
      elide: Text.ElideRight
      maximumLineCount: 2
    }

    Text {
      width: parent.width
      text: controller.statusDetail
      color: controller.contentForeground
      opacity: 0.72
      font.family: controller.contentFontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      elide: Text.ElideRight
      maximumLineCount: 2
    }
  }
}
