"""Validate stable artifacts and preserve the exact bytes approved for release."""

import argparse
import hashlib
import json
import pathlib
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
BUNDLE_ID = "dev.maximtop.makeitsoundnatural"


def source_version(version, pubspec):
    """Require the dispatch version to match the committed source version."""
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Stable version must have three numeric components")
    match = re.search(r"^version: (\S+)\+([1-9][0-9]*)$", pubspec, re.MULTILINE)
    if not match or match[1] != version:
        raise ValueError("Stable version must match pubspec.yaml")
    return match[2]


def check_plist(plist, version, build, feed_url, public_key):
    """Check signed metadata rather than trusting the archive's filename."""
    expected = {
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "SUFeedURL": feed_url,
        "SUPublicEDKey": public_key,
    }
    for key, value in expected.items():
        if plist.get(key) != value:
            raise ValueError(f"Artifact {key} does not match release source")


def check_history(version, build, tags, feed):
    """Reject duplicate tags and non-increasing stable versions/builds."""
    if f"v{version}" in tags.splitlines():
        raise ValueError("Stable tag already exists; never replace a release")
    channel = ET.fromstring(feed).find("channel")
    if channel is None:
        raise ValueError("Expected RSS channel")
    for item in channel.findall("item"):
        previous = item.findtext(f"{SPARKLE}shortVersionString", "")
        previous_build = item.findtext(f"{SPARKLE}version", "")
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", previous):
            raise ValueError("Unrecognized stable version history")
        if not re.fullmatch(r"[1-9][0-9]*", previous_build):
            raise ValueError("Unrecognized stable build history")
        if tuple(map(int, version.split('.'))) <= tuple(map(int, previous.split('.'))):
            raise ValueError("Stable version must increase")
        if int(build) <= int(previous_build):
            raise ValueError("Stable build number must increase")


def checksums(directory):
    """Hash all candidate payload files, excluding the manifest itself."""
    return {
        path.name: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(directory.iterdir())
        if path.is_file() and path.name != "candidate.json"
    }


def manifest(directory, version, build, sha):
    """Record provenance for the candidate's immutable publication payload."""
    return {"version": version, "build": build, "sha": sha,
            "files": checksums(directory)}


def verify(directory, version, build, sha):
    """Reject changed, missing or extra files and mismatched source commits."""
    actual = json.loads((directory / "candidate.json").read_text())
    if actual != manifest(directory, version, build, sha):
        raise ValueError("Candidate provenance or SHA256 checksums do not match")
    required = {f"MakeItSoundNatural-{version}.dmg",
                f"MakeItSoundNatural-{version}.app.zip", "appcast.xml",
                "release-notes.txt", "qa.txt"}
    if set(actual["files"]) != required:
        raise ValueError("Candidate payload is incomplete")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["source", "plist", "history", "manifest", "verify"])
    parser.add_argument("--version", required=True)
    parser.add_argument("--pubspec", default="pubspec.yaml")
    parser.add_argument("--plist", type=pathlib.Path)
    parser.add_argument("--source-plist", type=pathlib.Path, default=pathlib.Path("macos/Runner/Info.plist"))
    parser.add_argument("--feed-url")
    parser.add_argument("--tags", type=pathlib.Path)
    parser.add_argument("--feed", type=pathlib.Path)
    parser.add_argument("--directory", type=pathlib.Path)
    parser.add_argument("--sha")
    args = parser.parse_args()
    build = source_version(args.version, pathlib.Path(args.pubspec).read_text())
    if args.command == "source":
        print(f"build_number={build}")
    elif args.command == "plist":
        source = plistlib.loads(args.source_plist.read_bytes())
        check_plist(plistlib.loads(args.plist.read_bytes()), args.version, build,
                    args.feed_url, source["SUPublicEDKey"])
    elif args.command == "history":
        check_history(args.version, build, args.tags.read_text(), args.feed.read_text())
    elif args.command == "manifest":
        (args.directory / "candidate.json").write_text(
            json.dumps(manifest(args.directory, args.version, build, args.sha), indent=2) + "\n")
    else:
        verify(args.directory, args.version, build, args.sha)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, ET.ParseError) as error:
        print(f"Stable release rejected: {error}", file=sys.stderr)
        sys.exit(1)
