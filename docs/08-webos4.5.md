# webOS 4.5 on firmware 05.40.97

The fourth TV is a 32LM577BPUA, a 2019 model on software 05.40.97. The
software version starts with 05, but the OS is webOS 4.5: it reports itself as
"webOS TV Lite", release 4.10.2 (`goldilocks2`). The folders are named
`webos4.5` after the OS. It's the smallest TV here: 658 MB of RAM.
The same idea works (overlay, checkpoint delete, relaunch), but on this
firmware it has to point at a different app. The ported patches are in [`../patches/webos4.5`](../patches/webos4.5), one file per
step, same names as the 6.5 set, and the boot hook is
[`../hooks/webos4.5/70-homeqml-k`](../hooks/webos4.5/70-homeqml-k).

## Two home apps

This firmware ships two home apps:

- `com.webos.app.home` is the old launcher bar, the row of slanted tiles that
  slides up over whatever is playing.
- `com.webos.app.fullhome` is the full-screen home, the same QML app as the
  webOS 6 home. On this TV it's the default: the general settings have
  `defaultApps.home` set to `com.webos.app.fullhome` and `homeAutoLaunchMode`
  set to `full`, so the Home button opens it.

The patches go on `fullhome`. Its QML lives at
`/usr/palm/applications/com.webos.app.fullhome/qml` and has the same layout as
the 6.5 home (`UserInterfaceLayer/`, `Interfaces/`, `Model/`, ...), so every
file the patches touch is where you'd expect it. The hook in `hooks/webos4.5/` is
`hooks/70-homeqml-k` with the app id changed to `com.webos.app.fullhome`, for
the mount, the checkpoint dirs, the process it kills and the app it launches.
`scripts/deploy.sh` still points at `com.webos.app.home`, so on this TV copy
the overlay and the hook by hand (or change the two paths in the script).

## What the stock home looks like

Out of the box it shows a "Start a new experience with LG webOS" hero, a "Free
on LG Channels" row with a Recent Input tile at the front, the apps, and a
connection shelf with Home Dashboard and Connection Guide tiles.

## Differences from 6.5, by patch

- `01`: the ad request is `requestRecommendedSponsoredAdData()`, as on webOS 7,
  and the early `return` goes in the same place. `MainView.qml` doesn't make
  any of the three calls the 6.5 patch comments out. Here the sponsored
  ad request is in `Hero.qml` (`initialize()`), `makeAdBanner()` is in
  `UIController.qml` (and only runs on WEE models), and
  `updateContentRecommendationShelf()` doesn't exist. `01` comments out the
  first two where they are.
  With the shelf list switched to the default set, the LG Channels row turned
  into an empty "Trending now" row, still with the Recent Input tile at the
  front. That's the recommended shelf (`HOME_SH_RECOMMENDED`). It stays in the
  list here even with *Home Promotion* off, because the default set only drops
  server shelves when the TV is offline or the terms aren't accepted. So `01`
  also filters that one shelf out in `_filterShelfItem()` in `ShelfList.js`.
  After that, the apps sit right under the background, as on the other TVs.
- `02`: the same one-line change in `SystemProperties.qml`. It changes nothing
  you can see on this TV, because the hero here is the filler guide, which
  `04` hides.
- `03`: the cover rectangles look like webOS 7 (`styleSheet.screen.bgColor`,
  and the banner's opacity check includes `networkConnected`). Same fix: one
  `Image` behind everything, both covers transparent, banner opacity `0`.
- `04`, `06` and `07`: the 6.5 patches apply as they are.
- `05`: the shelf is built from `activateItems` and `inActivateItems` instead
  of one `tempArray`, so the filter goes after that line. This firmware also adds a
  "See User Guide" tile (type `"guide"`), so `05` drops it too, as on webOS 7.

## Screen and image sizes

The panel is a 32-inch HD panel, but the UI is drawn at 1920x1080: the home
process has `STARFISH_SCREEN_WIDTH=1920` and `STARFISH_SCREEN_HEIGHT=1080`, and
the framebuffer reports 1920x2160 (two 1080-line buffers). `is4K` is false, so
images load from `images/2k/`. The background is rendered at 1920x1080 (about
770 KB) and copied to both `2k/` and `4k/`.

## Living with 658 MB of RAM

On a running TV, `free` shows about 190 MB available and 200 to 300 MB of swap
in use. What helped:

- Keep the background under 1 MB. The `Image` caps `sourceSize` at 1920x1080,
  so the decoded image is about 8 MB, whatever the file size.
- Build the overlay on the TV (`cp -a` the stock tree, about 22 MB), then push
  only the files you changed. See [`06-webos7.md`](06-webos7.md).
- `fullhome` runs at about 21 MB when it's restored from its checkpoint and
  about 75 MB after a fresh launch. Relaunch it once per change and check
  `MemAvailable` in `/proc/meminfo` before the next one.
- Don't keep services you don't need running. The VNC server (below) doesn't
  work here, so it isn't started at boot.

## Screenshots

There's no `com.webos.service.capture` on this TV, and the VNC Server app
doesn't start (see below). The compositor can capture the screen instead:

```sh
luna-send -n 1 luna://com.webos.surfacemanager/captureCompositorOutput \
  '{"output":"/tmp/cap.png","format":"PNG"}'
```

It reports `1920x1080`, but the file it writes is 1280x720. That's enough to
check a change. `luna-send` prints nothing without a TTY, so use `ssh -tt`.

### VNC Server

`org.webosbrew.vncserver` 1.0.3 installs fine through the Homebrew Channel
install service (the `.ipk` URL and sha256 are in the webosbrew repo listing;
check the hash yourself):

```sh
luna-send -i luna://org.webosbrew.hbchannel.service/install \
  '{"id":"org.webosbrew.vncserver","ipkUrl":"<release .ipk url>","ipkHash":"<sha256>","subscribe":true}'
```

But `start` fails with `"Startup failed"`, `errorCode` `-4`. In the VNC
server's source, `-4` means setting up input failed. It creates its uinput
device, then calls LG's input manager (`IM_RequestToCheckInput()` in
`libim`), and that call fails on this firmware. Screen capture isn't the
problem. Each failed start leaves one more uinput device behind until the
service exits. So don't retry it in a loop. The app stays installed and its
launcher icon is hidden by `06`.

## Apps and the privacy pass

- App Update Blocker's service didn't answer on this TV, so its domains were
  never added. A boot hook adds its list to `/etc/hosts` from the shell
  instead. Its file name starts with `zz` so it runs after Life's Good Without
  Spying has mounted its hosts file:

  ```sh
  #!/bin/sh
  # /var/lib/webosbrew/init.d/zz-updateblock
  L=/media/developer/apps/usr/palm/services/org.webosbrew.appupdateblocker.service/lg_update_domains.txt
  [ -f "$L" ] || exit 0
  grep -q '^# LG app update domains' /etc/hosts && exit 0
  { echo; echo '# LG app update domains'; sed 's/^/127.0.0.1 /' "$L"; } >> /etc/hosts
  ```

- Life's Good Without Spying, YouTube AdFree and the settings pass work as on
  the other TVs, with *Ads & ACR* and *LG service platform* off for HBO Max
  (see [`05-apps-and-settings.md`](05-apps-and-settings.md)).
- High load after a day: with Life's Good Without Spying's voice option on, the
  TV sat at a load of about 9. LG's `livepick` service was exiting and being
  restarted every second or so. Each new copy asked the voice stub for
  `getRecognitionStatus`, which the stub doesn't answer. The stub's `node`
  process was using most of a CPU and holding about 2900 sockets. After a
  reboot `livepick` stayed up and the loop didn't come back. Our guess (not
  confirmed) is that it started because the voice option was turned on while
  the TV was running, so reboot once after you enable it. If the load climbs,
  look for repeated `livepick main process ended, respawning` lines in
  `dmesg`.

## Power cycle

After a full reboot, everything came back: the overlay (checksums match), the
background and patches, key-only SSH, the update blocker entries, the Life's
Good Without Spying hosts file, and telnet stayed off. The TV didn't boot into
the Homebrew Channel's failsafe mode.
