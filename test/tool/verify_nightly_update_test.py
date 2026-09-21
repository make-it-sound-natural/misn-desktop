"""Behavioral checks for staging feeds and verifying installed updates."""

import pathlib
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "tool"))
import verify_nightly_update as verification


class VerifyNightlyUpdateTests(unittest.TestCase):
    def test_staged_feed_preserves_signed_metadata(self):
        item = ET.fromstring('''
          <item xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <sparkle:version>2026092001</sparkle:version>
            <sparkle:shortVersionString>1.1.0-nightly.20260920.1</sparkle:shortVersionString>
            <enclosure url="https://example.com/app.dmg" length="123"
                       sparkle:edSignature="signature" type="application/octet-stream"/>
          </item>''')
        result = ET.fromstring(verification.staged_feed(item, "http://127.0.0.1/app.dmg"))
        staged = result.find("channel/item")
        self.assertEqual(staged.findtext(f"{verification.SPARKLE}version"), "2026092001")
        self.assertEqual(staged.find("enclosure").attrib, {
            "url": "http://127.0.0.1/app.dmg", "length": "123",
            f"{verification.SPARKLE}edSignature": "signature",
            "type": "application/octet-stream",
        })

    def test_installed_app_must_match_version_and_preserve_channel_trust(self):
        before = {"CFBundleVersion": "6", "CFBundleShortVersionString": "1.1.0",
                  "CFBundleIdentifier": "dev.maximtop.makeitsoundnatural.nightly",
                  "SUFeedURL": "https://example.com/appcast-nightly.xml",
                  "SUPublicEDKey": "original key"}
        after = {**before, "CFBundleVersion": "2026092001",
                 "CFBundleShortVersionString": "1.1.0-nightly.20260920.1"}
        verification.verify_installed(before, after, "2026092001", after["CFBundleShortVersionString"])
        for key in after:
            with self.subTest(key=key), self.assertRaises(ValueError):
                verification.verify_installed(
                    before, {**after, key: "changed"}, "2026092001",
                    after["CFBundleShortVersionString"],
                )

    def test_latest_item_uses_numeric_order_not_document_order(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "feed.xml"
            path.write_text('''
              <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
                <item><sparkle:version>9</sparkle:version></item>
                <item><sparkle:version>10</sparkle:version></item>
              </channel></rss>''')
            self.assertEqual(verification.latest_item(path).findtext(f"{verification.SPARKLE}version"), "10")


if __name__ == "__main__":
    unittest.main()
