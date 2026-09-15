import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Headless singleton: one metadata poller and one mpv session for all bars.
Item {
  id: root

  property var shell: null
  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property string preferMount: String(setting("preferMount", "stream") || "stream")
  readonly property bool showTitle: setting("showTitle", true) === true || setting("showTitle", true) === "true"
  readonly property string streamUrl: Model.streamUrl(preferMount)

  readonly property string helperPath: {
    var u = Qt.resolvedUrl("jradio-player").toString()
    return u.startsWith("file://") ? u.slice(7) : u
  }

  property bool playing: false
  property int playerPid: 0
  property string playerUrl: ""
  property bool playerBusy: false

  property bool online: false
  property string station: Model.PLAYER_TITLE
  property string song: ""
  property string artist: ""
  property string title: ""
  property string album: ""
  property string imageUrl: ""
  property int listeners: 0
  property string bitrate: ""
  property string lastError: ""
  property int metaFailures: 0

  readonly property string trackLine: Model.displayLine(artist, title) || song
  readonly property string barLabel: {
    if (!playing) return Model.PLAYER_TITLE
    if (!showTitle) return Model.PLAYER_TITLE
    var line = trackLine
    return line ? Model.truncate(line, 28) : Model.PLAYER_TITLE
  }
  readonly property string tooltipText: {
    var bits = [Model.PLAYER_TITLE]
    if (playing) bits.push("playing")
    else bits.push("stopped")
    if (trackLine) bits.push(trackLine)
    if (listeners > 0) bits.push(listeners + " listeners")
    return bits.join(" · ")
  }

  function applyMeta(meta) {
    if (!meta) return
    root.online = meta.online === true
    root.station = meta.station || Model.PLAYER_TITLE
    root.song = meta.song || ""
    root.artist = meta.artist || ""
    root.title = meta.title || ""
    root.album = meta.album || ""
    root.imageUrl = meta.imageUrl || ""
    root.listeners = Number(meta.listeners) || 0
    root.bitrate = meta.bitrate || ""
  }

  function applyPlayerStatus(status) {
    if (!status) return
    root.playing = status.playing === true
    root.playerPid = Number(status.pid) || 0
    root.playerUrl = status.url || ""
  }

  function refreshMeta() {
    if (metaProc.running) return
    metaProc.command = [
      "curl", "-fsS", "--max-time", "8",
      "-A", Model.USER_AGENT,
      Model.CENTOVA_INFO
    ]
    metaProc.running = true
  }

  function refreshPlayer() {
    if (statusProc.running) return
    statusProc.command = [root.helperPath, "status"]
    statusProc.running = true
  }

  function start() {
    runPlayer(["start", root.streamUrl])
  }

  function stop() {
    runPlayer(["stop"])
  }

  function toggle() {
    runPlayer(["toggle", root.streamUrl])
  }

  function runPlayer(args) {
    if (root.playerBusy || playerProc.running) return
    root.playerBusy = true
    root.lastError = ""
    var cmd = [root.helperPath]
    for (var i = 0; i < args.length; i++) cmd.push(args[i])
    playerProc.command = cmd
    playerProc.running = true
  }

  onPreferMountChanged: {
    if (root.playing && root.playerUrl && root.playerUrl !== root.streamUrl)
      root.start()
  }

  Process {
    id: metaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var meta = Model.parseStreamInfo(text)
        if (!meta || (!meta.song && !meta.artist && !meta.title && !meta.online)) {
          root.metaFailures++
          return
        }
        root.metaFailures = 0
        root.applyMeta(meta)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.trim()) root.lastError = text.trim().split("\n").pop()
      }
    }
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPlayerStatus(Model.parseStatusLine(text))
    }
  }

  Process {
    id: playerProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.applyPlayerStatus(Model.parseStatusLine(text))
        root.playerBusy = false
        root.refreshMeta()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.trim()) root.lastError = text.trim().split("\n").pop()
        root.playerBusy = false
      }
    }
    onExited: function(exitCode) {
      root.playerBusy = false
      if (exitCode !== 0 && !root.lastError)
        root.lastError = "jradio-player exited " + exitCode
    }
  }

  Timer {
    id: metaTimer
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshMeta()
  }

  Timer {
    id: statusTimer
    interval: 4000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshPlayer()
  }

  Component.onCompleted: {
    root.refreshMeta()
    root.refreshPlayer()
  }
}
