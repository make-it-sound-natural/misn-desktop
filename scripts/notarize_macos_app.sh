#!/usr/bin/env bash
set -euo pipefail

app_path="${1:?Usage: notarize_macos_app.sh APP_PATH [KEYCHAIN_PROFILE] [ZIP_PATH]}"
keychain_profile="${2:-notarytool-profile}"
zip_path="${3:-build/notarization-submission.zip}"
result_json="$(mktemp)"

cleanup() {
  rm -f "$zip_path" "$result_json"
}
trap cleanup EXIT

ditto -c -k --rsrc --keepParent "$app_path" "$zip_path"

echo "Submitting $app_path for notarization..."
set +e
xcrun notarytool submit "$zip_path" \
  --keychain-profile "$keychain_profile" \
  --wait \
  --output-format json > "$result_json"
submit_exit=$?
set -e

cat "$result_json"

submission_id="$(
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id", ""))' \
    "$result_json"
)"
status="$(
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status", ""))' \
    "$result_json"
)"

if [ "$submit_exit" -ne 0 ] || [ "$status" != "Accepted" ]; then
  echo "::error::Notarization failed with status: ${status:-unknown}"
  if [ -n "$submission_id" ]; then
    echo "Fetching notarization log for $submission_id..."
    xcrun notarytool log "$submission_id" \
      --keychain-profile "$keychain_profile" || true
  fi
  exit 1
fi

echo "Notarization accepted: $submission_id"
