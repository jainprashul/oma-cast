import QtQuick
import qs.Ui
import qs.Commons

// Scrollable panel shell. Sections are ordered by session phase:
// hero status → errors → live session → setup → actions.
KeyboardPanel {
  id: panel
  required property var controller

  anchorItem: controller.anchorItem
  owner: controller.hostWidget || controller
  bar: controller.bar
  open: controller.opened
  focusTarget: keyCatcher
  contentWidth: panel.fittedContentWidth(Style.space(400))
  contentHeight: panel.fittedContentHeight(panelScroll.contentHeight, Style.space(520))

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    onCloseRequested: controller.close()
    onTabRequested: function(direction) { controller.switchPanel(direction) }

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

        PanelHeroSection { controller: panel.controller }
        PanelErrorSection { controller: panel.controller }
        PanelLiveSessionSection { controller: panel.controller }
        PanelSetupSection { controller: panel.controller }

        PanelSeparator {
          width: parent.width
          foreground: panel.controller.contentForeground
        }

        PanelActionsSection { controller: panel.controller }
      }
    }
  }
}
