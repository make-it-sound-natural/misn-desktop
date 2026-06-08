# Developing Make It Sound Natural

Guide for setting up a local environment, running the macOS Flutter app, and
contributing changes. End-user documentation lives in [README.md](README.md).
Code style and architecture expectations are in [AGENTS.md](AGENTS.md).

## Contents

- [Prerequisites](#prerequisites)
  - [Required](#required)
  - [Recommended](#recommended)
- [Getting started](#getting-started)
  - [Clone and install dependencies](#clone-and-install-dependencies)
  - [Run the app](#run-the-app)
  - [Configuration](#configuration)
- [Development workflow](#development-workflow)
  - [Branching and pull requests](#branching-and-pull-requests)
  - [Formatting and analysis](#formatting-and-analysis)
  - [Testing](#testing)
  - [Building](#building)
  - [IDE and debugging](#ide-and-debugging)
- [Common tasks](#common-tasks)
  - [Make targets](#make-targets)
  - [Native macOS workspace](#native-macos-workspace)
  - [Release-related commands](#release-related-commands)
- [Troubleshooting](#troubleshooting)
- [Additional resources](#additional-resources)

## Prerequisites

### Required

- **macOS** — Target runtime is macOS 10.15+ (see `macos/Podfile` `platform :osx`).
- **Xcode** — Current Xcode for your macOS version, with Command Line Tools
  (`xcode-select --install` if needed).
- **Flutter (stable)** — CI pins **Flutter 3.38.0** stable
  (`.github/workflows/test.yml`). Use the same version locally to match analysis,
  tests, and formatting checks on pull requests.
  - Recommended: install [FVM](https://fvm.app/) and run `fvm install` from the
    repo root. The project version is pinned in `.fvmrc`.
  - The `Makefile` uses `fvm flutter` / `fvm dart` automatically when FVM is
    installed, and falls back to global `flutter` / `dart` otherwise.
- **CocoaPods** — Required for `macos/` native dependencies. Install the
  [recommended way](https://guides.cocoapods.org/using/getting-started.html)
  for your setup (often `gem install cocoapods` or via Bundler in `macos/`).

**Dart SDK** — Declared in `pubspec.yaml` as `>=3.8.0 <4.0.0`; the Dart
version is the one bundled with your Flutter SDK.

### Recommended

- **SwiftLint** — Used by `make lint-swift` and CI (`brew install swiftlint`).
- **Ruby + Bundler** — For Fastlane/CocoaPods in `macos/` when running
  `make fastlane-setup` or Fastlane lanes (see `macos/Gemfile`).

## Getting started

### Clone and install dependencies

```bash
git clone <repository-url>
cd desktop   # or your clone folder name
fvm install
fvm flutter pub get
cd macos && pod install && cd ..
```

If `fvm` is not on your `PATH` after installing it with Dart, add:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

After changing Flutter plugins or the macOS embedding, run `pod install` again
under `macos/`.

### Run the app

```bash
make start
# Equivalent:
# flutter run -d macos --no-pub
```

The Makefile notes that **"Failed to foreground app; open returned 1"** can
appear for agent-style (`LSUIElement`) apps; it is usually harmless.

### Configuration

There is no committed `.env` file. Configure an **OpenAI or OpenRouter API key**
and shortcuts in the in-app **Settings** UI after launch. Grant **Accessibility**
permissions when macOS prompts, or global shortcuts and text injection will not
work.

## Development workflow

### Branching and pull requests

The default branch is **`master`** (`origin/HEAD` → `master`). CI runs on pushes
and pull requests targeting **`master`** (see `.github/workflows/test.yml`).

Typical flow:

1. Create a branch from `master`.
2. Run `make lint` and `make test` before opening a PR.
3. Open a PR against `master` and ensure the **Test** workflow passes.

### Formatting and analysis

- **Format (matches CI)—run before every PR:**

  ```bash
  make format-check
  # same as:
  dart format --output=none --set-exit-if-changed .
  ```

  To apply formatting:

  ```bash
  make format
  # same as: dart format .
  ```

- **Analyze Dart/Flutter** — `make lint-flutter` runs **`format-check` first**,
  then `flutter analyze`, using rules from `analysis_options.yaml` (extends
  [`very_good_analysis`](https://pub.dev/packages/very_good_analysis)).

- **Lint Swift** — `make lint-swift` runs `swiftlint lint --config .swiftlint.yml`.

- **Both stacks** — `make lint`.

Detailed conventions: [AGENTS.md](AGENTS.md).

### Testing

| Command | Purpose |
|--------|---------|
| `make test` | Flutter unit/widget tests (`test/`) then macOS **XCTest** (`macos/RunnerTests/`) |
| `make test-flutter` | `flutter test --no-pub` only |
| `make test-macos` | `xcodebuild … test` on `Runner.xcworkspace` |

Native XCTest requires a successful **`cd macos && pod install`** at least once.

### Building

| Command | Purpose |
|--------|---------|
| `make build` | `flutter build macos --no-pub` (release-mode app bundle under `build/`) |
| `make clean` | `flutter clean`, DMG cleanup under build dir, and project DerivedData cleanup |
| `make clean-xcode-derived` | Removes this project’s `Runner-*` DerivedData only |

### IDE and debugging

- **VS Code / Cursor / Android Studio** — Use the Flutter and Dart plugins;
  start with `make start` or the IDE’s Run/Debug for **macos**.
- **Native Swift** — Open `macos/Runner.xcworkspace` in Xcode to debug
  `macos/Runner` code, method channels, and XCTest.

## Common tasks

### Make targets

Run **`make help`** for the canonical list. Summary:

**Development:** `start`, `build`, `clean`, `clean-xcode-derived`, `lint`,
`lint-flutter`, `lint-swift`, `test`, `test-flutter`, `test-macos`.

**Setup:** `fastlane-setup` (Bundler gems in `macos/`, see printed next steps).

**Release / signing:** `release`, `notarize`, `dmg`, `sign-dmg`, `full-release`,
`verify`, `version`, `bump-version`. These need Apple signing credentials;
high-level automation and secrets are described in
[docs/ci-cd-setup.md](docs/ci-cd-setup.md).

### Native macOS workspace

- Always use **`macos/Runner.xcworkspace`**, not `Runner.xcodeproj`, when
  working in Xcode (CocoaPods).
- Minimum deployment target is aligned with **macOS 10.15** in the Podfile.

### Release-related commands

Signing, notarization, and GitHub Actions secrets are **not** duplicated here.
Use [DEPLOYMENT.md](DEPLOYMENT.md) and
[docs/ci-cd-setup.md](docs/ci-cd-setup.md) for pipeline and release
maintenance.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| **`pod install` fails** | Run `flutter pub get` from the repo root first; ensure CocoaPods is up to date; delete `macos/Pods` and `macos/Podfile.lock` only if you know the impact, then `pod install` again. |
| **Xcode “Stale file … outside allowed root”** | Run `make clean` or `make clean-xcode-derived` (see comments in the `Makefile`). |
| **`make test-macos` fails** | Run `cd macos && pod install`; open workspace and confirm **Runner** scheme builds. |
| **CI passes locally but fails on GitHub** | Align Flutter to **3.38.0** stable; run `dart format --output=none --set-exit-if-changed .` and `make lint` / `make test`. |
| **SwiftLint not found** | `brew install swiftlint` (PATH must include the binary for `make lint-swift`). |

## Additional resources

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Product overview, installation, and usage |
| [AGENTS.md](AGENTS.md) | Project layout, Dart/Swift conventions, testing notes |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Production distribution and runtime configuration |
| [docs/ci-cd-setup.md](docs/ci-cd-setup.md) | GitHub Actions, secrets, release workflow details |
| [.github/workflows/test.yml](.github/workflows/test.yml) | Exact CI steps and Flutter version |

There is no `CHANGELOG.md` in this repository at the time of writing; release
notes may live in GitHub Releases.
