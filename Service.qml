import QtQuick
import Quickshell
import "Model.js" as Model
import "omakit"

// Headless singleton: one metadata poller and one mpv session for all bars.
// Remote metadata/artwork always go through jradio-fetch (HTTPS + byte caps).
// Every helper starts through omakit Run (deadline + producer-side caps).
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

  // Absolute helper paths; Qt.resolvedUrl is what inspect resolves for Run.
  readonly property string helperPath: Qt.resolvedUrl("jradio-player").toString().replace("file://", "")
  readonly property string fetchPath: Qt.resolvedUrl("jradio-fetch").toString().replace("file://", "")

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
  property string playerAction: "status"

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

  // Session vars mpv needs for audio + MPRIS; fetch helpers use the closed base.
  readonly property var playerEnvironment: ({
    DBUS_SESSION_BUS_ADDRESS: Quickshell.env("DBUS_SESSION_BUS_ADDRESS"),
    WAYLAND_DISPLAY: Quickshell.env("WAYLAND_DISPLAY"),
    DISPLAY: Quickshell.env("DISPLAY"),
    XDG_SESSION_TYPE: Quickshell.env("XDG_SESSION_TYPE")
  })

  function applyMeta(meta) {
    if (!meta) return
    applyMetaOnline(meta)
    applyMetaTrack(meta)
    applyMetaArt(meta)
  }

  function applyMetaOnline(meta) {
    var hasTrack = !!(meta.song || meta.artist || meta.title)
    // HTTPS Centova currently fails closed (bad cert). Do not clobber ICY
    // metadata or flip the station "offline" while we are already playing.
    if (!hasTrack && meta.online !== true) {
      if (!root.playing) root.online = false
      return
    }
    root.online = meta.online === true
  }

  function applyMetaStation(meta) {
    root.station = Model.sanitizeText(meta.station || Model.PLAYER_TITLE, Model.MAX_STATION) || Model.PLAYER_TITLE
    root.listeners = Model.clampInt(meta.listeners, 0, Model.MAX_LISTENERS, 0)
    if (meta.bitrate) root.bitrate = Model.sanitizeText(meta.bitrate, Model.MAX_BITRATE)
  }

  function applyMetaFields(meta) {
    if (meta.song) root.song = Model.sanitizeText(meta.song, Model.MAX_SONG)
    if (meta.artist) root.artist = Model.sanitizeText(meta.artist, Model.MAX_ARTIST)
    if (meta.title) root.title = Model.sanitizeText(meta.title, Model.MAX_TITLE)
    if (meta.album) root.album = Model.sanitizeText(meta.album, Model.MAX_ALBUM)
  }

  function applyMetaTrack(meta) {
    if (meta.online !== true && !(meta.song || meta.artist || meta.title)) return
    applyMetaStation(meta)
    applyMetaFields(meta)
  }

  function applyMetaArt(meta) {
    var nextArt = Model.safeArtUrl(meta.imageUrl || "")
    root.imageUrl = nextArt
    if (!nextArt) return
    if (nextArt !== root.pendingArtUrl) root.fetchArt(nextArt)
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

  function runFailure(result, label) {
    var detail = result.stderr || result.reason || result.state
    if (detail) root.setError(label + ": " + detail)
  }

  function refreshMeta() {
    if (metaRun.running) return
    metaRun.start()
  }

  function fetchArt(url) {
    var safe = Model.safeArtUrl(url)
    if (!safe || artRun.running) return
    root.pendingArtUrl = safe
    artRun.start()
  }

  function refreshPlayer() {
    if (statusRun.running) return
    statusRun.start()
  }

  function start() {
    runPlayer("start")
  }

  function stop() {
    runPlayer("stop")
  }

  function toggle() {
    runPlayer("toggle")
  }

  function runPlayer(action) {
    if (root.playerBusy || playerRun.running) return
    root.playerBusy = true
    root.lastError = ""
    root.playerAction = action
    playerRun.start()
  }

  onPreferMountChanged: {
    if (root.playing && root.playerUrl && root.playerUrl !== root.streamUrl)
      root.start()
  }

  Run {
    id: metaRun
    command: [root.fetchPath, "meta"]
    deadlineMs: 15000
    maxBytes: 131072
    keepBytes: 65536
    onFinished: result => {
      if (result.state !== "ok") {
        root.metaFailures++
        root.runFailure(result, "meta")
        return
      }
      var meta = Model.parseStreamInfo(result.stdout)
      if (!meta) {
        root.metaFailures++
        return
      }
      root.metaFailures = 0
      root.applyMeta(meta)
    }
  }

  Run {
    id: artRun
    command: [root.fetchPath, "art", root.pendingArtUrl]
    deadlineMs: 20000
    maxBytes: 8192
    keepBytes: 2048
    onFinished: result => {
      if (result.state !== "ok") {
        root.pendingArtUrl = ""
        root.artPath = ""
        return
      }
      var path = Model.parseArtResult(result.stdout)
      root.artPath = path
      if (!path) root.pendingArtUrl = ""
    }
  }

  Run {
    id: statusRun
    command: [root.helperPath, "status"]
    deadlineMs: 8000
    maxBytes: 16384
    keepBytes: 8192
    environment: root.playerEnvironment
    onFinished: result => {
      if (result.state !== "ok") return
      root.applyPlayerStatus(Model.parseStatusLine(result.stdout))
    }
  }

  Run {
    id: playerRun
    // Binding picks start/stop/toggle + stream URL at start() time.
    command: root.playerAction === "stop"
      ? [root.helperPath, "stop"]
      : [root.helperPath, root.playerAction, root.streamUrl]
    deadlineMs: 20000
    maxBytes: 16384
    keepBytes: 8192
    environment: root.playerEnvironment
    onFinished: result => {
      root.playerBusy = false
      if (result.state !== "ok") {
        root.runFailure(result, "player")
        return
      }
      root.applyPlayerStatus(Model.parseStatusLine(result.stdout))
      root.refreshMeta()
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
