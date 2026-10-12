uTube by kharrison, based on Opaline by verback2308.

- Added three more experimental playback methods after the previous six: Mobile web · native HLS, Embedded web · native HLS, and TV compatibility · byte ranges.
- Mobile and embedded HLS use the standard native player with automatic quality. The embedded route stays anonymous and requires an embeddable video with a usable playlist.
- TV compatibility uses the YouTube account already connected for comments and notifications. It tries compatible separate video/audio streams with the existing solver and native delivery. No new Google project or account setup is required when that account is connected.
- New methods are off by default. Enable them in Settings → Debug → Playback sources. Your existing order, enabled choices, and working solver are preserved.
- Improved embedded request configuration and added regression checks for delivery selection, account requirements and settings migration.

All five experimental alternatives depend on the video and session. Live playback and sustained AirPlay still need device testing; these are not guaranteed fixes for YouTube restrictions. The original four methods remain the defaults. See EXPERIMENTAL_PLAYBACK.md for the comparison and test guide.
