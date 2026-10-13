#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
AIRPLAY_CHECK_DIR=$(mktemp -d)
trap 'rm -rf "$AIRPLAY_CHECK_DIR"' EXIT
swiftc Opaline/Core/API/Models/DirectPlaybackInfo.swift \
  Opaline/Core/API/Models/SubtitleTrack.swift \
  Opaline/Core/Playback/AirPlayVideoPolicy.swift \
  scripts/airplay_playback_checks.swift -o "$AIRPLAY_CHECK_DIR/checks"
"$AIRPLAY_CHECK_DIR/checks" scripts/fixtures/airplay_video_formats.json
