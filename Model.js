.pragma library

// Public JPopsuki Radio endpoints (advertised on jpopsuki.eu/media.php).
var HOST = "http://jpopsuki.fm:8000"
var CENTOVA_INFO = "http://jpopsuki.fm:2199/rpc/jpopsuki/streaminfo.get"
var CENTOVA_PLS = "http://jpopsuki.fm:2199/tunein.php/jpopsuki/playlist.pls"
var MEDIA_PAGE = "http://jpopsuki.eu/media.php"
var PLAYER_TITLE = "JPopsuki Radio"
var GLYPH = "󰐹"
var USER_AGENT = "ofs.jradio/1.0.0 (Omarchy Quattro; +https://jpopsuki.eu/media.php)"

var MOUNTS = {
  stream: HOST + "/stream",
  autodj: HOST + "/autodj"
}

function streamUrl(preferMount) {
  var key = String(preferMount || "stream")
  return MOUNTS[key] || MOUNTS.stream
}

function truncate(text, maxLen) {
  var s = String(text || "").replace(/\s+/g, " ").trim()
  if (!s) return ""
  var n = Math.max(8, Number(maxLen) || 28)
  if (s.length <= n) return s
  return s.slice(0, Math.max(1, n - 1)) + "…"
}

function displayLine(artist, title) {
  var a = String(artist || "").trim()
  var t = String(title || "").trim()
  if (a && t) return a + " — " + t
  return t || a || ""
}

function emptyMeta() {
  return {
    online: false,
    station: PLAYER_TITLE,
    song: "",
    artist: "",
    title: "",
    album: "",
    imageUrl: "",
    listeners: 0,
    bitrate: "",
    mountpoint: "",
    tuneinUrl: "",
    raw: null
  }
}

function parseStreamInfo(text) {
  var meta = emptyMeta()
  if (!text) return meta
  var payload
  try {
    payload = JSON.parse(text)
  } catch (e) {
    return meta
  }
  var rows = payload && payload.data
  if (!rows || !rows.length) return meta
  var row = rows[0] || {}
  var track = row.track || {}

  meta.online = row.offline !== true && (row.serverstate === true || row.server === "Online")
  meta.station = String(row.title || PLAYER_TITLE)
  meta.song = String(row.song || row.rawmeta || "")
  meta.artist = String(track.artist || "")
  meta.title = String(track.title || "")
  if (!meta.artist && !meta.title && meta.song) {
    var parts = meta.song.split(" - ")
    if (parts.length >= 2) {
      meta.artist = parts[0].trim()
      meta.title = parts.slice(1).join(" - ").trim()
    } else {
      meta.title = meta.song
    }
  }
  meta.album = String(track.album || "")
  meta.imageUrl = String(track.imageurl || "")
  meta.listeners = Number(row.listeners || row.listenertotal || 0) || 0
  meta.bitrate = String(row.bitrate || "")
  meta.mountpoint = String(row.mountpoint || "")
  meta.tuneinUrl = String(row.tuneinurl || "")
  meta.raw = row
  return meta
}

function parseStatusLine(text) {
  // jradio-player status prints one JSON object.
  if (!text) return { playing: false, pid: 0, url: "", title: PLAYER_TITLE }
  try {
    var obj = JSON.parse(String(text).trim().split("\n").pop())
    return {
      playing: obj.playing === true,
      pid: Number(obj.pid) || 0,
      url: String(obj.url || ""),
      title: String(obj.title || PLAYER_TITLE)
    }
  } catch (e) {
    return { playing: false, pid: 0, url: "", title: PLAYER_TITLE }
  }
}
