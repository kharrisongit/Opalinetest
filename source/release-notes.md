uTube by kharrison, based on Opaline by verback2308.

- Added two experimental playback options after the existing four: Web · native HLS and Embedded web · byte ranges. Enable them in Settings → Debug → Playback sources. Both are off by default; your existing choices and solver stay configured as before.
- Native web HLS can use the YouTube website account you already connected, with automatic quality in the standard player. No separate Google registration or web player window is needed. Availability depends on the video and session.
- Embedded playback tries anonymous compatible streams for videos that allow embedding, using the existing signature solver and native HLS delivery with quality selection.
- Added time limits for experimental loading and guards against late, duplicate or cancelled source responses replacing the current video.

These are experimental alternatives, not guaranteed fixes for YouTube restrictions. Live playback and sustained AirPlay on the new methods still need device testing. The current four playback methods remain the defaults. See EXPERIMENTAL_PLAYBACK.md in the repository for details and the test guide.
