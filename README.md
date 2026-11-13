# webOS Home Screen Lab

Reclaim the home screen on an LG webOS 4.5, 6.x or 7.x TV you own: drop the ads, promos,
"Start a new experience" filler and unused tiles, put a full-screen photo
behind everything, and make the input tiles dark so they sit on it.

> Not affiliated with LG. For a TV you own. No exploit here, no warranty. See [NOTICE.md](NOTICE.md).

This is a customization guide for a TV you own. It has no exploit code. Rooting
is done with the public community tools linked in
[`docs/01-rooting.md`](docs/01-rooting.md), and everything in this repo runs
after the TV is already rooted.

## Tested TVs

| Model | Year / webOS | Firmware | RAM | UI resolution | Patch set | Notes |
|-------|--------------|----------|-----|---------------|-----------|-------|
| 43UP8000PUR | 2021 / webOS 6.5 | 03.51.16 | 1 GB | Not measured. The background is made at 1920x1080 and goes in `images/2k` and `images/4k` | `patches/` | The original set. Screenshots through the VNC Server app |
| 43UQ7070ZUD | 2022 / webOS 7.6 (webOS 22) | 04.60.90 | 1.3 GB | 1920x1080 on a 4K panel, so images load from `images/2k` | `patches/webos7/` | Stock home adds a "TV functions" shelf, which `01` removes. `05` also hides the "See User Guide" tile. Screenshots with the capture service need `SCREEN`, since `DISPLAY` comes back black. See [`docs/06-webos7.md`](docs/06-webos7.md). Patches `08`-`11` add the live Earth clock and bottom app row, see [`docs/09-earth-clock-and-layout.md`](docs/09-earth-clock-and-layout.md) |
| 43UP8000PUR | 2021 / webOS 6.5.3 | 03.53.45 | 1 GB (about 1070 MB usable) | 1920x1080 on a 4K panel, so images load from `images/2k` | `patches/webos6-03.53/` | Same model as the first row, newer firmware. `01` and `03` needed new context, and `05` also hides the "See User Guide" tile. The LG Channels row above the apps goes away only with *Recommendations on Home* off. See [`docs/07-webos6-03.53.md`](docs/07-webos6-03.53.md) |
| 32LM577BPUA | 2019 / webOS 4.5 ("webOS TV Lite") | 05.40.97 | 658 MB | 1920x1080 on an HD panel, so images load from `images/2k` | `patches/webos4.5/` | The full-screen home is `com.webos.app.fullhome`, so it uses `hooks/webos4.5/70-homeqml-k`. `01` also drops the "Trending now" row, and `05` also hides the "See User Guide" tile. VNC Server isn't supported, so screenshots come from the compositor. See [`docs/08-webos4.5.md`](docs/08-webos4.5.md) |

Other models use the same home app structure, but file names and image sizes
vary, so read your own files instead of pasting mine.

![home screen](assets/screenshot.jpg)


## What's here

| Path | What it is |
|------|-----------|
| `docs/01-rooting.md` | How people root LG TVs, with links to the public tools (no exploit here) |
| `docs/02-how-the-home-app-works.md` | The webOS home app is QML. The overlay and checkpoint trick that makes edits stick |
| `docs/03-the-edits.md` | Every change, what it does and why, keyed to the patches |
| `docs/04-going-further.md` | Building your own app, the screensaver, doing it across several TVs |
| `docs/05-apps-and-settings.md` | The homebrew apps we install and why, plus the privacy pass |
| `docs/06-webos7.md` | What changes on webOS 7 (webOS 22): ported patches, screen size, app notes |
| `docs/07-webos6-03.53.md` | What changes on webOS 6.5 firmware 03.53.45: ported patches and the LG Channels row |
| `docs/09-earth-clock-and-layout.md` | webOS 7: live Earth clock with weather, the app row at the bottom, compact input tiles, a new screensaver, a soundbar fix |
| `docs/08-webos4.5.md` | What changes on firmware 05.40.97 (webOS 4.5): the full-screen home app, ported patches, 658 MB of RAM, screenshots |
| `patches/` | One `git`-style patch per change, against LG's stock home QML (webOS 6.5) |
| `patches/webos7/` | The same patches ported to webOS 7 |
| `patches/webos6-03.53/` | The same patches for webOS 6.5 firmware 03.53.45 |
| `patches/webos4.5/` | The same patches ported to firmware 05.40.97, webOS 4.5 (`com.webos.app.fullhome`) |
| `hooks/70-homeqml-k` | Boot hook: bind-mounts the patched copy and relaunches home |
| `hooks/72-screensaver-k`, `hooks/80-soundbar-k`, `hooks/81-earthclock-k` | Boot hooks for the screensaver overlay, the soundbar fix and the Earth/weather fetcher |
| `scripts/earthfetch-k.sh`, `scripts/soundbar-k.sh` | The fetcher behind the Earth clock and the soundbar reconnect loop |
| `hooks/webos4.5/70-homeqml-k` | The same hook for firmware 05.x (webOS 4.5), where the full-screen home is `com.webos.app.fullhome` |
| `scripts/render_home_bg.py` | Turns the ESO Milky Way panorama into a TV-safe background (geometry is tuned to that image) |
| `scripts/deploy.sh` | Copies the overlay to the TV and applies it |

## The shape of it

LG's home screen is a QML app on a signed, read-only partition. You can't edit
it in place, but you can bind-mount a writable copy over it and force the app to
relaunch from your copy. A boot hook re-applies the mount on every power-on.
That's the whole mechanism. The rest is reading LG's QML and changing the right
lines.

[`docs/02-how-the-home-app-works.md`](docs/02-how-the-home-app-works.md) covers
the one real gotcha: webOS restores the home app from a frozen memory
checkpoint, so you have to delete the checkpoint or your edits stay invisible.

## Quick start (TV already rooted, SSH reachable)

```sh
# 1. Copy LG's stock home QML off the TV to ./stock-qml, then:
cd stock-qml
git init -q && git add -A && git commit -qm stock      # baseline to diff against
git apply ../patches/*.patch                            # webOS 6.x; on webOS 7 use ../patches/webos7/*.patch, on firmware 05.x ../patches/webos4.5/*.patch

# 2. Render the background. The rotation/crop are tuned for the 3840x1920 ESO
#    Milky Way panorama; for another photo, adjust the constants at the top.
python3 ../scripts/render_home_bg.py my_photo.jpg bg_space_SIZE.jpg
cp bg_space_1920.jpg UserInterfaceLayer/Components/images/2k/bg_space.jpg
cp bg_space_1920.jpg UserInterfaceLayer/Components/images/4k/bg_space.jpg

# 3. Push the copy to the TV and apply (see scripts/deploy.sh for the real thing)
```

Apply the patches one at a time and look at the screen after each. Match LG's
exact image dimensions, keep assets small (these TVs have 1 to 1.3 GB of RAM and
thrash on oversized images), and always keep LG's original QML so you can roll back.

## Safety / scope

- This modifies your own TV's UI. Nothing here targets anyone else's device.
- Keep a backup of the stock QML and your boot hooks. A bad QML edit black-screens
  the home app, and restoring the backup and relaunching fixes it.
- Don't let the TV auto-update. The public rooting tools include an update
  blocker for exactly this reason.
