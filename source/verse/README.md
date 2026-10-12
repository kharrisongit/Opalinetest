# Verse

Native UIKit lyric notebook for AltStore Classic; bundle ID `com.kharrison.verse`, iOS 16+.

## Use

Refresh the **kharrison Apps** source in AltStore and install Verse. Compose a lyric, put it in a notebook, and select text → tap **Rhyme** to insert a suggestion. **Check spelling** is in the editor menu and keyboard toolbar. English rhyme lookups are offline; system spell-check languages follow installed dictionaries.

For sync, choose **Settings → Connect iCloud Drive folder**. Select the same parent folder under **iCloud Drive** on every device. Verse creates a `Verse` subfolder. A folder selected under **On My iPhone** only saves locally. The Files provider controls cloud propagation; “Saved to sync folder” means the local provider accepted the files, not that another device has already downloaded them. Sync runs at launch, every 25 seconds while open, after edits, and on manual refresh. The app has no always-running background service.

Saved revisions are immutable UUID-named JSON files. Parent revision links derive current drafts without deleting historical data. Concurrent edits remain separate drafts, marked “Parallel draft.” Choose the preferred text and trash the other draft when ready. Backups include history and deleted drafts; removing the app deletes device-only data. Removing remote files is not a deletion command; trash lyrics within Verse instead.

## Build and checks

On macOS with Xcode selected:

```sh
swiftc source/verse/Sources/Models.swift source/verse/Tests/CoreChecks.swift -o /tmp/verse-checks
/tmp/verse-checks
bash source/verse/build.sh
bash source/verse/smoke.sh
```

`build.sh` compiles with the iOS SDK, builds icons, bundles a revision-pinned CMU dictionary, and packages an ad-hoc-signed `Verse.ipa` for AltStore to re-sign. No paid signing secrets are stored in the repository. GitHub Actions **Build Verse IPA** tests, compiles, simulator-launches, publishes a `verse-*` release, and updates only Verse in the shared AltStore source using the existing validated publisher. The existing apps remain separate.

Device acceptance: install in AltStore, type a misspelling and correct it, search “light” in both rhyme modes, kill/relaunch after editing, restore a backup, connect the same iCloud folder on two devices, test offline edits on both then reconnect and verify both drafts survive. Simulator launch is not a substitute for this iCloud/AltStore test.

Dictionary: CMUdict commit `74790861f652b15e4ac49015a90074ad62a27690`. License included in Resources and the app Settings.
