# AGENTS.md

Working reference for **AI coding agents** and contributors: patterns, layout,
verification commands, and rules. **Environment setup** (install, clone, IDE) is in
[DEVELOPMENT.md](DEVELOPMENT.md) and [README.md](README.md), not here.

## Table of contents

1. [Project overview](#project-overview)
2. [Technical context](#technical-context)
3. [Project structure](#project-structure)
4. [Build and test commands](#build-and-test-commands)
5. [Contribution instructions](#contribution-instructions)
6. [Code guidelines](#code-guidelines)
   - [System design](#system-design)
   - [Architecture](#architecture)
   - [Code quality](#code-quality)
   - [Testing](#testing)
   - [Dependency management](#dependency-management)
   - [Configuration and documentation](#configuration-and-documentation)
   - [Markdown formatting](#markdown-formatting)
   - [Other conventions](#other-conventions)

## Project overview

**Make It Sound Natural** is a **macOS desktop** app: Flutter UI plus native
Swift for global shortcuts, accessibility, clipboard, and LLM calls. Users
select text in any app, trigger a shortcut, and get rewritten variants (OpenAI
or compatible providers). Settings, API keys, and prompts stay local; the app
is **not** a web or mobile target—do not add iOS, Android, or web code here.

## Technical context

| Field | Detail |
| --- | --- |
| **Languages** | Dart (Flutter), Swift (macOS runner) |
| **Dart SDK** | `>=3.8.0 <4.0.0` (see `pubspec.yaml`) |
| **Primary deps** | Flutter SDK, app deps in `pubspec.yaml`, CocoaPods |
| **Storage** | `shared_preferences` (settings), macOS Keychain (API keys); no server DB |
| **Testing** | `flutter_test` / `test/`; XCTest in `macos/RunnerTests/` |
| **Target platform** | **macOS only** |
| **Project type** | Desktop application (hybrid Flutter + native) |
| **Lint** | `very_good_analysis` (Dart); SwiftLint (Swift) |

## Project structure

```text
├── AGENTS.md                 # This file (agent + contributor rules)
├── Makefile                  # build, lint, test, release helpers
├── pubspec.yaml              # Dart deps and app version
├── analysis_options.yaml     # Dart analyzer / linter (Very Good Analysis)
├── appcast.xml               # Sparkle feed – Stable channel
├── appcast-beta.xml          # Sparkle feed – Beta channel
├── appcast-nightly.xml       # Sparkle feed – Nightly channel
├── lib/                      # Flutter/Dart UI and logic
│   ├── main.dart             # App entry
│   ├── screens/              # Home, onboarding, settings sections
│   ├── widgets/              # Shared UI
│   ├── services/             # OpenAI, settings, shortcuts, updates, etc.
│   ├── models/               # Data types (e.g. correction variants)
│   ├── constants/            # Method channel method names, defaults, status
│   ├── theme/                # Theming
│   ├── utils/                # Logging, formatters
│   └── l10n/                 # ARB sources + ignored generated localizations
├── tool/                     # Dart CLI tooling for release automation
│   ├── release_manager.dart  # Entrypoint: dart run tool/release_manager.dart
│   └── release_manager/      # Channel config, version policy, CLI commands
├── test/                     # Dart unit/widget tests
│   └── tool/                 # Tests for release_manager CLI
├── docs/
│   ├── design-system.md      # Compact desktop UI layout rules and tokens
│   └── ci-cd-setup.md        # CI/CD overview
├── .github/workflows/        # CI/CD workflows
│   ├── test.yml              # PR / push test pipeline
│   ├── bump-version.yml      # Bump pubspec version (dispatch)
│   ├── release-stable.yml    # Stable release (dispatch from master)
│   ├── release-beta.yml      # Beta release (dispatch)
│   └── release-nightly.yml   # Nightly release (dispatch)
└── macos/
    ├── Runner.xcworkspace    # Open this for Xcode (after pod install)
    ├── Runner/               # Swift: app delegate, bridge, shortcuts, bubble
    │   # Key files: MethodChannelHandler, ShortcutHandler, LLMService,
    │   # ClipboardService, ShortcutManager, ContextCapturer, StatusBubble*,
    │   # StatusBubbleControlling (test seam), VariantHandler, …
    └── RunnerTests/          # XCTest (dispatch, LLM error parser, bubble policy)
```

## Build and test commands

| Action | Command |
| --- | --- |
| Run app (debug) | `make start` or `flutter run -d macos` |
| Build macOS | `make build` or `flutter build macos` |
| **Format Dart (apply)** | `make format` or `dart format .` |
| **Format Dart (check only)** | `make format-check` or `dart format --output=none --set-exit-if-changed .` |
| Analyze Dart | `make lint-flutter` (runs **format-check** first) or `flutter analyze` alone |
| Lint Swift | `make lint-swift` (requires SwiftLint) |
| Check localizations | `make l10n-check` |
| Lint all | `make lint` (format-check + Flutter analyze + SwiftLint) |
| **All tests** | `make test` (Flutter tests, then macOS XCTest) |
| Flutter tests only | `make test-flutter` |
| macOS XCTest only | `make test-macos` (needs `cd macos && pod install`) |
| Clean | `make clean` |

## Contribution instructions

- You MUST **keep Dart formatting clean on every change**—CI fails if any file
  would be rewritten. **Always** run the same check CI uses before you finish:

  - `dart format --output=none --set-exit-if-changed .`
    (exit code **1** means one or more files need formatting—run `make format`
    or `dart format .`, then run the check again.)

  **`make lint`** and **`make lint-flutter`** already run **`format-check`**
  first, so a passing `make lint` implies Dart format + analyzer + SwiftLint.

  For a quick pass without Swift: `make format-check` then `flutter analyze`.

- You MUST add or update **unit/widget tests** for changed Dart logic and
  **XCTest** when changing native behavior covered by `RunnerTests/`.

- You MUST run **`make test`** so both Flutter tests and macOS XCTest pass.

- When changing Swift, you MUST also run a debug macOS build (`make start` or
  `flutter build macos --debug --no-pub`) and scan the build output for Swift
  compiler warnings. `make test`, release builds, and SwiftLint can pass while
  Xcode still reports debug-only compiler warnings such as unreachable code.

- When you change folder layout or entrypoints, update the **Project
  structure** section in this file so it stays accurate.

- If a task is essentially “refactor or standardize” behavior, capture the
  rule in **Code guidelines** (or **Other conventions**) here when it should
  stick.

- After implementing changes, you MUST confirm new code matches **Code
  guidelines** in this document.

- Do **not** add mobile or web platform code; this repo is **macOS-only**.

## Code guidelines

### System design

Design for a **desktop** environment:

- The app runs as a **long-lived process**—release file handles, timers, and
  monitors when no longer needed; do not rely on process exit only.
- Use the **framework’s concurrency model** (Dart `async`/`await`, Swift main
  queue + `DispatchQueue`) instead of ad hoc shared mutable state across
  threads.
- **Persist** user settings and restore them on launch (`shared_preferences` on
  Dart; macOS Keychain for API keys; UserDefaults where appropriate on native).
- Keep **UI responsive**: network, paste simulation, and LLM calls must not
  block the UI thread; show progress (e.g. status bubble) for long work.
- Support **graceful quit**: save state, tear down shortcuts/monitors where
  applicable.
- **macOS-only**: no assumptions that code runs on iOS or in a browser.

### Architecture

- **Separation of concerns** — UI in `lib/screens` / `widgets`; API and prefs in
  `lib/services`; native OS integration in `macos/Runner`.
- **Single responsibility** — small widgets and focused services; avoid
  “god” screens (extract sub-widgets; see file-size hints below).
- **Dependency direction** — Dart depends on abstractions (`services`); native
  calls Flutter via `MethodChannelHandler`; avoid Flutter importing Swift.
- **Explicit boundaries** — method channel method names live in
  `lib/constants/method_channel_methods.dart`; mirror names in Swift.
- **Data flow clarity** — shortcut → capture → LLM → paste / errors flow
  through `ShortcutHandler`, `VariantHandler`, `LLMService`, and channel
  callbacks predictably.
- **Minimize coupling** — `StatusBubbleControlling` injects the bubble for
  `ShortcutHandler` tests without a real `NSPanel`.
- **Make invalid states impossible** — prefer enums, typed models, and
  migration fallbacks over stringly-typed state where the UI can persist values.
- **Observability** — use `dart:developer` `log` in Dart; `os_log` / structured
  logging patterns in Swift where used.
- **Keep it boring** — prefer Flutter, AppKit, and Swift standard patterns over
  custom frameworks unless they remove real complexity.

Layers (top to bottom):

```text
Flutter UI (screens, widgets)
      ↓ method channel
MethodChannelHandler + ShortcutHandler + domain Swift services
      ↓
macOS APIs (Accessibility, clipboard, Carbon shortcuts, URLSession)
```

Flutter UI and tests **must not** import Swift. Swift **must not** embed
business rules that belong in shared Dart unless required for OS integration.

**Known exclusions** (acceptable for now):

- Some Swift types (e.g. `ShortcutHandler`) exceed SwiftLint size limits;
  prefer new code in small types; refactor opportunistically.

### Code quality

- **Dart**: follow **Effective Dart**; null-safe code; avoid `!` unless
  proven; `async`/`await` for async work; `Stream`s for event sequences; pattern
  matching and exhaustive `switch` where useful; `try`/`catch` with sensible
  types; arrow syntax for trivial one-liners; `///` on **public** APIs
  (`public_member_api_docs` is enabled via `analysis_options.yaml`, which
  includes `package:very_good_analysis`).
- **Flutter UI**: prefer **immutable** widgets; **composition** over
  inheritance; small **private `Widget` classes** instead of methods that return
  widgets; split large **`build()`** methods; use **`const`** where possible;
  avoid heavy work **inside `build()`** (network, parsing, allocations). For
  long lists use **`ListView.builder`** / sliver builders, not unbounded
  eager children.
- **Swift**: follow Swift API Design Guidelines; SwiftLint
  (`.swiftlint.yml`)—notable rules include `empty_count` and
  `force_unwrapping`; exclude `Flutter/GeneratedPluginRegistrant.swift` from
  lint noise. Prefer `guard`, optional chaining, and `Result` / thrown errors;
  avoid retain cycles (`weak` / `unowned` where appropriate).
- **Line length**: aim for **80 characters** per line in new code (Dart and
  Swift).
- **Naming**: Dart — `PascalCase` types, `camelCase` members, `snake_case`
  files; Swift — `PascalCase` types, `camelCase` members.
- **Errors**: surface user-visible failures (SnackBar, native error bubble);
  do not swallow errors silently.
- **Logging**: `dart:developer` `log` in Dart; avoid raw `print` in production
  paths.
- **File size (Dart)**: keep **`State` classes under ~400 lines**; extract
  child widgets if a screen mixes unrelated concerns. Keep **private helper
  widgets** in the same file when tightly coupled and **under ~150 lines**;
  move reusable pieces to `lib/widgets/`. Target **~500 lines max per screen
  file**—larger files signal a need to split. **One logical concern per
  stateful widget** (e.g. one area handles “update checks”, not all settings).

### Testing

- **Dart**: tests under `test/`; use `flutter_test`; Arrange-Act-Assert.
- **Native**: `macos/RunnerTests/` — XCTest; `@testable import` the app module
  (e.g. `Make_It_Sound_Natural`).
- **`make test`** runs **both** stacks; CI runs `pod install` then `make test`.
- **Settings compatibility**: changing persisted keys or option values needs
  migration/fallback and a test so stale saves do not break UI.
- **Status bubble policy**: after success, `VariantHandler` calls
  `updateState(.success)` which schedules auto-dismiss. Do **not** call
  `hide()` from `variantHandler(_:didCompleteSuccessfully:)` — that raced the
  timer. See `ShortcutHandlerVariantCompletionTests`.

### Dependency management

- Prefer **pub.dev** packages that are widely used and maintained; justify new
  dependencies (smaller attack surface and bundle); when suggesting a new
  package, **briefly explain** what it buys the project.
- Prefer built-in Dart, Flutter, Swift, and AppKit APIs when they adequately
  solve the problem. Do not add niche packages for small helper behavior.
- Use the latest stable version compatible with `>=3.8.0 <4.0.0` when adding a
  Dart package, and verify it against pub.dev before editing `pubspec.yaml`.
- **pubspec.yaml** uses compatible ranges (`^`); **`pubspec.lock`** pins
  concrete versions—commit lockfile changes with dependency updates. This is the
  current project convention even though exact manifest pins reduce surprise.
- **Commands**: `flutter pub add <name>`; `flutter pub add dev:<name>` for dev
  dependencies; `dart pub remove <name>` to remove.
- When adding a new package, prefer the **latest stable** version appropriate
  for the Dart SDK constraint.

### Configuration and documentation

- **User config**: API keys in macOS Keychain; model, shortcuts, and other
  preferences in local settings. Never commit secrets.
- **Settings defaults**: persisted fallback values (provider, model, variant,
  shortcuts, and similar settings) live in `lib/constants/app_defaults.dart`.
  Services, widgets, and tests should reference `AppDefaults` instead of
  repeating string literals; add or update `SettingsService` fallback tests when
  a new saved setting gets a default.
- **Native defaults and provider IDs**: keep Swift defaults and shared provider
  IDs clear by centralizing them in `macos/Runner/AppDefaults.swift` when they
  are referenced across native services/tests or used as persisted fallbacks.
  Local one-off strings are fine; repeated provider/default literals should use
  named constants for readability and consistency.
- **Localization checks**: use `make l10n-check` after editing ARB files to
  catch missing, extra, or untranslated messages before generated localization
  code is refreshed.
- **Update this file** when build/test commands or top-level layout change.
- **User-facing install**: [README.md](README.md); **local dev workflow**:
  [DEVELOPMENT.md](DEVELOPMENT.md); **CI overview**: `docs/ci-cd-setup.md` when
  relevant.
- **Documentation style**: `///` **dartdoc** on public Dart APIs; `///` on
  public Swift APIs where applicable. Comment **why**, not what, for
  non-obvious code; keep comments short.

### Markdown formatting

All Markdown in this repo **SHOULD** follow:

- **Line length**: at most **80 characters** per line where practical.
- **Unordered lists**: use `-`; indent nested items by **4 spaces**.
- **Emphasis**: use `*` for *italic* and `**` for **bold** (not underscores).
- **Headings**: avoid duplicate heading text at different levels when possible.
- **Inline HTML**: avoid except `<a>`, `<p>`, `<details>`, `<summary>`, `<img>`.
- **Trailing spaces**: none; use a blank line instead of two-space line breaks.
- **Tables**: compact pipes if wide tables break 80 columns or linters.

### Other conventions

- **Flutter–Swift bridge**: `MethodChannelHandler.swift`; map types safely
  (String, Int, Double, Bool, List, Map). Channel name uses reverse-domain
  style. Propagate errors to Flutter and handle errors from Dart on both
  sides; remember channel callbacks may not always run on the thread you expect—
  document or dispatch to main when the UI is touched.
- **Constants**: `MethodChannelMethods` (camelCase method names); status enums
  with string values (`shortcut_status.dart`) for exhaustive switches; event
  IDs may use `snake_case`.
- **State management**: prefer built-in (`ValueNotifier`, `ChangeNotifier`,
  `ListenableBuilder`, `StreamBuilder`, `FutureBuilder`); no extra
  state-management package unless requested.
- **macOS window close behavior**: the red close button hides/orders out the
  existing `MainFlutterWindow` instead of destroying it or terminating the app.
  This keeps the Flutter engine, method channel, and native shortcut handlers
  alive so global shortcuts continue working while the window is hidden. Use
  app menu Quit, Cmd+Q, or the menu bar Quit item for full termination.
- **Local UI verification**: do not take screenshots, click, type, or otherwise
  drive the user's active desktop for visual smoke tests unless explicitly
  requested. Prefer XCTest/AppKit assertions, process/log checks, accessibility
  queries, or user confirmation. If visual automation is required, run it in an
  isolated environment such as CI, a separate macOS user session, or a VM.
- **Visual design**: every visual/UI change MUST follow
  [docs/design-system.md](docs/design-system.md) before implementation. Use
  shared tokens from `lib/theme/app_design_tokens.dart` and primitives from
  `lib/widgets/` before adding local spacing, panels, tabs, or settings rows.
  Keep the app compact, aligned to an 8 px rhythm, and consistent across
  Rewrite, Settings, and dialogs. If a visual change introduces or revises a
  reusable pattern, update `docs/design-system.md` in the same change.
- **Accessibility (macOS)**: target **~4.5:1** contrast for normal text;
  support larger system text where reasonable; use **`Semantics`** for custom
  controls; verify critical flows with **VoiceOver** when changing interaction.
- **Agent interaction**: assume the reader knows programming but may be new to
  Dart or Swift—explain language-specific details when helpful. If requirements
  are unclear, **ask** before building the wrong thing. Prefer **`make`**
  targets from this file for verification after edits.

```dart
// Method names: abstract class with static String constants (camelCase)
abstract class MethodChannelMethods {
  static const String setApiKey = 'setApiKey';
}

// Status-like values: enum with string backing for exhaustive switch
enum ShortcutStatus {
  success('success'),
  contextReplaced('context_replaced');
  final String value;
  const ShortcutStatus(this.value);
}
```
