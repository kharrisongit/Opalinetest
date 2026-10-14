uTube by kharrison, based on Opaline by verback2308.

- Fixed playback stops and videos failing to start when YouTube redirects a SABR stream to another media server. uTube now follows the redirect and retries the exact requested audio/video segment without resetting playback.
- Redirect handling preserves signed URLs and session state, supports simultaneous audio/video requests, and stops invalid redirects and redirect loops.
- Failed signature solves now move on to the next playback method instead of sending an unsolved URL and waiting for a 403 error.
- Added overall startup deadlines to the original four playback methods and cancellation of expired requests, so a stalled method cannot hold up fallback indefinitely while the app is running.
- Added regression checks for startup and mid-video redirects, concurrent requests, loops, invalid destinations, solver failures and fallback cancellation.

Includes the previous AirPlay format-selection, segment-identity and playback-position fixes. The shared kharrison Apps source and other app listings are unchanged by this release.
