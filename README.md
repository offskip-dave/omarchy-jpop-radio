# JPopsuki Radio for Omarchy Quattro

Tune into the public [JPopsuki Radio](https://jpopsuki.eu/media.php) Icecast
stream from the Omarchy bar. Playback runs through `mpv` + `mpv-mpris`, so
`omarchy.media` gets the usual play/pause controls and now-playing metadata.

This plugin only uses the advertised public radio stream — it does not touch
the invite-only JPopsuki tracker or TV VOD.

## Security

- **Metadata & artwork** are fetched with `jradio-fetch` over **HTTPS only**
  (`--proto '=https'`), with hard byte/time ceilings. Bodies are projected
  through `jq` before QML sees them.
- **Artwork** is downloaded to `$XDG_RUNTIME_DIR/ofs-jradio/art/`, validated
  (JPEG/PNG/WebP, max 512 KiB, max 1024×1024) with Pillow, then shown as a
  local `file://` path. Remote URLs are never bound to `Image`.
- **Playback** is limited to a fixed Icecast allowlist. The station does not
  currently offer a working TLS stream; URLs from metadata responses are never
  used for playback.
- Remote strings are sanitized and rendered with `textFormat: Text.PlainText`.

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

Panel shows station status, current track, validated local art when available,
and listener count.

## Requirements

- Omarchy Quattro (`omarchy-shell` / Quickshell plugins)
- `mpv` and `mpv-mpris` (stock on Omarchy)
- `curl`, `jq`, `socat`, `python` + Pillow (for art validation)

## Stream mounts

Settings → Stream mount:

- `stream` (default) — allowlisted `http://jpopsuki.fm:8000/stream`
- `autodj` — allowlisted `http://jpopsuki.fm:8000/autodj`

Both are 192 kbps MP3. Icecast TLS is not available from the station today.

## Remove

```bash
~/.config/omarchy/plugins/ofs.jradio/jradio-player stop
omarchy plugin remove ofs.jradio --yes
```

## License

MIT
