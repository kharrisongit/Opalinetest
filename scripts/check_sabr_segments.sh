#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SABR_CHECK_DIR=$(mktemp -d)
trap 'rm -rf "$SABR_CHECK_DIR"' EXIT
swiftc Opaline/Core/API/Models/DirectPlaybackInfo.swift \
  Opaline/Core/API/Models/SubtitleTrack.swift \
  Opaline/Core/Playback/SABR/Protobuf.swift \
  Opaline/Core/Playback/SABR/UMPReader.swift \
  Opaline/Core/Playback/SABR/MediaHeader.swift \
  Opaline/Core/Playback/SABR/SABRSegmentRequest.swift \
  Opaline/Core/Playback/SABR/SABRBufferedRange.swift \
  Opaline/Core/Playback/SABR/SABRSegmentCollector.swift \
  scripts/sabr_segment_checks.swift -o "$SABR_CHECK_DIR/checks"
"$SABR_CHECK_DIR/checks"
