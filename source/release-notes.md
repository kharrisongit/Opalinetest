uTube by kharrison, based on Opaline by verback2308.

- Native comment editor and replies in videos and Shorts. Tap **Write a comment** or **Reply**, choose your connected YouTube channel, then **Post**.
- Commenting account setup in Settings. Posting uses Google's YouTube API and requires your own iOS OAuth client ID; see NATIVE_COMMENTING.md in this repository. Playback sign-in is separate. No Google client is bundled.
- Keep drafts after failed requests and only show a new comment after YouTube confirms it. Ambiguous network failures are never retried automatically.
- New **uTube** app name, custom red icon, and **kharrison** attribution.
- AirPlay background fixes: keep an active route playing when leaving the app, prevent automatic PiP from interrupting AirPlay, and avoid pausing AirPlay when PiP closes.

Update through the same AltStore source. The bundle identifier is unchanged to preserve the existing installation. AirPlay still needs a check on your receiver; no live Google comment was posted during automated validation.
