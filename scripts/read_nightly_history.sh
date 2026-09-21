#!/usr/bin/env bash
# Refresh history even when the build checkout or a restarted run is old.
set -euo pipefail

mkdir -p build
branch="${DEFAULT_BRANCH:?DEFAULT_BRANCH is required}"
git fetch --tags origin "$branch"
git show "FETCH_HEAD:appcast-nightly.xml" > build/nightly-repository.xml
git tag --list > build/nightly-tags.txt
base_url="${UPDATE_BASE_URL:-https://raw.githubusercontent.com/${GITHUB_REPOSITORY:?}/$branch}"
curl --fail --location --silent --show-error --retry 3 \
  -H 'Cache-Control: no-cache' \
  "${base_url%/}/appcast-nightly.xml" > build/nightly-live.xml
