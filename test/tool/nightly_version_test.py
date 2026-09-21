"""Behavioral tests for release allocation and restart validation."""

import os
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import nightly_version as nightly


def feed(items=()):
    entries = "".join(
        f"<item><sparkle:version>{bundle}</sparkle:version>"
        f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString></item>"
        for version, bundle in items
    )
    return (
        '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
        f"<channel>{entries}</channel></rss>"
    )


class NightlyVersionTests(unittest.TestCase):
    def test_first_build_of_day_starts_at_one_above_installed_builds(self):
        versions, bundles = nightly.read_history(
            "v1.1.0-nightly.20260727.6", [feed([("1.1.0-nightly.20260727.6", 6)])]
        )
        self.assertEqual(
            nightly.generate("1.1.0", "20260920", versions, bundles),
            ("1.1.0-nightly.20260920.1", 2026092001),
        )

    def test_gaps_and_base_changes_use_maximum_across_the_day(self):
        versions = {"1.0.0-nightly.20260920.1", "1.1.0-nightly.20260920.8"}
        self.assertEqual(
            nightly.generate("2.0.0", "20260920", versions, [2026092008]),
            ("2.0.0-nightly.20260920.9", 2026092009),
        )

    def test_next_day_resets_daily_sequence_and_increases_bundle(self):
        self.assertEqual(
            nightly.generate(
                "1.0.0", "20261001", {"2.0.0-nightly.20260930.99"}, [2026093099]
            ),
            ("1.0.0-nightly.20261001.1", 2026100101),
        )

    def test_failed_build_or_workflow_rename_does_not_consume_a_number(self):
        history = ({"1.1.0-nightly.20260920.1"}, [2026092001])
        first = nightly.generate("1.1.0", "20260920", *history)
        self.assertEqual(nightly.generate("1.1.0", "20260920", *history), first)

    def test_serialized_runs_and_rerun_after_publication_advance(self):
        versions, bundles = set(), []
        for sequence in range(1, 100):
            version, bundle = nightly.generate("1.1.0", "20260920", versions, bundles)
            self.assertEqual(bundle, 2026092000 + sequence)
            versions.add(version)
            bundles.append(bundle)
        with self.assertRaisesRegex(ValueError, "daily limit"):
            nightly.generate("1.1.0", "20260920", versions, bundles)

    def test_stale_parallel_candidate_is_rejected_before_publication(self):
        first, bundle = nightly.generate("1.1.0", "20260920", set(), [])
        second, _ = nightly.generate("2.0.0", "20260920", set(), [])
        for candidate in (first, second, "1.1.0-nightly.20260919.99"):
            with self.assertRaises(ValueError):
                nightly.ensure_newer(candidate, [bundle], {first})

    def test_retained_tag_protects_partial_publication_without_feed_commit(self):
        versions, bundles = nightly.read_history("v1.1.0-nightly.20260920.8", [feed()])
        self.assertEqual(nightly.generate("1.1.0", "20260920", versions, bundles)[1], 2026092009)

    def test_feeds_protect_deleted_tags_and_deduplicate_history(self):
        version = "1.1.0-nightly.20260920.7"
        versions, bundles = nightly.read_history(
            "v1.0.0\nv1.1.0-beta.1\nv1.1.0-nightly.20260920.2",
            [feed([(version, 2026092007)]), feed([(version, 2026092007)])],
        )
        self.assertEqual(nightly.generate("1.1.0", "20260920", versions, bundles)[1], 2026092008)

    def test_unknown_or_higher_published_bundle_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "exceed"):
            nightly.generate("1.1.0", "20260920", set(), [3000000000])
        for invalid in ("1.2", "0", "-1", "nightly", ""):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                nightly.read_history("", [feed([("1.1.0-nightly.20260920.1", invalid)])])

    def test_rejects_future_history_and_invalid_dates(self):
        for date in ("20260919", "20260230"):
            with self.subTest(date=date), self.assertRaises(ValueError):
                nightly.generate("1.1.0", date, {"1.1.0-nightly.20260920.1"}, [])

    def test_restart_uses_artifact_metadata_without_new_run_number(self):
        version = "1.1.0-nightly.20260920.2"
        plist = {
            "CFBundleIdentifier": "dev.maximtop.makeitsoundnatural.nightly",
            "CFBundleVersion": "2026092002",
            "CFBundleShortVersionString": version,
        }
        self.assertEqual(nightly.check_artifact(version, plist, set(), [6]), 2026092002)
        for key, value in (
            ("CFBundleIdentifier", "dev.maximtop.makeitsoundnatural.beta"),
            ("CFBundleVersion", "6"),
            ("CFBundleShortVersionString", "1.1.0"),
        ):
            with self.subTest(key=key), self.assertRaises(ValueError):
                nightly.check_artifact(version, {**plist, key: value}, set(), [6])

    def test_history_refreshes_old_checkout_without_changing_remote(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            remote = path / "remote"
            checkout = path / "checkout"
            live = path / "live"
            remote.mkdir()
            live.mkdir()

            def git(*args, cwd=remote):
                return subprocess.run(
                    ["git", *args], cwd=cwd, check=True,
                    capture_output=True, text=True,
                    env={**os.environ, "GIT_AUTHOR_NAME": "Release test",
                         "GIT_AUTHOR_EMAIL": "test@example.com",
                         "GIT_COMMITTER_NAME": "Release test",
                         "GIT_COMMITTER_EMAIL": "test@example.com"},
                ).stdout.strip()

            git("init", "--initial-branch=master")
            (remote / "appcast-nightly.xml").write_text(feed())
            git("add", ".")
            git("commit", "-m", "Initial feed")
            git("clone", str(remote), str(checkout), cwd=path)
            version = "1.1.0-nightly.20260920.7"
            updated = feed([(version, 2026092007)])
            (remote / "appcast-nightly.xml").write_text(updated)
            git("commit", "-am", "Publish nightly")
            git("tag", "v" + version)
            original_refs = git("show-ref")
            (live / "appcast-nightly.xml").write_text(updated)
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/read_nightly_history.sh")],
                cwd=checkout, capture_output=True, text=True,
                env={**os.environ, "DEFAULT_BRANCH": "master",
                     "UPDATE_BASE_URL": live.as_uri()},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((checkout / "appcast-nightly.xml").read_text(), feed())
            self.assertEqual((checkout / "build/nightly-repository.xml").read_text(), updated)
            self.assertEqual((checkout / "build/nightly-live.xml").read_text(), updated)
            self.assertIn("v" + version, (checkout / "build/nightly-tags.txt").read_text())
            self.assertEqual(git("show-ref"), original_refs)

    def test_cli_round_trip_with_binary_plist_and_rejected_duplicate(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            tags = path / "tags"
            appcast = path / "feed.xml"
            plist = path / "Info.plist"
            tags.write_text("")
            appcast.write_text(feed())
            command = [sys.executable, str(ROOT / "tool/nightly_version.py")]
            history = ["--tags", str(tags), "--feed", str(appcast)]
            generated = subprocess.run(
                command + ["generate", "--base", "1.1.0", "--date", "20260920"] + history,
                check=True, capture_output=True, text=True,
            ).stdout
            outputs = dict(line.split("=", 1) for line in generated.splitlines())
            plist.write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "dev.maximtop.makeitsoundnatural.nightly",
                "CFBundleVersion": outputs["bundle_version"],
                "CFBundleShortVersionString": outputs["short_version"],
            }, fmt=plistlib.FMT_BINARY))
            check = command + ["check", "--version", outputs["version"], "--plist", str(plist)] + history
            self.assertEqual(subprocess.run(check, check=True, capture_output=True, text=True).stdout, generated)
            tags.write_text("v" + outputs["version"])
            rejected = subprocess.run(check, capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertEqual(rejected.stdout, "")


if __name__ == "__main__":
    unittest.main()
