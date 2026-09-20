# Nightly version numbering

Nightly display versions are `BASE-nightly.YYYYMMDD.N` in UTC. The first
published build of a new day is `.1`. The sequence is shared across base
versions: changing `1.1.0` to `1.2.0` on the same day does not reset it.
`CFBundleShortVersionString` now includes this complete display version.

`CFBundleVersion` is the decimal integer `YYYYMMDDNN`, with a two-digit daily
sequence. The appcast uses the same value read and checked from the signed
artifact. There is a hard limit of 99 releases per UTC day; reaching it fails
before publication. Do not widen the suffix without a migration review.

## Allocation and publication

- `tool/nightly_version.py` uses Python's standard XML/plist parsers, without
  additional dependencies. Existing Dart commands still configure the app and
  write appcasts.
- Fetch remote tags and the default branch appcast, and download the current
  live appcast. Missing or malformed history stops the release.
- Take the maximum existing sequence for the day plus one, not the tag count.
  Tags and both feeds contribute, so gaps and removed releases do not collide.
- Keep tags when deleting old nightly release assets. Tags also record a
  release whose appcast publication or commit did not finish.
- Reject a candidate that is not newer than every known nightly date/sequence
  and every published numeric bundle version. Clock rollback, stale restarts,
  an unexpected version scheme, or a higher existing bundle stop publication.
- Hold the repository-wide `nightly` Actions concurrency group from allocation
  through publication, with `cancel-in-progress: false`. Preserve this literal
  group when renaming or copying the workflow. GitHub may replace pending runs;
  they do not consume versions. Do not run an older workflow revision during
  migration: it still uses the old allocation and cancellation policy.
- Recheck history and the extracted signed app before creating release assets.
  Publish the GitHub release/tag before an external appcast, then commit only
  the updated nightly feed on the freshly fetched default branch.

## Retries and recovery

A failed build that published nothing can reuse its number. Rerunning the build
after publication allocates a new number. Restarting notarization or release
uses the supplied source artifact and its embedded versions, never the new
Actions run number. Artifacts built with the old scheme cannot be published
through the new workflow; build a fresh nightly instead.

A duplicate or older release attempt fails before uploads or feed changes. A
failure after the GitHub release was created reserves that number permanently;
start a new build to publish a newer version. Do not replace published assets or
remove ledger tags to make a retry pass. Manually restoring a partially
published feed requires a separate review. Git push conflicts fail safely and
may require a new build; there is no force push.

## Compatibility evidence (20 September 2026)

The GitHub releases, tags, current default branch, live nightly feed and the
all five retained downloadable applications were inspected for
[MT-899](https://www.notion.so/3aa03d59105281dfa3c0fe6349d41a4d).
The latest published nightly is `1.1.0-nightly.20260727.6`, with actual bundle
version `6`. Both the retained feed and downloaded apps contain builds `2`
through `6`, with matching feed URLs and bundle identifiers. An allocation
for 20 September produces `1.1.0-nightly.20260920.1` / `2026092001`.
This observation is evidence, not a hard-coded migration floor: each release
reads current history again.

Sparkle 2.8.1 is pinned in `macos/Podfile.lock`. XCTest calls its actual
`SUStandardVersionComparator`, covering old integer builds, daily increments,
day/month rollover, equality and reverse comparisons. Sparkle ignores the
suffix after a hyphen, so two display versions with the same base compare
equal. Only numeric bundle versions are used for nightly update ordering.
See [Sparkle publishing](https://sparkle-project.org/documentation/publishing/).

Stable and beta use separate bundle identifiers and feed URLs. There is no
in-app channel switch or automatic cross-channel update path. A manual install
of another channel installs that channel's separate application. This change
preserves all three identities, feeds and signing keys.

Stable and beta currently have empty feeds and no published GitHub releases.
Their workflows already use the pubspec build number inside the app but the
marketing version in the appcast. Those values are not necessarily ordered
correctly by Sparkle (for example, bundle `4` is newer than feed `1.1.0`).
That pre-existing release issue is outside this nightly correction; this work
does not claim stable/beta end-to-end update compatibility or change their
numbering. It should be addressed before their first public release.

## Verification

- `make test-release`: allocation, gaps, base/day changes, retries, stale
  candidates, partial publication, binary plists and CLI failures.
- `make test`: release policy, Flutter tests and native XCTest, including real
  Sparkle comparison behavior.
- `make lint-flutter`, `make lint-swift`, and a debug macOS build.

No release or live feed mutation is needed for these checks. Actual signed,
notarized installation and Sparkle download/install remain a release-time
verification; do not mark MT-899 Done based only on these local checks.
