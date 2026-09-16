import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Now-playing popout for JPopsuki Radio.
Panel {
  id: root
  moduleName: "ofs.jradio"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("ofs.jradio") : null
  readonly property bool playing: service ? service.playing : false
  readonly property bool online: service ? service.online : false
  readonly property string station: service ? service.station : Model.PLAYER_TITLE
  readonly property string trackLine: service ? service.trackLine : ""
  readonly property string album: service ? service.album : ""
  readonly property string artSource: service ? service.artSource : ""
  readonly property int listeners: service ? service.listeners : 0
  readonly property string bitrate: service ? service.bitrate : ""
  readonly property string lastError: service ? service.lastError : ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color mutedForeground: Qt.darker(contentForeground, 1.45)

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function togglePlayback() {
    if (root.service && root.service.toggle) root.service.toggle()
  }

  function stopPlayback() {
    if (root.service && root.service.stop) root.service.stop()
  }

  function refreshMeta() {
    if (root.service && root.service.refreshMeta) root.service.refreshMeta()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(420))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === " " || t === "p" || t === "P") root.togglePlayback()
        else if (t === "s" || t === "S") root.stopPlayback()
        else if (t === "r" || t === "R") root.refreshMeta()
      }

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(12)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        Row {
          width: parent.width
          spacing: Style.space(12)

          Rectangle {
            id: artFrame
            width: Style.space(88)
            height: Style.space(88)
            radius: Style.space(6)
            color: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.08)
            clip: true

            // Only local file:// paths produced by jradio-fetch after validation.
            Image {
              id: artImage
              anchors.fill: parent
              source: root.artSource
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: false
              visible: root.artSource !== "" && status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !artImage.visible
              text: Model.GLYPH
              textFormat: Text.PlainText
              color: root.mutedForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.displayLarge
            }
          }

          Column {
            width: parent.width - artFrame.width - Style.space(12)
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              text: root.station || Model.PLAYER_TITLE
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              wrapMode: Text.NoWrap
            }

            Text {
              width: parent.width
              text: root.playing ? "On air" : (root.online ? "Online · stopped" : "Station offline?")
              textFormat: Text.PlainText
              color: root.playing ? Color.accent : root.mutedForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.6
            }

            Text {
              width: parent.width
              visible: root.trackLine !== ""
              text: root.trackLine
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              visible: root.album !== ""
              text: root.album
              textFormat: Text.PlainText
              color: root.mutedForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        Row {
          spacing: Style.space(16)

          Text {
            visible: root.listeners > 0
            text: root.listeners + " listening"
            textFormat: Text.PlainText
            color: root.mutedForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            visible: root.bitrate !== ""
            text: root.bitrate
            textFormat: Text.PlainText
            color: root.mutedForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          width: parent.width
          visible: root.lastError !== ""
          text: root.lastError
          textFormat: Text.PlainText
          color: Color.urgent
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }

        Row {
          spacing: Style.space(8)

          WidgetButton {
            bar: root.bar
            text: root.playing ? "Stop" : "Play"
            onPressed: function() { root.togglePlayback() }
          }

          WidgetButton {
            bar: root.bar
            text: "Refresh"
            onPressed: function() { root.refreshMeta() }
          }
        }

        Text {
          width: parent.width
          text: "Space play/stop · S stop · R refresh"
          textFormat: Text.PlainText
          color: root.mutedForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
