import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Headless singleton: one metadata poller and one mpv session for all bars.
// Remote metadata/artwork always go through jradio-fetch (HTTPS + byte caps).
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
  readonly property string fetchPath: {
    var u = Qt.resolvedUrl("jradio-fetch").toString()
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
  property string artPath: ""
  property int listeners: 0
  property string bitrate: ""
  property string lastError: ""
  property int metaFailures: 0
  property string pendingArtUrl: ""

  readonly property string trackLine: Model.displayLine(artist, title) || song
  readonly property string artSource: Model.fileUrl(artPath)
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
    if (trackLine) bits.push(Model.sanitizeText(trackLine, Model.MAX_SONG))
    if (listeners > 0) bits.push(listeners + " listeners")
    return bits.join(" · ")
  }

  function applyMeta(meta) {
    if (!meta) return

    var hasTrack = !!(meta.song || meta.artist || meta.title)
    // HTTPS Centova currently fails closed (bad cert). Do not clobber ICY
    // metadata or flip the station "offline" while we are already playing.
    if (!hasTrack && meta.online !== true) {
      if (!root.playing) root.online = false
    } else {
      root.online = meta.online === true
      root.station = Model.sanitizeText(meta.station || Model.PLAYER_TITLE, Model.MAX_STATION) || Model.PLAYER_TITLE
      if (meta.song) root.song = Model.sanitizeText(meta.song, Model.MAX_SONG)
      if (meta.artist) root.artist = Model.sanitizeText(meta.artist, Model.MAX_ARTIST)
      if (meta.title) root.title = Model.sanitizeText(meta.title, Model.MAX_TITLE)
      if (meta.album) root.album = Model.sanitizeText(meta.album, Model.MAX_ALBUM)
      root.listeners = Model.clampInt(meta.listeners, 0, Model.MAX_LISTENERS, 0)
      if (meta.bitrate) root.bitrate = Model.sanitizeText(meta.bitrate, Model.MAX_BITRATE)
    }

    var nextArt = Model.safeArtUrl(meta.imageUrl || "")
    root.imageUrl = nextArt
    if (!nextArt) {
      // Keep existing validated art until a replacement URL arrives.
    } else if (nextArt !== root.pendingArtUrl) {
      root.fetchArt(nextArt)
    }
  }

  function mergeIcy(status) {
    if (!status) return
    if (status.icyArtist)
      root.artist = Model.sanitizeText(status.icyArtist, Model.MAX_ARTIST)
    if (status.icyTitle)
      root.title = Model.sanitizeText(status.icyTitle, Model.MAX_TITLE)
    if (status.icySong && !root.title && !root.artist)
      root.song = Model.sanitizeText(status.icySong, Model.MAX_SONG)
  }

  function applyPlayerStatus(status) {
    if (!status) return
    root.playing = status.playing === true
    root.playerPid = Model.clampInt(status.pid, 0, 4194304, 0)
    root.playerUrl = Model.isAllowlistedStream(status.url) ? status.url : ""
    if (root.playing) root.mergeIcy(status)
  }

  function setError(text) {
    root.lastError = Model.sanitizeText(text, Model.MAX_ERROR)
  }

  function refreshMeta() {
    if (metaProc.running) return
    // Helper writes a size-capped HTTPS body and prints a projected JSON object.
    metaProc.command = [root.fetchPath, "meta"]
    metaProc.running = true
  }

  function fetchArt(url) {
    var safe = Model.safeArtUrl(url)
    if (!safe || artProc.running) return
    root.pendingArtUrl = safe
    artProc.command = [root.fetchPath, "art", safe]
    artProc.running = true
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
        var text = String(this.text || "")
        if (text.length > Model.MAX_META_BYTES) {
          root.metaFailures++
          root.setError("metadata response too large")
          return
        }
        var meta = Model.parseStreamInfo(text)
        if (!meta) {
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
        var err = String(this.text || "")
        if (err.length > 2048) err = err.slice(0, 2048)
        if (err.trim()) root.setError(err.trim().split("\n").pop())
      }
    }
  }

  Process {
    id: artProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var text = String(this.text || "")
        if (text.length > 2048) text = text.slice(0, 2048)
        var path = Model.parseArtResult(text)
        root.artPath = path
        if (!path) root.pendingArtUrl = ""
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Art failures stay silent in the UI; drop the pending URL so we retry later.
        root.pendingArtUrl = ""
        root.artPath = ""
      }
    }
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var text = String(this.text || "")
        if (text.length > 8192) text = text.slice(0, 8192)
        root.applyPlayerStatus(Model.parseStatusLine(text))
      }
    }
  }

  Process {
    id: playerProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var text = String(this.text || "")
        if (text.length > 8192) text = text.slice(0, 8192)
        root.applyPlayerStatus(Model.parseStatusLine(text))
        root.playerBusy = false
        root.refreshMeta()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(this.text || "")
        if (err.length > 2048) err = err.slice(0, 2048)
        if (err.trim()) root.setError(err.trim().split("\n").pop())
        root.playerBusy = false
      }
    }
    onExited: function(exitCode) {
      root.playerBusy = false
      if (exitCode !== 0 && !root.lastError)
        root.setError("jradio-player exited " + exitCode)
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
