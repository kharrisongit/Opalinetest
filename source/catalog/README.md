# kharrison Apps catalog

The existing AltStore Classic source is `../apps.json`. Quill and Verse keep
their application code, builds, and IPA releases in their own repositories.
This directory only maintains their listings in the shared kharrison Apps source.

`sync.py` imports their published app metadata, checks that the newest IPA is
public and has the declared size, and preserves older versions and other apps.
It keeps the existing source identifier so users do not need to add a new source.

The **Sync kharrison Apps catalog** workflow checks for releases every 15 minutes
(GitHub may delay scheduled runs). It can also be run manually after a release.
No cross-repository credentials or copied application code are needed.

```sh
python3 -m unittest discover -s source/catalog -p 'test_sync.py'
python3 source/catalog/sync.py
```
