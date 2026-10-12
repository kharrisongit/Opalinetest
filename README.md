<div align="center">

<img src="source/utube-icon.png" width="128" alt="uTube app icon">

# uTube

**Your YouTube, your layout.**

A personal YouTube client for iPhone and iPad, maintained by **kharrison**.
Inline comments, a YouTube inbox, playful Home layouts, and playback controls you can make your own.

[![Latest release](https://img.shields.io/github/v/release/kharrisongit/utube?label=Download%20uTube&color=ed414b)](https://github.com/kharrisongit/utube/releases/latest)
[![AltStore source](https://img.shields.io/badge/AltStore-kharrison%20Apps-247c85)](#install-with-altstore)
![iOS 12+](https://img.shields.io/badge/iOS-12%2B-555555?logo=apple)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

</div>

uTube is an independently maintained **fork of [Opaline by verback2308](https://github.com/verback2308/Opaline)**. It builds on Opaline's native player with its own interface, features, artwork, and releases. The original project and its contributors are credited below.

## Make it yours

- **Four ways to browse.** Choose Shelf Rails, Plain Grid, **Wall**, or **Carousel**. Wall is a dense thumbnail canvas you can pan and pinch to zoom. Carousel puts videos in animated cards with muted previews and a Play button.
- **Keep watching while you browse.** The minimized player stays in charge. Carousel previews stay off while the main player is in use, AirPlay is connected, or the app is inactive.
- **Comments right where you watch.** Type a comment or reply in the video’s comments panel and tap **Send**. The composer stays in the list without opening a separate writing window.
- **Your YouTube inbox.** The bell opens notifications with **All** and **Replies** tabs, profile photos, video thumbnails, and replies inside the panel. Pull to refresh or load older notifications.
- **AirPlay within reach.** Connect from the Home toolbar or the video controls. Background audio and Picture in Picture are also available.
- **Choose your controls.** Show or hide AirPlay, speed, captions, Picture in Picture, repeat, and Audio Only in **Settings → Playback → Video controls**. Audio Only starts hidden.
- **Light by default.** Dark mode and other appearance choices remain available. The **History** tab also holds Downloads and Playlists.

uTube also keeps the foundation that makes Opaline useful: native iPhone and iPad playback, search, channels, subscriptions, playlists, Shorts, offline downloads, captions, audio tracks, SponsorBlock, and Return YouTube Dislike.

## Install with AltStore

**Requires iOS 12 or newer.** uTube is available through **kharrison Apps**, the AltStore Classic source for kharrison's personal apps and games. The same source also includes [The Last Dragonrider](https://github.com/kharrisongit/ember).

1. Open **AltStore → Sources → +**.
2. Paste this source URL:

   ```text
   https://raw.githubusercontent.com/kharrisongit/utube/main/source/apps.json
   ```

3. Add **kharrison Apps**, then install **uTube**.

Already added the source? Refresh it to see new releases. AltStore signs the app during installation; use your usual AltServer setup when needed.

**uTube now installs alongside Opaline.** Starting with **1.12.8**, uTube has its own app identifier (`com.kharrison.utube`). Install it as a new app from the source. Earlier uTube builds shared Opaline's identity; their settings, downloads, and sign-in stay with that older installation and do not transfer automatically. You can keep both apps.

### Other downloads

[Releases](https://github.com/kharrisongit/utube/releases/latest) include the **uTube IPA** for manual sideloading and **rootful/rootless `.deb` packages** for jailbroken devices. Use version **1.12.8 or newer** for the separate uTube app.

## Comments and notifications

Connect once through **Settings → Commenting account → Connect YouTube**. Choose your YouTube channel, then return to the comments or inbox. **No Google Cloud project or app registration is required.** This website connection is separate from the app's viewing sign-in.

The inbox refreshes inside uTube; it does not provide iOS push notifications. YouTube can change its website connection, so account features may occasionally need an update or a new sign-in. See [account and privacy details](NATIVE_COMMENTING.md).

Playback connects to YouTube and, for some playback sources, a configurable helper service. SponsorBlock and Return YouTube Dislike use their respective services. Signing in does not make activity anonymous to YouTube.

## Build from source

Use **macOS and Xcode**:

```bash
git clone https://github.com/kharrisongit/utube.git
cd utube
cp Config/Local.xcconfig.example Config/Local.xcconfig
open Opaline.xcodeproj
```

Set your development team in `Config/Local.xcconfig`, select the **Opaline** scheme, and build. The project and scheme retain their original internal names; the installed app is **uTube**. Release packaging is handled by [`make_ipa.sh`](make_ipa.sh) and the [build workflow](.github/workflows/build-release.yml).

## Bugs and ideas

[Open an issue in this repository](https://github.com/kharrisongit/utube/issues/new/choose). Include the uTube version, device, iOS version, and steps to reproduce. For playback problems, **Settings → Debug → Share Debug Log** can help with diagnosis. AirPlay and background behavior can vary by receiver and iOS version; include the receiver model when reporting a problem.

## Credits and license

- **[Opaline — verback2308 and contributors](https://github.com/verback2308/Opaline):** the original app and foundation of this fork.
- **kharrison:** uTube's direction, customization, artwork, and releases.
- [SponsorBlock](https://github.com/ajayyy/SponsorBlock) — community sponsor-segment data.
- [Return YouTube Dislike](https://github.com/Anarios/return-youtube-dislike) — community dislike data.
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — reference for YouTube playback behavior.
- [YouTubeLegacy](https://github.com/PoomSmart/YouTubeLegacy) — inspiration for older-device support.
- [YouTube.js](https://github.com/LuanRT/YouTube.js) — reference for website comments and notifications.

Licensed under the [GNU General Public License v3.0](LICENSE). Original copyright notices and attribution are retained. uTube is not affiliated with Google or YouTube.
