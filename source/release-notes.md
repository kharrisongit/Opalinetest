Playback recovery and YouTube verification

- Stop old playback attempts before refreshing a rejected visitor session. Late responses can no longer restore the discarded identity.
- Retry a confirmed bot check once with a fresh identity, with a shared cooldown instead of repeated identity changes.
- Preserve the reason playback methods failed. Account restrictions, unavailable videos and transport failures no longer count as bot checks; HTTP 429 pauses further requests.
- Refresh rejected proof-of-origin tokens using the correct client and binding, including bypassing the provider cache. Ignore late invalidated mints and reject failed provider responses.
- Add a visible Verify with YouTube screen after refused playback and in Settings > Playback and Debug. Complete any check yourself, then choose Retry playback to import the anonymous visitor session. Google account and commenting credentials remain untouched.

Browser verification is experimental: a successful browser session may still be refused by native playback or AirPlay.
