"""Check first publication, repeat publication, and mismatched IPA rejection."""
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).with_name("update_source.py")


class UpdateSourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.feed = self.root / "apps.json"
        self.template = self.root / "app.json"
        self.ipa = self.root / "Opaline.ipa"
        self.feed.write_text(json.dumps({"name": "Test source", "apps": [], "news": []}))
        self.template.write_text(json.dumps({
            "name": "Opaline", "bundleIdentifier": "com.verback.YTLite",
            "developerName": "Test", "iconURL": "https://example.com/icon.png",
        }))
        self.write_ipa()

    def write_ipa(self, bundle="com.verback.YTLite", version="1.12.1"):
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr("Payload/Opaline.app/Info.plist", plistlib.dumps({
                "CFBundleIdentifier": bundle,
                "CFBundleShortVersionString": version,
                "CFBundleVersion": "123", "MinimumOSVersion": "12.0",
            }))

    def publish(self, size=None):
        return subprocess.run([
            sys.executable, str(SCRIPT), "--file", str(self.feed),
            "--app-template", str(self.template), "--ipa", str(self.ipa),
            "--version", "1.12.1", "--size", str(size or self.ipa.stat().st_size),
            "--date", "2026-10-12T06:30:00Z", "--download-url",
            "https://github.com/kharrisongit/Opalinetest/releases/download/1.12.1/Opaline.ipa",
        ], capture_output=True, text=True, check=False)

    def test_first_release_populates_empty_source(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(self.feed.read_text())
        app = data["apps"][0]
        latest = app["versions"][0]
        self.assertEqual(latest["buildVersion"], "123")
        self.assertEqual(latest["version"], "1.12.1")
        self.assertEqual(latest["size"], self.ipa.stat().st_size)
        self.assertEqual(latest["downloadURL"], app["downloadURL"])
        self.assertEqual(data["news"][0]["appID"], app["bundleIdentifier"])
        self.assertEqual(data["news"][0]["url"],
                         "https://github.com/kharrisongit/Opalinetest/releases/tag/1.12.1")

    def test_fork_name_and_icon_are_preserved(self):
        template = json.loads(self.template.read_text())
        template["name"] = "uTube"
        template["iconURL"] = "https://example.com/utube-icon.png"
        self.template.write_text(json.dumps(template))
        self.assertEqual(self.publish().returncode, 0)
        data = json.loads(self.feed.read_text())
        self.assertEqual(data["news"][0]["title"], "uTube 1.12.1")
        self.assertEqual(data["apps"][0]["iconURL"], template["iconURL"])

    def test_repeated_publication_has_one_version_and_news_item(self):
        self.assertEqual(self.publish().returncode, 0)
        self.assertEqual(self.publish().returncode, 0)
        data = json.loads(self.feed.read_text())
        self.assertEqual(len(data["apps"][0]["versions"]), 1)
        self.assertEqual(len(data["news"]), 1)

    def test_rejects_wrong_app_without_changing_source(self):
        original = self.feed.read_bytes()
        self.write_ipa(bundle="com.example.wrong")
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.feed.read_bytes(), original)

    def test_rejects_wrong_version_without_changing_source(self):
        original = self.feed.read_bytes()
        self.write_ipa(version="1.12.0")
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.feed.read_bytes(), original)

    def test_rejects_wrong_size_without_changing_source(self):
        original = self.feed.read_bytes()
        self.assertNotEqual(self.publish(size=1).returncode, 0)
        self.assertEqual(self.feed.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
