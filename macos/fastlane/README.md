fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac build

```sh
[bundle exec] fastlane mac build
```

Build release version of the app

### mac notarize_app

```sh
[bundle exec] fastlane mac notarize_app
```

Sign and notarize the app for distribution

### mac create_dmg

```sh
[bundle exec] fastlane mac create_dmg
```

Create DMG for distribution

### mac sign_sparkle

```sh
[bundle exec] fastlane mac sign_sparkle
```

Sign DMG with Sparkle EdDSA key for auto-updates

### mac release

```sh
[bundle exec] fastlane mac release
```

Full release: build, notarize, create DMG, and sign for Sparkle

### mac verify

```sh
[bundle exec] fastlane mac verify
```

Verify app signature and notarization

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
