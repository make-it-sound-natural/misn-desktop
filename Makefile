.PHONY: start build clean clean-xcode-derived clean-nightly-install format format-check lint lint-flutter lint-swift l10n-check test test-flutter test-macos release notarize dmg sign-dmg full-release verify version bump-version fastlane-setup toolchain pub-get

# Configuration
APP_NAME = Make It Sound Natural
BUNDLE_ID = dev.maximtop.makeitsoundnatural
NIGHTLY_APP_NAME = Make It Sound Natural Nightly
NIGHTLY_BUNDLE_ID = dev.maximtop.makeitsoundnatural.nightly
BUILD_DIR = build/macos/Build/Products/Release
VERSION = $(shell grep 'version:' pubspec.yaml | head -1 | awk '{print $$2}' | cut -d'+' -f1)
LOCAL_FLUTTER = $(CURDIR)/.fvm/flutter_sdk/bin/flutter
LOCAL_DART = $(CURDIR)/.fvm/flutter_sdk/bin/dart
FVM ?= $(shell if command -v fvm >/dev/null 2>&1; then \
		command -v fvm; \
	elif [ -x "$$HOME/.pub-cache/bin/fvm" ]; then \
		echo "$$HOME/.pub-cache/bin/fvm"; \
	fi)
FLUTTER ?= $(if $(wildcard $(LOCAL_FLUTTER)),$(LOCAL_FLUTTER),$(if $(FVM),$(FVM) flutter,flutter))
DART ?= $(if $(wildcard $(LOCAL_DART)),$(LOCAL_DART),$(if $(FVM),$(FVM) dart,dart))
SWIFTLINT ?= $(shell if [ -x /opt/homebrew/bin/swiftlint ]; then \
		echo /opt/homebrew/bin/swiftlint; \
	else \
		command -v swiftlint; \
	fi)

# ============================================================================
# Development
# ============================================================================

toolchain:
	@echo "FVM: $(FVM)"
	@echo "Flutter: $(FLUTTER)"
	@$(FLUTTER) --version
	@echo "Dart: $(DART)"
	@$(DART) --version

pub-get:
	@$(FLUTTER) pub get

# Note: "Failed to foreground app; open returned 1" is a harmless Flutter message
# for LSUIElement (agent) apps when `open` cannot foreground the bundle.
start: pub-get
	@MISN_SAVE_SCREENSHOT_CONTEXT=1 $(FLUTTER) run -d macos --no-pub

build: pub-get
	@$(FLUTTER) build macos --no-pub

# Flutter builds with -derivedDataPath under build/macos; Xcode may still use a
# default ~/Library/Developer/Xcode/DerivedData/Runner-* folder (e.g. from
# pod install or opening the workspace). Mixed state triggers Xcode warnings:
# "Stale file ... is located outside of the allowed root paths". This removes
# only this project's Runner-* folder (derived from BUILD_DIR).
clean-xcode-derived:
	@DD=$$(cd macos && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
		-configuration Debug -showBuildSettings 2>/dev/null \
		| grep '^[[:space:]]*BUILD_DIR =' | head -1 \
		| sed -E 's|.*/DerivedData/(Runner-[^/]+)/.*|\1|'); \
	if [ -n "$$DD" ] && [ -d "$$HOME/Library/Developer/Xcode/DerivedData/$$DD" ]; \
	then \
		rm -rf "$$HOME/Library/Developer/Xcode/DerivedData/$$DD"; \
		echo "Removed Xcode DerivedData $$DD"; \
	fi

clean:
	@$(FLUTTER) clean
	@rm -rf $(BUILD_DIR)/*.dmg
	@$(MAKE) clean-xcode-derived
	@echo "Cleaned build artifacts"

# Remove only Nightly app install and Nightly-specific local state.
clean-nightly-install:
	@osascript -e 'tell application "$(NIGHTLY_APP_NAME)" to quit' 2>/dev/null || true
	@pkill -x "$(NIGHTLY_APP_NAME)" 2>/dev/null || true
	@rm -rf "/Applications/$(NIGHTLY_APP_NAME).app"
	@defaults delete $(NIGHTLY_BUNDLE_ID) 2>/dev/null || true
	@rm -f "$$HOME/Library/Preferences/$(NIGHTLY_BUNDLE_ID).plist"
	@rm -f "$$HOME/Library/Preferences/ByHost/$(NIGHTLY_BUNDLE_ID)."*.plist
	@rm -rf "$$HOME/Library/Application Support/$(NIGHTLY_BUNDLE_ID)"
	@rm -rf "$$HOME/Library/Containers/$(NIGHTLY_BUNDLE_ID)"
	@rm -rf "$$HOME/Library/Application Scripts/$(NIGHTLY_BUNDLE_ID)"
	@rm -rf "$$HOME/Library/Saved Application State/$(NIGHTLY_BUNDLE_ID).savedState"
	@rm -rf "$$HOME/Library/Caches/$(NIGHTLY_BUNDLE_ID)"
	@rm -rf "$$HOME/Library/WebKit/$(NIGHTLY_BUNDLE_ID)"
	@rm -rf "$$HOME/Library/HTTPStorages/$(NIGHTLY_BUNDLE_ID)"
	@rm -f "$$HOME/Library/HTTPStorages/$(NIGHTLY_BUNDLE_ID).binarycookies"
	@security delete-generic-password -s $(NIGHTLY_BUNDLE_ID) \
		-a openai_api_key >/dev/null 2>&1 || true
	@security delete-generic-password -s $(NIGHTLY_BUNDLE_ID) \
		-a openrouter_api_key >/dev/null 2>&1 || true
	@tccutil reset All $(NIGHTLY_BUNDLE_ID) >/dev/null 2>&1 || true
	@rm -f "$$HOME/Downloads"/MakeItSoundNaturalNightly-*.dmg
	@echo "Removed Nightly app, prefs, caches, keychain items, TCC grants, and DMGs"

# Apply Dart style (fix formatting)
format:
	@$(DART) format .

# Fail if any Dart file would change (matches CI `dart format` step)
format-check:
	@$(DART) format --output=none --set-exit-if-changed .

# Lint all code (Flutter + Swift)
lint: lint-flutter lint-swift

# Lint Flutter/Dart code (format check first—same order as CI)
lint-flutter: pub-get format-check
	@echo "Linting Flutter/Dart files..."
	@$(FLUTTER) analyze

# Lint Swift code (requires: brew install swiftlint)
lint-swift:
	@echo "Linting Swift files..."
	@$(SWIFTLINT) lint --config .swiftlint.yml

# Verify localization files have matching keys and translated values
l10n-check: pub-get
	@$(DART) run tool/check_l10n.dart

# Run all tests: Flutter (`test/`) then native XCTest (`macos/RunnerTests/`)
test: test-flutter test-macos

# Flutter / Dart tests (--no-pub skips dependency check for faster runs)
test-flutter: pub-get
	@echo "Running Flutter tests..."
	@$(FLUTTER) test --no-pub

# Native XCTest (requires: `cd macos && pod install`; uses Runner.xcworkspace)
# `flutter build macos --config-only` materializes macos/Flutter/ephemeral/
# (FlutterInputs/Outputs.xcfilelist, etc.); without it, Xcode fails to load
# those file lists on fresh checkouts (e.g. CI).
test-macos: pub-get
	@echo "Running macOS XCTest..."
	@$(FLUTTER) build macos --config-only --no-pub
	@cd macos && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
		-destination 'platform=macOS' test

# ============================================================================
# Fastlane Setup (one-time)
# ============================================================================

# Install Fastlane and dependencies
fastlane-setup:
	@echo "Installing Fastlane dependencies..."
	@cd macos && bundle install
	@echo ""
	@echo "=== Fastlane Setup Complete ==="
	@echo ""
	@echo "Next, store your Apple credentials (one-time):"
	@echo "  export APPLE_ID=\"your@email.com\""
	@echo "  export TEAM_ID=\"YOURTEAMID\""
	@echo "  xcrun notarytool store-credentials \"notarytool-profile\" \\"
	@echo "    --apple-id \"\$$APPLE_ID\" \\"
	@echo "    --team-id \"\$$TEAM_ID\" \\"
	@echo "    --password \"app-specific-password\""
	@echo ""
	@echo "Generate Sparkle signing keys:"
	@echo "  cd macos && ./Pods/Sparkle/bin/generate_keys"
	@echo ""

# ============================================================================
# Release Workflow (via Fastlane)
# ============================================================================

# Build release version
release:
	@cd macos && bundle exec fastlane build

# Sign and notarize the app
# Usage: DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" make notarize
notarize:
	@if [ -z "$(DEVELOPER_ID)" ]; then \
		echo "Error: DEVELOPER_ID is required"; \
		echo "Usage: DEVELOPER_ID=\"Developer ID Application: Your Name (TEAMID)\" make notarize"; \
		exit 1; \
	fi
	@cd macos && bundle exec fastlane notarize_app developer_id:"$(DEVELOPER_ID)"

# Create DMG for distribution (run after notarize)
dmg:
	@cd macos && bundle exec fastlane create_dmg

# Sign DMG with Sparkle EdDSA key
sign-dmg:
	@cd macos && bundle exec fastlane sign_sparkle

# Verify app signature and notarization
verify:
	@cd macos && bundle exec fastlane verify

# Full release workflow
# Usage: DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" make full-release
full-release:
	@if [ -z "$(DEVELOPER_ID)" ]; then \
		echo "Error: DEVELOPER_ID is required"; \
		echo "Usage: DEVELOPER_ID=\"Developer ID Application: Your Name (TEAMID)\" make full-release"; \
		exit 1; \
	fi
	@cd macos && bundle exec fastlane release developer_id:"$(DEVELOPER_ID)"

# ============================================================================
# Version Management
# ============================================================================

version:
	@echo "Current version: $(VERSION)"

# Bump version (usage: make bump-version NEW_VERSION=1.0.1)
bump-version:
	@if [ -z "$(NEW_VERSION)" ]; then \
		echo "Usage: make bump-version NEW_VERSION=1.0.1"; \
		exit 1; \
	fi
	@sed -i '' "s/^version: .*/version: $(NEW_VERSION)+$$(($$(grep 'version:' pubspec.yaml | head -1 | awk '{print $$2}' | cut -d'+' -f2) + 1))/" pubspec.yaml
	@echo "Version bumped to $(NEW_VERSION)"

# ============================================================================
# Help
# ============================================================================

help:
	@echo "Make It Sound Natural - Build Commands"
	@echo ""
	@echo "Development:"
	@echo "  make toolchain      - Show Flutter/Dart tool paths used by Make"
	@echo "  make pub-get        - Resolve dependencies with the pinned Flutter SDK"
	@echo "  make start          - Run debug app with screenshot debug-save enabled"
	@echo "  make build          - Build debug version"
	@echo "  make clean          - Clean build artifacts and Xcode DerivedData"
	@echo "  make clean-xcode-derived - Remove only this project's Runner DerivedData"
	@echo "  make clean-nightly-install - Remove Nightly app and local Nightly state"
	@echo "  make format         - Apply dart format to all Dart files"
	@echo "  make format-check   - Fail if Dart format differs (CI gate)"
	@echo "  make lint           - format-check + Flutter analyze + SwiftLint"
	@echo "  make lint-flutter   - format-check + Flutter analyze"
	@echo "  make lint-swift     - Lint Swift code only (requires swiftlint)"
	@echo "  make l10n-check     - Verify localization key coverage"
	@echo "  make test           - Run Flutter tests + macOS XCTest"
	@echo "  make test-flutter   - Run Flutter tests only"
	@echo "  make test-macos     - Run macOS XCTest only (CocoaPods workspace)"
	@echo ""
	@echo "Setup (one-time):"
	@echo "  make fastlane-setup - Install Fastlane and show credential setup"
	@echo ""
	@echo "Release:"
	@echo "  make release        - Build release version"
	@echo "  make notarize       - Sign and notarize app (requires DEVELOPER_ID)"
	@echo "  make dmg            - Create DMG from notarized app"
	@echo "  make sign-dmg       - Sign DMG for Sparkle auto-updates"
	@echo "  make full-release   - Complete release workflow (requires DEVELOPER_ID)"
	@echo "  make verify         - Verify app signature and notarization"
	@echo ""
	@echo "Version:"
	@echo "  make version        - Show current version"
	@echo "  make bump-version NEW_VERSION=x.y.z - Bump version number"
	@echo ""
	@echo "Example release workflow:"
	@echo "  make fastlane-setup                    # One-time setup"
	@echo "  make bump-version NEW_VERSION=1.0.1   # Bump version"
	@echo "  DEVELOPER_ID=\"...\" make full-release  # Build, notarize, DMG"
	@echo "  # Update appcast.xml with Sparkle signature"
	@echo "  # Create GitHub release with DMG"
