# Experimental playback sources

Implemented in the uTube fork, based on Opaline's source/delivery design. No upstream submission has been made. Research checked October 12, 2026; YouTube can change availability independently of an app update.

## What is added

The default order remains visionOS byte ranges, visionOS SABR, TV SABR, and progressive 360p. Two **disabled by default** entries are appended to saved orders. Saved enabled choices are preserved. Enable and reorder them in Settings → Debug → Playback sources.

| Source | Different approach | Limits |
| --- | --- | --- |
| `web.hls` — Web · native HLS | Request a Safari-style WEB response, using the already-connected YouTube website account when available; validate the returned HLS playlist and hand its HTTPS URL directly to AVPlayer. | HLS is only returned for some sessions/videos. Quality is automatic, with the saved resolution preference passed to AVPlayer as a preference. Receiver behavior can differ. No promise of 1080p/4K. |
| `web.embedded.range` — Embedded web · byte ranges | Request WEB_EMBEDDED_PLAYER anonymously. Resolve the selected video/audio URL challenges with the existing JS solver, then use Opaline's SIDX-to-HLS delivery. Quality selection uses the existing adaptive-format picker. | Embedding must be allowed, clear compatible adaptive URLs must be present, and the CDN must accept them. This does not turn SABR-only responses into byte-range streams. |

Both use the existing player and AirPlay system; neither opens a browser or starts a second player. No new server, proxy, Google project, OAuth registration, or external dependency is introduced. Both routes use the existing on-device solver, with the existing configured remote fallback on failure/older iOS, when a returned URL carries a player challenge. Unchallenged HLS URLs go directly to the native player.

## Implementation details for reviewers

- Website configuration is fetched from the corresponding watch/embed page, with the timestamp and JS URL kept together. If necessary, the timestamp is read from that referenced script. A known web client version is a fallback only when the page omits it. TV signature timestamps are not reused.
- Player responses must be playable and belong to the requested video. Restricted responses and DRM license responses are rejected. No retry with an age/restriction override is performed.
- Embedded playback accepts explicit HTTPS googlevideo adaptive URLs, preserves signed query parameters (including existing client version/token/expiry), and changes only solved `n`/signature values. Formats with DRM metadata are excluded. Unsupported codecs continue to be filtered by the existing parser.
- Native HLS resolves a returned manifest `n` challenge (including `/n/…` path parameters), preserving the signed path and playlist suffix. It uses a direct HTTPS master/media playlist, leaving alternate audio groups intact. It does not wrap the master in a custom URL scheme for quality selection. AVPlayer remains responsible for actual stream readiness and media decoding; its normal failure path can advance the chain.
- The embedded range probe can reject a blocked CDN response without resetting the default visionOS visitor identity.
- Each experimental initial attempt has a 45-second overall deadline; its web requests have 15-second request timeouts. Release cancels loader requests. Chain generation checks ignore duplicate/late callbacks, cancelled requests, and completions after releasing the source. Already-running shared signature/SIDX work may finish, but cannot install its result after a timed-out attempt.
- HLS account cookies and SAPISID authorization remain inside the existing dedicated ephemeral, no-redirect commenting transport, and go only to the fixed YouTube player endpoint. Disconnecting/replacing the account invalidates pending account reads. Those headers never go to media URLs or the solver. Embedded requests and page preflights are anonymous and do not use the shared cookie jar. These playback methods are not anonymity from YouTube.

Main additions are `WebPlaybackProfile`, `WebPlayerConfiguration`, `WebPlaybackRequest`, `WebPlaybackLoader`, `NativeWebHLSSource`, and `WebRangeDelivery`. The existing source accepts an optional loader so its quality-selection and delivery code can be reused. `PlaybackAttemptState` guards completion races in the chain. The four original resolver implementations and solver endpoint are retained.

## Other ideas considered

| Idea | Decision |
| --- | --- |
| More Android/iPhone client profiles | Deferred. Upstream reports adaptive streams starting and then stopping around a minute for some identities. A successful `/player` response alone is not evidence of reliable playback. Platform-bound PO tokens cannot be reused interchangeably. |
| WEB SABR using the connected website account | Worth future investigation, but needs the correct WEB session/video-bound integrity-token lifecycle. The current TV token generator is not a drop-in substitute. No fabricated tokens or new third-party token service was added. |
| Self-hosted resolution service | Revisit when upstream publishes its supported server. Keep the working configured service for now. |
| Local caching/remuxing for AirPlay | Could improve delivery of already-authorized streams but cannot resolve a rejected player request; storage, background execution and receiver compatibility need a separate design. |

## Validation and device test guide

CI compiles the app and runs executable checks for page/JS configuration parsing, matching request profiles, credential-free baseline requests, response restrictions, media URL validation, signature query preservation, HLS validation, and actual fallback-chain timeout/cancellation/late-callback races. Existing comment, notification, AirPlay-policy and package-identity checks remain in place.

A public-video probe from the build environment received YouTube's `LOGIN_REQUIRED` bot check. **Live playback, quality and sustained AirPlay on these new paths are not verified from that environment.** These options are experiments until device results show otherwise. No account credentials were used for that probe.

To compare on a device:

1. Note the current source order. Enable one experimental entry and temporarily move it first. Other entries remain enabled so a failure can fall through.
2. Play a public embeddable video at least ten minutes long. Open playback statistics/debug log and confirm `web.hls` or `web.embedded.range` is the selected source; a fallback playing successfully does not prove the experiment worked.
3. Check sound, video, quality changes where available, seeking, captions, and resuming a partially watched video. Test an unavailable/non-embeddable video: it should fail over cleanly.
4. AirPlay to the target receiver, leave uTube for at least ten minutes, and return. Record device/iOS, receiver, selected source, quality, elapsed time and whether playback continued. Also check a minimized video while browsing.
5. Switch videos while a request is pending and toggle the account connection during an HLS request. No old response should replace the new video. Test a network interruption and recovery.
6. Restore the original four entries to the top. Keep experiments disabled if they are not useful for your videos/session.

Before sharing logs, remove signed media URLs, cookies, account/visitor IDs and other identifying data. For an upstream proposal, share code plus redacted device results, including failures and whether another source actually won.

## Primary references

- [yt-dlp PO Token Guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide): client-specific requirements, embedded restrictions and token binding.
- [yt-dlp YouTube client profiles](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/_base.py): Safari and embedded WEB identities; notes that HLS availability is session dependent.
- [yt-dlp manifest handling](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/_video.py): HLS path challenge resolution.
- [yt-dlp issue 17143](https://github.com/yt-dlp/yt-dlp/issues/17143): missing Safari HLS responses and removal from defaults. This is why these entries are opt-in.
- [Apple HTTP Live Streaming](https://developer.apple.com/documentation/http-live-streaming): native streaming platform.
- [Opaline](https://github.com/verback2308/Opaline): original playback architecture, solver, SABR and HLS implementations.
