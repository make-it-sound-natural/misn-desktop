#!/bin/bash
set -euo pipefail

# Extract version information from pubspec.yaml
# Usage:
#   ./extract_version.sh          - Prints version number
#   ./extract_version.sh changelog - Generates changelog from git commits

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC_PATH="$PROJECT_ROOT/pubspec.yaml"

# Function to extract version from pubspec.yaml
get_version() {
  if [ ! -f "$PUBSPEC_PATH" ]; then
    echo "Error: pubspec.yaml not found at $PUBSPEC_PATH" >&2
    exit 1
  fi

  grep '^version:' "$PUBSPEC_PATH" | head -1 | awk '{print $2}' | cut -d'+' -f1
}

# Function to generate changelog from git commits since last tag
generate_changelog() {
  cd "$PROJECT_ROOT"

  # Get the previous tag
  PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

  if [ -z "$PREV_TAG" ]; then
    # No previous tag, get all commits
    echo "Initial release"
    echo ""
    git log --pretty=format:"- %s" --reverse
  else
    # Get commits since previous tag
    COMMIT_COUNT=$(git rev-list "$PREV_TAG"..HEAD --count)

    if [ "$COMMIT_COUNT" -eq 0 ]; then
      echo "No changes since $PREV_TAG"
    else
      echo "Changes since $PREV_TAG:"
      echo ""

      # Group commits by type
      {
        # Features
        FEATURES=$(git log "$PREV_TAG"..HEAD --pretty=format:"%s" --grep="^feat" --grep="^feature" -i | sed 's/^/- /')
        if [ -n "$FEATURES" ]; then
          echo "### Features"
          echo "$FEATURES"
          echo ""
        fi

        # Fixes
        FIXES=$(git log "$PREV_TAG"..HEAD --pretty=format:"%s" --grep="^fix" -i | sed 's/^/- /')
        if [ -n "$FIXES" ]; then
          echo "### Bug Fixes"
          echo "$FIXES"
          echo ""
        fi

        # Other changes
        OTHER=$(git log "$PREV_TAG"..HEAD --pretty=format:"%s" --invert-grep --grep="^feat" --grep="^feature" --grep="^fix" -i | sed 's/^/- /')
        if [ -n "$OTHER" ]; then
          echo "### Other Changes"
          echo "$OTHER"
        fi
      } | grep -v '^$' || echo "- Various improvements and updates"
    fi
  fi
}

# Main logic
case "${1:-version}" in
  version)
    get_version
    ;;
  changelog)
    generate_changelog
    ;;
  *)
    echo "Usage: $0 [version|changelog]" >&2
    echo "  version   - Print version number from pubspec.yaml (default)" >&2
    echo "  changelog - Generate changelog from git commits" >&2
    exit 1
    ;;
esac
