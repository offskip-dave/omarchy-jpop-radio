def clean($n):
  if type != "string" then ""
  else gsub("[\\u0000-\\u001f\\u007f]"; "") | gsub("[<>&`]"; "") | gsub("\\s+"; " ") | .[0:$n] end;
.data[0] as $r
| ($r.track // {}) as $t
| {
    type: "result",
    data: [{
      title: ($r.title | clean(80)),
      song: (($r.song // $r.rawmeta // "") | clean(200)),
      track: {
        artist: (($t.artist // "") | clean(120)),
        title: (($t.title // "") | clean(120)),
        album: (($t.album // "") | clean(120)),
        imageurl: ((if ($t.imageurl | type) == "string" then $t.imageurl else "" end) | clean(512))
      },
      listeners: (
        (($r.listeners // $r.listenertotal // 0) | tonumber? // 0)
        | if . < 0 then 0 elif . > 1000000 then 1000000 else floor end
      ),
      bitrate: (($r.bitrate // "") | clean(32)),
      offline: ($r.offline == true),
      serverstate: ($r.serverstate == true),
      server: (($r.server // "") | clean(32))
    }]
  }
