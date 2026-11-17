"""Stable release regressions: version identity, history and approved bytes."""

import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("stable_release", ROOT / "tool/stable_release.py")
stable = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stable)


class StableReleaseTests(unittest.TestCase):
    def test_dispatch_must_match_pubspec(self):
        self.assertEqual(stable.source_version("1.2.0", "version: 1.2.0+5\n"), "5")
        for version in ["1.3.0", "1.2.0-nightly.20261116.1", "1.2.0;echo bad"]:
            with self.assertRaises(ValueError):
                stable.source_version(version, "version: 1.2.0+5\n")

    def test_signed_plist_cannot_be_nightly_or_wrong_version(self):
        plist = {"CFBundleIdentifier": stable.BUNDLE_ID,
                 "CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "5",
                 "SUFeedURL": "https://example.com/appcast.xml", "SUPublicEDKey": "key"}
        stable.check_plist(plist, "1.2.0", "5", plist["SUFeedURL"], "key")
        for key in plist:
            changed = dict(plist, **{key: "wrong"})
            with self.assertRaises(ValueError):
                stable.check_plist(changed, "1.2.0", "5", plist["SUFeedURL"], "key")

    def test_history_rejects_duplicates_and_build_regressions(self):
        feed = '''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
        <channel><item><sparkle:version>5</sparkle:version>
        <sparkle:shortVersionString>1.2.0</sparkle:shortVersionString></item></channel></rss>'''
        stable.check_history("1.3.0", "6", "v1.2.0", feed)
        for version, build, tags in [("1.2.0", "6", ""), ("1.3.0", "5", ""),
                                     ("1.3.0", "6", "v1.3.0")]:
            with self.assertRaises(ValueError):
                stable.check_history(version, build, tags, feed)

    def test_first_stable_accepts_empty_feed_and_preserves_nightly_history(self):
        stable.check_history("1.2.0", "5", "v1.2.0-nightly.20261107.1",
                             "<rss><channel /></rss>")

    def test_publish_requires_complete_unchanged_payload_and_same_commit(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = pathlib.Path(temp)
            for name in ["MakeItSoundNatural-1.2.0.dmg", "MakeItSoundNatural-1.2.0.app.zip",
                         "appcast.xml", "release-notes.txt", "qa.txt"]:
                (directory / name).write_text(name)
            record = stable.manifest(directory, "1.2.0", "5", "source-sha")
            (directory / "candidate.json").write_text(json.dumps(record))
            stable.verify(directory, "1.2.0", "5", "source-sha")
            with self.assertRaises(ValueError):
                stable.verify(directory, "1.2.0", "5", "other-sha")
            (directory / "MakeItSoundNatural-1.2.0.dmg").write_text("rebuilt")
            with self.assertRaises(ValueError):
                stable.verify(directory, "1.2.0", "5", "source-sha")
            (directory / "MakeItSoundNatural-1.2.0.dmg").unlink()
            (directory / "candidate.json").write_text(json.dumps(
                stable.manifest(directory, "1.2.0", "5", "source-sha")))
            with self.assertRaises(ValueError):
                stable.verify(directory, "1.2.0", "5", "source-sha")


if __name__ == "__main__":
    unittest.main()
