.pragma library

// Network policy:
// - Metadata and artwork fetches are HTTPS-only (--proto '=https').
// - Icecast has no working TLS; playback uses a fixed allowlist of mounts only
//   (never a URL from a remote response).

var PLAYER_TITLE = "JPopsuki Radio"
var GLYPH = "󰐹"
var USER_AGENT = "ofs.jradio/1.1.0 (Omarchy Quattro; +https://jpopsuki.eu/media.php)"
var MEDIA_PAGE = "https://jpopsuki.eu/media.php"

// Centova JSON over HTTPS (verified TLS). Broken/self-signed certs fail closed.
var CENTOVA_INFO = "https://jpopsuki.fm:2199/rpc/jpopsuki/streaminfo.get"

var MAX_META_BYTES = 65536
var MAX_ART_BYTES = 524288
var MAX_META_TIME = 8
var MAX_ART_TIME = 10
var MAX_ART_EDGE = 1024

var MAX_STATION = 80
var MAX_ARTIST = 120
var MAX_TITLE = 120
var MAX_ALBUM = 120
var MAX_SONG = 200
var MAX_BITRATE = 32
var MAX_ERROR = 200
var MAX_URL = 512
var MAX_PATH = 512
var MAX_LISTENERS = 1000000

// Playback allowlist only — never taken from streaminfo / playlist responses.
var STREAM_MOUNTS = {
  stream: "http://jpopsuki.fm:8000/stream",
  autodj: "http://jpopsuki.fm:8000/autodj"
}

var ART_HOST_SUFFIXES = [
  "lastfm.freetls.fastly.net",
  "last.fm",
  "www.last.fm"
]

function streamUrl(preferMount) {
  var key = String(preferMount || "stream")
  return STREAM_MOUNTS[key] || STREAM_MOUNTS.stream
}

function isAllowlistedStream(url) {
  var u = String(url || "")
  for (var key in STREAM_MOUNTS) {
    if (STREAM_MOUNTS[key] === u) return true
  }
  return false
}

function isHttpsUrl(url) {
  var u = String(url || "")
  if (u.length < 12 || u.length > MAX_URL) return false
  if (u.indexOf("https://") !== 0) return false
  if (/[\r\n\0]/.test(u)) return false
  return true
}

function hostOf(url) {
  var u = String(url || "")
  var m = /^https:\/\/([^\/:?#]+)/i.exec(u)
  return m ? String(m[1]).toLowerCase() : ""
}

function hostAllowed(host, suffixes) {
  var h = String(host || "").toLowerCase()
  if (!h || h.indexOf("..") !== -1) return false
  for (var i = 0; i < suffixes.length; i++) {
    var s = suffixes[i]
    if (h === s || h.endsWith("." + s)) return true
  }
  return false
}

function upgradeToHttps(url) {
  var u = String(url || "").trim()
  if (!u) return ""
  if (u.indexOf("https://") === 0) return u
  if (u.indexOf("http://") === 0) return "https://" + u.slice(7)
  return ""
}

function safeArtUrl(url) {
  var upgraded = upgradeToHttps(url)
  if (!isHttpsUrl(upgraded)) return ""
  if (!hostAllowed(hostOf(upgraded), ART_HOST_SUFFIXES)) return ""
  return upgraded.slice(0, MAX_URL)
}

function sanitizeText(value, maxLen) {
  var n = Math.max(1, Number(maxLen) || 80)
  var s = String(value === undefined || value === null ? "" : value)
  // Strip controls, delimiters used in rich text, and collapse whitespace.
  s = s.replace(/[\u0000-\u001f\u007f\u0080-\u009f]/g, "")
  s = s.replace(/[<>&`]/g, "")
  s = s.replace(/\s+/g, " ").trim()
  if (s.length > n) s = s.slice(0, n)
  return s
}

function clampInt(value, min, max, fallback) {
  var n = Number(value)
  if (!isFinite(n)) return fallback
  n = Math.floor(n)
  if (n < min) return min
  if (n > max) return max
  return n
}

function truncate(text, maxLen) {
  var s = sanitizeText(text, Math.max(8, Number(maxLen) || 28))
  var n = Math.max(8, Number(maxLen) || 28)
  if (s.length <= n) return s
  return s.slice(0, Math.max(1, n - 1)) + "…"
}

function displayLine(artist, title) {
  var a = sanitizeText(artist, MAX_ARTIST)
  var t = sanitizeText(title, MAX_TITLE)
  if (a && t) return sanitizeText(a + " — " + t, MAX_SONG)
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
    bitrate: ""
  }
}

function parseMetaJson(text) {
  if (!text) return null
  var raw = String(text)
  if (raw.length > MAX_META_BYTES) raw = raw.slice(0, MAX_META_BYTES)
  try {
    return JSON.parse(raw)
  } catch (e) {
    return null
  }
}

function rowIsOnline(row) {
  if (row.offline === true) return false
  if (row.serverstate === true) return true
  if (row.server === "Online") return true
  return false
}

function splitSongArtist(song) {
  var parts = String(song || "").split(" - ")
  if (parts.length < 2) return { artist: "", title: sanitizeText(song, MAX_TITLE) }
  return {
    artist: sanitizeText(parts[0], MAX_ARTIST),
    title: sanitizeText(parts.slice(1).join(" - "), MAX_TITLE)
  }
}

function textOr(value, fallback) {
  var s = sanitizeText(value, arguments.length > 2 ? arguments[2] : MAX_SONG)
  return s || fallback || ""
}

function fillMetaCore(meta, row, track) {
  meta.online = rowIsOnline(row)
  meta.station = textOr(row.title, PLAYER_TITLE, MAX_STATION) || PLAYER_TITLE
  meta.song = textOr(row.song || row.rawmeta, "", MAX_SONG)
  meta.artist = textOr(track.artist, "", MAX_ARTIST)
  meta.title = textOr(track.title, "", MAX_TITLE)
}

function fillMetaExtras(meta, row, track) {
  if (!meta.artist && !meta.title && meta.song) {
    var split = splitSongArtist(meta.song)
    meta.artist = split.artist
    meta.title = split.title
  }
  meta.album = textOr(track.album, "", MAX_ALBUM)
  meta.imageUrl = safeArtUrl(track.imageurl || "")
  meta.listeners = clampInt(row.listeners || row.listenertotal || 0, 0, MAX_LISTENERS, 0)
  meta.bitrate = textOr(row.bitrate, "", MAX_BITRATE)
}

function fillMetaTrack(meta, row) {
  var track = row.track || {}
  fillMetaCore(meta, row, track)
  fillMetaExtras(meta, row, track)
  return meta
}

function parseStreamInfo(text) {
  var meta = emptyMeta()
  var payload = parseMetaJson(text)
  if (!payload) return meta
  var rows = payload.data
  if (!rows || !rows.length) return meta
  return fillMetaTrack(meta, rows[0] || {})
}

function emptyStatus() {
  return {
    playing: false,
    pid: 0,
    url: "",
    title: PLAYER_TITLE,
    icyArtist: "",
    icyTitle: "",
    icySong: ""
  }
}

function parseStatusJson(text) {
  if (!text) return null
  var raw = String(text)
  if (raw.length > 8192) raw = raw.slice(0, 8192)
  try {
    return JSON.parse(raw.trim().split("\n").pop())
  } catch (e) {
    return null
  }
}

function statusUrl(obj) {
  var url = String(obj.url || "")
  if (url && !isAllowlistedStream(url)) return ""
  return url
}

function statusIcy(obj) {
  return {
    icyArtist: textOr(obj.icyArtist || obj.artist, "", MAX_ARTIST),
    icyTitle: textOr(obj.icyTitle || obj.trackTitle, "", MAX_TITLE),
    icySong: textOr(obj.icySong || obj.song, "", MAX_SONG)
  }
}

function statusFromObject(obj) {
  var icy = statusIcy(obj)
  return {
    playing: obj.playing === true,
    pid: clampInt(obj.pid, 0, 4194304, 0),
    url: statusUrl(obj),
    title: textOr(obj.title, PLAYER_TITLE, MAX_STATION) || PLAYER_TITLE,
    icyArtist: icy.icyArtist,
    icyTitle: icy.icyTitle,
    icySong: icy.icySong
  }
}

function parseStatusLine(text) {
  var obj = parseStatusJson(text)
  if (!obj) return emptyStatus()
  return statusFromObject(obj)
}

function artPathAllowed(path) {
  if (!path || path.indexOf("\0") !== -1) return false
  if (path.indexOf("..") !== -1) return false
  if (path.charAt(0) !== "/") return false
  if (path.length > MAX_PATH) return false
  // Only accept runtime-cache paths written by jradio-fetch.
  if (path.indexOf("/ofs-jradio/") === -1) return false
  return true
}

function parseArtResult(text) {
  if (!text) return ""
  var raw = String(text)
  if (raw.length > 2048) raw = raw.slice(0, 2048)
  try {
    var obj = JSON.parse(raw.trim().split("\n").pop())
    var path = String(obj.path || "")
    return artPathAllowed(path) ? path : ""
  } catch (e) {
    return ""
  }
}

function fileUrl(path) {
  var p = String(path || "")
  if (!p || p.charAt(0) !== "/") return ""
  return "file://" + p
}
