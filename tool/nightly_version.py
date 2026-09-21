"""Allocate nightly versions from published history, independently of Actions.

The workflow holds the repository-wide nightly concurrency group throughout
allocation and publication. Retained tags and both appcasts are the ledger;
failed builds do not consume a number. Only the Python standard library is used
so XML and binary/XML plists can be read without extra release dependencies.
"""

import argparse
import datetime
import pathlib
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

NIGHTLY = re.compile(r"(\d+\.\d+\.\d+)-nightly\.(\d{8})\.([1-9]\d*)")
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def split_version(version):
    """Return the base, UTC date and daily sequence of a nightly version."""
    match = NIGHTLY.fullmatch(version)
    if match is None:
        raise ValueError(f"Invalid nightly version: {version}")
    base, date, sequence = match.groups()
    datetime.datetime.strptime(date, "%Y%m%d")
    return base, date, int(sequence)


def bundle_version(version):
    """Encode a nightly date and sequence as a monotonic Sparkle integer."""
    _, date, sequence = split_version(version)
    if sequence > 99:
        raise ValueError("Nightly daily limit reached (99); wait for next UTC day")
    return int(date) * 100 + sequence


def read_history(tags, feeds):
    """Read our retained tags and generated feeds, failing on malformed data."""
    versions = set()
    bundles = []
    for tag in tags.splitlines():
        if tag.startswith("v") and "-nightly." in tag:
            version = tag[1:]
            split_version(version)
            versions.add(version)
    for feed in feeds:
        root = ET.fromstring(feed)
        channel = root.find("channel")
        if root.tag != "rss" or channel is None:
            raise ValueError("Expected an RSS appcast channel")
        for item in channel.findall("item"):
            version = item.findtext(f"{SPARKLE}shortVersionString")
            split_version(version)
            versions.add(version)
            # This channel has always published positive integer build numbers.
            # An unknown scheme needs an explicit migration, not a guessed floor.
            raw = item.findtext(f"{SPARKLE}version")
            if raw is None or re.fullmatch(r"[1-9]\d*", raw) is None:
                raise ValueError(f"Unsupported nightly bundle version: {raw}")
            bundles.append(int(raw))
    return versions, bundles


def ensure_newer(version, bundles, versions):
    """Reject duplicate/stale releases before any upload or appcast mutation."""
    candidate = bundle_version(version)
    _, date, sequence = split_version(version)
    if bundles and candidate <= max(bundles):
        raise ValueError("Nightly bundle version must exceed every published build")
    for previous in versions:
        _, old_date, old_sequence = split_version(previous)
        if (date, sequence) <= (old_date, old_sequence):
            raise ValueError("Nightly date/sequence is already published or stale")
    return candidate


def generate(base, date, versions, bundles):
    """Use the largest daily sequence, across base versions, rather than count."""
    sequence = max(
        (split_version(v)[2] for v in versions if split_version(v)[1] == date),
        default=0,
    ) + 1
    version = f"{base}-nightly.{date}.{sequence}"
    return version, ensure_newer(version, bundles, versions)


def check_artifact(version, plist, versions, bundles):
    """Use signed artifact metadata, including on restarts from another run."""
    candidate = ensure_newer(version, bundles, versions)
    if plist["CFBundleIdentifier"] != "dev.maximtop.makeitsoundnatural.nightly":
        raise ValueError("Expected the Nightly application")
    if plist["CFBundleVersion"] != str(candidate):
        raise ValueError("Artifact bundle version does not match the nightly version")
    if plist["CFBundleShortVersionString"] != version:
        raise ValueError("Artifact display version does not match the nightly version")
    return candidate


def main():
    """Print GitHub output fields; all inputs are explicit for reproducible tests."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["generate", "check"])
    parser.add_argument("--tags", type=pathlib.Path, required=True)
    parser.add_argument("--feed", type=pathlib.Path, action="append", required=True)
    parser.add_argument("--base")
    parser.add_argument("--date")
    parser.add_argument("--version")
    parser.add_argument("--plist", type=pathlib.Path)
    args = parser.parse_args()
    versions, bundles = read_history(
        args.tags.read_text(), [feed.read_text() for feed in args.feed]
    )
    if args.command == "generate":
        if args.base is None or args.date is None:
            parser.error("generate requires --base and --date")
        version, bundle = generate(args.base, args.date, versions, bundles)
    else:
        if args.version is None or args.plist is None:
            parser.error("check requires --version and --plist")
        version = args.version
        with args.plist.open("rb") as source:
            bundle = check_artifact(version, plistlib.load(source), versions, bundles)
    print(f"version={version}\nbundle_version={bundle}\nshort_version={version}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, ET.ParseError) as error:
        sys.exit(str(error))
