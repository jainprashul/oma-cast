import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "FluxCastModel.js" as Model

BarWidget {
  id: root
  moduleName: "oma-cast"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property string currentState: panelLoader.item ? panelLoader.item.currentState : "unavailable"
  readonly property string displayState: panelLoader.item ? panelLoader.item.displayState : currentState
  readonly property string currentTarget: panelLoader.item ? panelLoader.item.currentTarget : ""
  readonly property string currentProtocol: panelLoader.item ? panelLoader.item.currentProtocol : "wfd"
  readonly property int currentElapsedSeconds: panelLoader.item ? panelLoader.item.elapsedSeconds : 0
  readonly property bool visibleInBar: Model.barIconVisible(opened, displayState)

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item && typeof panelLoader.item.refresh === "function") panelLoader.item.refresh()
  }

  function scan() {
    if (panelLoader.item && typeof panelLoader.item.scan === "function") panelLoader.item.scan()
  }

  function start() {
    if (panelLoader.item && typeof panelLoader.item.start === "function") panelLoader.item.start()
  }

  function stop() {
    if (panelLoader.item && typeof panelLoader.item.stop === "function") panelLoader.item.stop()
  }

  function statusJson() {
    if (!panelLoader.item || typeof panelLoader.item.debugState !== "function") return "{\"ok\":false}"
    return panelLoader.item.debugState()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    if ("bar" in panelLoader.item) panelLoader.item.bar = root.bar
    if ("settings" in panelLoader.item) panelLoader.item.settings = root.settings
    if ("anchorItem" in panelLoader.item) panelLoader.item.anchorItem = button
    if ("hostWidget" in panelLoader.item) panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  visible: visibleInBar

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "oma-cast"

    function toggle(): void { root.toggle() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function scan(): void { root.scan() }
    function start(): void { root.start() }
    function stop(): void { root.stop() }
    function refresh(): void { root.refresh() }
    function status(): string { return root.statusJson() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.iconForState(root.displayState)
    active: root.displayState === "casting" || root.displayState === "connecting" || root.displayState === "scanning"
    tooltipText: Model.barTooltip(root.displayState, root.currentTarget, root.currentProtocol, root.currentElapsedSeconds)

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.toggle()
      } else if (buttonCode === Qt.RightButton) {
        if (root.currentState === "casting") root.stop()
        else root.toggle()
      } else if (buttonCode === Qt.MiddleButton) {
        root.refresh()
      }
    }
  }
}
