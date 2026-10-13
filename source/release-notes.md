uTube by kharrison, based on Opaline by verback2308.

- AirPlay now selects an available H.264 stream up to 1080p60 instead of sending the phone's AV1/high-resolution choice to the receiver. Lower quality selections stay lower.
- The same compatibility selection runs when AirPlay connects after a video starts. Switching keeps the existing player/receiver connection, playback position, speed and a deliberate pause.
- Quality choices while AirPlay is connected use the compatible formats. Your saved higher-quality default for watching on the phone is unchanged.
- Works through the existing Opaline playback sources and solver. No experimental source needs to be enabled.
- SABR now checks the returned segment number before serving media. Earlier segments are skipped instead of being served under a later segment's URL, preventing repeated overlapping chunks during playback.
- New videos clear the previous video's recovery position. SponsorBlock waits for a ready player and pending recovery/resume work before skipping.
- Added regression checks covering both reported video format ladders, lower quality selections, and codec alternatives at the same resolution.

This update also targets the repeated segment requests and stale recovery seeks found in the Ryan George playback log.
