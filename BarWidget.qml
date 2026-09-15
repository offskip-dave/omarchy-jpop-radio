import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Bar pill: play/stop on left click, now-playing panel on right click.
BarWidget {
  id: root
  moduleName: "ofs.jradio"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("ofs.jradio") : null
  readonly property string glyph: Model.GLYPH
  readonly property bool playing: service ? service.playing : false
  readonly property bool showTitle: {
    var v = root.setting("showTitle", true)
    return v === true || v === "true"
  }
  readonly property string label: {
    if (!service) return Model.PLAYER_TITLE
    if (!root.showTitle) return Model.PLAYER_TITLE
    return service.barLabel || Model.PLAYER_TITLE
  }
  readonly property string tooltip: service ? service.tooltipText : Model.PLAYER_TITLE
  readonly property color defaultForeground: bar ? bar.foreground : Color.foreground
  readonly property color iconColor: root.playing ? Color.accent : defaultForeground

  readonly property var verticalLines: {
    if (!root.vertical) return []
    var lines = [root.glyph]
    if (root.showTitle && root.label && root.label !== Model.PLAYER_TITLE) {
      var parts = String(root.label).split(" ")
      for (var i = 0; i < parts.length && lines.length < 4; i++)
        if (parts[i]) lines.push(parts[i])
    }
    return lines
  }

  function syncService() {
    if (root.service && "settings" in root.service)
      root.service.settings = root.settings
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePlayback() {
    if (root.service && root.service.toggle) root.service.toggle()
  }

  function refreshMeta() {
    if (root.service && root.service.refreshMeta) root.service.refreshMeta()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: { injectPanel(); syncService() }
  onServiceChanged: { injectPanel(); syncService() }

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
    target: "ofs.jradio"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function play(): void { if (root.service) root.service.start() }
    function stop(): void { if (root.service) root.service.stop() }
    function togglePlay(): void { root.togglePlayback() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : (root.showTitle ? root.glyph + " " + root.label : root.glyph)
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.5
    foreground: root.iconColor
    tooltipText: root.tooltip
    onPressed: function(b) {
      if (b === Qt.RightButton) root.togglePanel()
      else if (b === Qt.MiddleButton) root.refreshMeta()
      else root.togglePlayback()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData === root.glyph
            ? Style.font.icon
            : (modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize)
          color: button.foreground
        }
      }
    }
  }
}
