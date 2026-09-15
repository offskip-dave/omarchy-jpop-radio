# JPopsuki Radio for Omarchy Quattro

Tune into the public [JPopsuki Radio](http://jpopsuki.eu/media.php) Icecast
stream from the Omarchy bar. Playback runs through `mpv` + `mpv-mpris`, so
`omarchy.media` gets the usual play/pause controls and now-playing metadata.

Now-playing (artist, title, album art, listeners) is polled from Centova's
public streaminfo endpoint. This plugin only uses the advertised public radio
stream — it does not touch the invite-only JPopsuki tracker or TV VOD.

## Install

```bash
omarchy plugin add /home/ofs_dave/Development/arch-jradio --enable --yes
# or from a published git remote:
# omarchy plugin add https://github.com/you/arch-jradio.git --enable --yes
```

For local development without cloning:

```bash
ln -sfn /home/ofs_dave/Development/arch-jradio ~/.config/omarchy/plugins/ofs.jradio
omarchy-shell shell rescanPlugins
omarchy plugin enable ofs.jradio --section right
```

## Controls

| Input | Action |
| --- | --- |
| Left click bar | Play / stop the stream |
| Right click bar | Open now-playing panel |
| Middle click bar | Refresh metadata |

Panel shows station status, current track, Last.fm art when available, and
listener count.

## Requirements

- Omarchy Quattro (`omarchy-shell` / Quickshell plugins)
- `mpv` and `mpv-mpris` (stock on Omarchy)
- `curl` for metadata polls

## Stream mounts

Settings → Stream mount:

- `stream` (default) — matches Centova's published playlist
- `autodj` — same AutoDJ feed on the Icecast host

Both are `http://jpopsuki.fm:8000/<mount>` at 192 kbps MP3.

## Remove

```bash
~/.config/omarchy/plugins/ofs.jradio/jradio-player stop
omarchy plugin remove ofs.jradio --yes
```

## License

MIT
