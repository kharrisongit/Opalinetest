#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh simulator
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for devices in d["devices"].values() for v in devices if v["name"].startswith("iPhone")))')
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" build/simulator/Verse.app
xcrun simctl launch "$DEVICE" com.kharrison.verse
sleep 4
xcrun simctl spawn "$DEVICE" launchctl list | grep com.kharrison.verse
xcrun simctl io "$DEVICE" screenshot build/verse-screenshot.png
xcrun simctl terminate "$DEVICE" com.kharrison.verse
