"""Install a signed candidate over a disposable copy of the live nightly.

Run on the release runner, where no user installation is running. The candidate
feed and DMG are served only on loopback; neither the live feed nor the signed
application plists are changed. Sparkle performs its normal download, signature
verification and installation before publication is allowed.
"""

import argparse
import contextlib
import functools
import http.server
import pathlib
import plistlib
import subprocess
import tempfile
import threading
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
APP_NAME = "Make It Sound Natural Nightly.app"


def latest_item(feed):
    """Read the newest numeric nightly build from a generated appcast."""
    return max(
        ET.parse(feed).getroot().find("channel").findall("item"),
        key=lambda item: int(item.findtext(f"{SPARKLE}version")),
    )


def staged_feed(item, url):
    """Retarget only the download URL, preserving the signature and versions."""
    ET.register_namespace("sparkle", SPARKLE[1:-1])
    root = ET.Element("rss", version="2.0")
    channel = ET.SubElement(root, "channel")
    ET.SubElement(channel, "title").text = "Nightly installation verification"
    item.find("enclosure").set("url", url)
    channel.append(item)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def run(*args):
    """Bound external operations so a stuck installer cannot allow publication."""
    return subprocess.run(args, check=True, timeout=300)


def read_plist(app):
    with (app / "Contents/Info.plist").open("rb") as source:
        return plistlib.load(source)


def verify_installed(before, after, expected_version, expected_short_version):
    """Require the update and the existing channel's trust/identity to survive."""
    if after["CFBundleVersion"] != expected_version:
        raise ValueError("Sparkle did not install the expected bundle version")
    if after["CFBundleShortVersionString"] != expected_short_version:
        raise ValueError("Installed display version does not match the candidate")
    for key in ("CFBundleIdentifier", "SUFeedURL", "SUPublicEDKey"):
        if after[key] != before[key]:
            raise ValueError(f"Update changed {key}")


@contextlib.contextmanager
def serve(directory):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            yield f"http://127.0.0.1:{server.server_port}"
        finally:
            server.shutdown()
            thread.join()


def verify_update(dmg, candidate_feed, live_feed, sparkle):
    candidate = latest_item(candidate_feed)
    previous = latest_item(live_feed)
    expected = candidate.findtext(f"{SPARKLE}version")
    expected_short = candidate.findtext(f"{SPARKLE}shortVersionString")
    old_version = previous.findtext(f"{SPARKLE}version")
    if int(expected) <= int(old_version):
        raise ValueError("Candidate must be newer than the live nightly")

    with tempfile.TemporaryDirectory(prefix="nightly-update-") as temporary:
        root = pathlib.Path(temporary)
        previous_dmg = root / "previous.dmg"
        run("curl", "--fail", "--location", "--retry", "3", "--output",
            str(previous_dmg), previous.find("enclosure").get("url"))
        mount = root / "mounted"
        mount.mkdir()
        installed = root / APP_NAME
        run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint",
            str(mount), str(previous_dmg))
        try:
            run("ditto", str(mount / APP_NAME), str(installed))
        finally:
            run("hdiutil", "detach", str(mount))
        before = read_plist(installed)
        if before["CFBundleVersion"] != old_version:
            raise ValueError("Live archive and appcast bundle versions differ")
        run("codesign", "--verify", "--deep", "--strict", str(installed))
        run("xcrun", "stapler", "validate", str(dmg))

        site = root / "site"
        site.mkdir()
        (site / "candidate.dmg").symlink_to(dmg.resolve())
        with serve(str(site)) as url:
            (site / "appcast.xml").write_bytes(
                staged_feed(candidate, f"{url}/candidate.dmg")
            )
            run(str(sparkle), str(installed), "--check-immediately", "--verbose",
                "--feed-url", f"{url}/appcast.xml", "--user-agent-name",
                "MISN Nightly Release Verification")

        verify_installed(before, read_plist(installed), expected, expected_short)
        run("codesign", "--verify", "--deep", "--strict", str(installed))
        run("spctl", "--assess", "--type", "execute", "--verbose=2", str(installed))
        print(f"Verified Sparkle installation: {old_version} -> {expected} "
              f"({expected_short}); identity, feed and public key preserved", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dmg", type=pathlib.Path, required=True)
    parser.add_argument("--candidate-feed", type=pathlib.Path, required=True)
    parser.add_argument("--live-feed", type=pathlib.Path, required=True)
    parser.add_argument("--sparkle", type=pathlib.Path, required=True)
    args = parser.parse_args()
    verify_update(args.dmg, args.candidate_feed, args.live_feed, args.sparkle)


if __name__ == "__main__":
    main()
