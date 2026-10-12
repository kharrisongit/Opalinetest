import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import sync


def feed(version="1.0.1", bundle="com.kharrison.quill", repo="kharrisongit/Quill"):
    app = {"name": "Quill", "bundleIdentifier": bundle, "versions": [{
        "version": version, "buildVersion": "1", "date": "2026-10-12T22:00:00Z",
        "downloadURL": f"https://github.com/{repo}/releases/download/v{version}/Quill.ipa",
        "size": 123, "localizedDescription": "Release notes",
    }]}
    return {"apps": [app], "news": [{"identifier": f"{bundle}-{version}",
             "appID": bundle, "date": "2026-10-12T22:00:00Z"}]}


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.other = {"bundleIdentifier": "com.kharrison.utube", "versions": [{"anything": "kept"}]}
        self.base = {"name": "kharrison Apps", "identifier": "existing-source-id",
                     "apps": [self.other], "news": [{"identifier": "utube-news", "appID": "com.kharrison.utube"}]}

    def merge(self, base, incoming):
        return sync.merge_app(base, incoming, "com.kharrison.quill", "kharrisongit/Quill")

    def test_addition_preserves_source_other_apps_and_input(self):
        before = copy.deepcopy(self.base)
        result = self.merge(self.base, feed())
        self.assertEqual(self.base, before)
        self.assertEqual(result["apps"][0], self.other)
        self.assertEqual(result["identifier"], before["identifier"])
        self.assertIn(before["news"][0], result["news"])
        self.assertEqual(result["apps"][1]["version"], "1.0.1")

    def test_new_release_keeps_older_versions(self):
        result = self.merge(self.merge(self.base, feed()), feed("1.0.2"))
        self.assertEqual([v["version"] for v in result["apps"][1]["versions"]], ["1.0.2", "1.0.1"])
        self.assertEqual(result["apps"][1]["downloadURL"], feed("1.0.2")["apps"][0]["versions"][0]["downloadURL"])

    def test_stale_feed_does_not_downgrade(self):
        current = self.merge(self.base, feed("1.0.2"))
        current["apps"][1]["name"] = "Newer metadata"
        result = self.merge(current, feed())
        self.assertEqual(result["apps"][1]["version"], "1.0.2")
        self.assertEqual(result["apps"][1]["name"], "Newer metadata")

    def test_rerun_is_idempotent(self):
        result = self.merge(self.base, feed())
        self.assertEqual(self.merge(result, feed()), result)

    def test_wrong_app_and_wrong_download_rejected(self):
        for incoming in [feed(bundle="another.app"), feed(repo="someone/Else"), {"apps": []}]:
            with self.assertRaises(ValueError):
                self.merge(self.base, incoming)

    def test_news_cannot_replace_another_app(self):
        incoming = feed()
        incoming["news"][0]["identifier"] = "utube-news"
        with self.assertRaises(ValueError):
            self.merge(self.base, incoming)

    def test_failed_download_keeps_published_file_unchanged(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "apps.json"
            original = json.dumps(self.base)
            path.write_text(original)
            with patch.dict(sync.APPS, {"com.kharrison.quill": "kharrisongit/Quill"}, clear=True), \
                 patch.object(sync, "fetch_feed", return_value=feed()), \
                 patch.object(sync, "verify_download", side_effect=ValueError("Not published")):
                with self.assertRaises(ValueError):
                    sync.sync(path)
            self.assertEqual(path.read_text(), original)


if __name__ == "__main__":
    unittest.main()
