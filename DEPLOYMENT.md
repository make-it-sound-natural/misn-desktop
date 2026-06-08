# Deployment

This repository ships a **macOS desktop application**, not a hosted service.
“Production deployment” here means **distributing a signed, notarized app**
and operating the **update feed** end users rely on. Runtime configuration is
almost entirely **on-device** (user-entered API keys and local preferences).

## Table of contents

- [Overview](#overview)
- [End-user runtime](#end-user-runtime)
  - [Credentials and configuration](#credentials-and-configuration)
  - [Network and external services](#network-and-external-services)
  - [System permissions](#system-permissions)
- [Automated release (GitHub Actions)](#automated-release-github-actions)
  - [Required repository secrets](#required-repository-secrets)
  - [Optional update hosting variables](#optional-update-hosting-variables)
  - [Sparkle update signing](#sparkle-update-signing)
- [Logging](#logging)
- [Error reporting](#error-reporting)

## Overview

| Aspect | Detail |
| --- | --- |
| Deployable artifact | Signed, notarized `.app` packaged as a `.dmg`; updates via **Sparkle** |
| Runtime environment variables | None for production config; debug-only variables can enable extra local logging/artifacts |
| Central infrastructure | **None** — no database, cache, or app server |
| Primary external dependencies | **OpenAI** and **OpenRouter** HTTPS APIs (user-supplied keys) |

For local development and build commands, see [DEVELOPMENT.md](DEVELOPMENT.md).

## End-user runtime

### Credentials and configuration

| Item | Purpose | Required | Where it lives |
| --- | --- | --- | --- |
| OpenAI API key | Calls OpenAI chat completions | If provider is OpenAI | macOS **Keychain** in release builds |
| OpenRouter API key | Calls OpenRouter chat completions | If provider is OpenRouter | macOS **Keychain** in release builds |
| Provider and model | Routing and model selection | Has defaults | SharedPreferences |

Secrets are **never** committed; users enter keys in the app UI. There is no
production `.env` file or server-side secret store for the client. Debug builds
store API keys in UserDefaults under `dev_only_*` keys so tests and local debug
runs do not require real Keychain writes.

### Network and external services

The native layer sends LLM requests to:

| Service | Endpoint (code) | Purpose |
| --- | --- | --- |
| OpenAI | `https://api.openai.com/v1/chat/completions` | Default provider |
| OpenRouter | `https://openrouter.ai/api/v1/chat/completions` | Alternate provider |

**Sparkle** checks for updates using the feed URL in `macos/Runner/Info.plist`
(`SUFeedURL`), which points at the repository’s **`appcast.xml`** (hosted on
GitHub). Release automation updates that file when a new DMG is published.
Beta and Nightly builds are configured at build time to use
`appcast-beta.xml` and `appcast-nightly.xml`.

Outbound HTTPS access to the chosen API host (and to GitHub for the appcast)
must be allowed wherever the app runs (typical macOS setups allow this by
default).

### System permissions

The app requires **Accessibility** permission for global shortcuts and
text automation. Users grant this in **System Settings** when prompted; this is
not configurable via environment variables.

## Automated release (GitHub Actions)

Releases are produced by channel workflows in `.github/workflows/`:
`release-stable.yml`, `release-beta.yml`, and `release-nightly.yml`. Operators
maintaining releases must ensure the following **repository configuration**
exists. Do not paste real secret values into issues or docs.

### Required repository secrets

These map to GitHub Actions **secrets** used during build, not to application
runtime environment variables.

| Secret | Purpose |
| --- | --- |
| `APPLE_DEVELOPER_CERTIFICATE_P12` | Base64-encoded Developer ID **.p12** for signing |
| `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` | Password for the `.p12` import |
| `DEVELOPER_ID` | Codesign identity name (e.g. `Developer ID Application: …`) |
| `APPLE_ID` | Apple ID for **notarytool** |
| `APPLE_ID_PASSWORD` | App-specific password (or notary credential) for notarytool |
| `TEAM_ID` | Apple Developer Team ID |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key used to sign DMG updates for Sparkle appcasts |

The certificate import script `scripts/import_certificates.sh` expects
`CERTIFICATE_P12` and `CERTIFICATE_PASSWORD` in the environment (set from the
first two secrets in CI).

### Optional update hosting variables

By default, `UPDATE_PUBLISH_TARGET` is empty or `github`, so release workflows
skip external update publishing and rely on GitHub release assets/appcast files.
`scripts/publish_update_files.sh` also supports these targets:

`cloudflare_pages` requires repository variables `UPDATE_BASE_URL`,
`UPDATE_PUBLISH_TARGET`, `CLOUDFLARE_PAGES_PROJECT`, and
`CLOUDFLARE_PAGES_BRANCH`. It also requires secrets `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID`.

`ssh` requires repository variables `UPDATE_BASE_URL`, `UPDATE_PUBLISH_TARGET`,
and `UPDATE_SSH_PATH`. `UPDATE_SSH_PORT` is optional and defaults to `22`.
It also requires secrets `UPDATE_SSH_HOST`, `UPDATE_SSH_USER`, and
`UPDATE_SSH_PRIVATE_KEY`.

`UPDATE_BASE_URL` also lets channel workflows configure the built app and
appcast URLs to point at an external update host instead of GitHub assets.

### Sparkle update signing

- The **public** EdDSA key must be present in `macos/Runner/Info.plist` as
  `SUPublicEDKey` (see Sparkle’s `generate_keys` tooling under
  `macos/Pods/Sparkle/bin/`).
- The **private** key must be available only in CI (e.g. `SPARKLE_PRIVATE_KEY`)
  to sign each release DMG so `appcast.xml` can include a valid
  `sparkle:edSignature`.

## Logging

| Item | Detail |
| --- | --- |
| Library | `package:logging` with `dart:developer` (`lib/utils/logger.dart`) |
| Level | `Logger.root.level = Level.ALL` |
| Output | Structured messages via `developer.log`, plus a formatted line to stderr via `print` for visibility |

Logs are **local to the machine** (Console / terminal). There is no configured
shipment to a remote log aggregator.

Debug-only environment variables:

| Variable | Purpose |
| --- | --- |
| `MISN_LOG_FULL_LLM_CONTEXT=1` | Logs full LLM text context instead of hiding it in debug logs. |
| `MISN_SAVE_SCREENSHOT_CONTEXT=1` | Saves screenshot-context images for local debugging. |
| `MISN_SCREENSHOT_CONTEXT_DIR` | Overrides the debug screenshot-context output directory. |

## Error reporting

There is **no** integrated crash or error reporting SDK (no Sentry, Bugsnag, or
similar) in this codebase. Failures surface in-app or in local logs.
