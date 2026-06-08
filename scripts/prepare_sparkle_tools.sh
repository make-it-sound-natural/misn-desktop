#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
if [ -z "$version" ]; then
  version="$(
    awk '/- Sparkle \([0-9][^)]*\)/ {
      gsub(/[()]/, "", $3)
      print $3
      exit
    }' macos/Podfile.lock
  )"
fi

if [ -z "$version" ]; then
  echo "Unable to determine Sparkle version from macos/Podfile.lock" >&2
  exit 1
fi

tools_dir="${RUNNER_TEMP:-/tmp}/sparkle-tools-$version"
sign_update="$tools_dir/bin/sign_update"
archive="$tools_dir/Sparkle-$version.tar.xz"
archive_url="https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz"

if [ ! -x "$sign_update" ]; then
  rm -rf "$tools_dir"
  mkdir -p "$tools_dir"
  echo "Downloading Sparkle $version tools from $archive_url..." >&2
  curl --fail --location --show-error --retry 5 --retry-all-errors \
    --connect-timeout 20 \
    --output "$archive" \
    "$archive_url"

  echo "Extracting Sparkle sign_update..." >&2
  if ! tar -tf "$archive" ./bin/sign_update >/dev/null; then
    echo "Sparkle archive does not contain ./bin/sign_update" >&2
    tar -tf "$archive" | head -50 >&2
    exit 1
  fi
  tar -xJf "$archive" -C "$tools_dir" ./bin/sign_update
  chmod +x "$sign_update"
fi

printf '%s\n' "$sign_update"
