# CI/CD Setup Guide

Quick reference for setting up and maintaining GitHub Actions CI/CD pipeline.

## Quick Start

1. Configure all required GitHub Secrets (see below)
2. Push code to trigger tests
3. Use `bump-version.yml`, then run the target channel release workflow

## GitHub Secrets Reference

| Secret Name | Description | How to Get It |
|------------|-------------|---------------|
| `APPLE_DEVELOPER_CERTIFICATE_P12` | Base64-encoded .p12 certificate | Export from Keychain, then: `base64 -i cert.p12 \| pbcopy` |
| `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` | Password for .p12 file | Password you set when exporting |
| `DEVELOPER_ID` | Full Developer ID string | From Keychain: "Developer ID Application: Name (TEAM)" |
| `APPLE_ID` | Apple ID email | Your Apple Developer account email |
| `APPLE_ID_PASSWORD` | App-specific password | Generate at appleid.apple.com → Security |
| `TEAM_ID` | Apple Developer Team ID | developer.apple.com/account → Membership |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for Sparkle updates | `./Pods/Sparkle/bin/generate_keys` |

## Workflow Triggers

### Test Workflow
- **File**: `.github/workflows/test.yml`
- **Triggers**:
  - Push to `master`
  - Pull requests to `master`
  - Skips docs/spec-only changes via `paths-ignore`
- **Concurrency**: Cancels outdated runs for the same ref.
- **Actions**:
  - `dart` job on `ubuntu-latest`: `make lint-flutter`,
    then `make test-flutter`
  - `native` job on `macos-latest` after `dart` passes: CocoaPods install,
    cached portable SwiftLint, `make lint-swift`, then `make test-macos`

### Release Channels

The project uses three release channels with separate workflows,
appcast feeds, and bundle identifiers:

| Channel | Workflow | Feed | Bundle ID suffix | Version format |
|---------|----------|------|-------------------|----------------|
| **Stable** | `release-stable.yml` | `appcast.xml` | *(none)* | `X.Y.Z` |
| **Beta** | `release-beta.yml` | `appcast-beta.xml` | `.beta` | `X.Y.Z-beta.N` |
| **Nightly** | `release-nightly.yml` | `appcast-nightly.xml` | `.nightly` | `X.Y.Z-nightly.YYYYMMDD.N` |

Each channel installs side-by-side (different bundle IDs) and
checks its own Sparkle appcast feed for updates.

### Bump Version Workflow
- **File**: `.github/workflows/bump-version.yml`
- **Trigger**: Manual `workflow_dispatch`
- **Inputs**: channel, version, build\_number (`auto` or int),
  target\_branch
- **Action**: Validates version against channel policy, bumps
  `pubspec.yaml`, commits and pushes.

### Release Stable Workflow
- **File**: `.github/workflows/release-stable.yml`
- **Trigger**: Manual `workflow_dispatch`
- **Requirement**: Must run from `master` branch.

### Release Beta Workflow
- **File**: `.github/workflows/release-beta.yml`
- **Trigger**: Manual `workflow_dispatch`
- **Requirement**: Version must match `X.Y.Z-beta.N`.

### Release Nightly Workflow
- **File**: `.github/workflows/release-nightly.yml`
- **Trigger**: Manual `workflow_dispatch`
- **Auto-cleanup**: Keeps only last 5 nightly releases.

The release workflow is split into 3 separate jobs to handle long notarization times:

| Job | Timeout | Description |
|-----|---------|-------------|
| `build-and-sign` | 30 min | Build Flutter app, sign all binaries |
| `notarize` | 60 min | Submit to Apple notarization, staple ticket |
| `release` | 15 min | Create DMG, Sparkle signature, GitHub Release |

Each job uploads artifacts that can be reused if a later job fails.

## Release Steps

### 1. Bump Version
- Go to GitHub → Actions → **Bump Version** → **Run workflow**.
- Choose the channel, version, build number (`auto` is allowed), and branch.
- Wait for the workflow to commit the updated `pubspec.yaml`.

### 2. Run Channel Release
- Stable: run **Release Stable** from `master` with version `X.Y.Z`.
- Beta: run **Release Beta** with version `X.Y.Z-beta.N`.
- Nightly: run **Release Nightly** manually.

### 3. Monitor Release
- Go to GitHub → Actions tab
- Watch the selected channel workflow
- Each job (`build-and-sign` → `notarize` → `release`) runs separately
- Once complete, check the Releases page

### 4. Restart Failed Release

If a job fails after artifacts were uploaded, restart from that stage:

1. Go to **Actions** tab in GitHub
2. Click the same channel workflow on the left
3. Click **Run workflow** button (top right)
4. Fill in the form:
  - **Branch**: `master` for Stable, or the same source branch for prerelease
   - **Version**: `1.0.1` (same version that failed, without `v` prefix)
   - **Start from job**: select `notarize` or `release` depending on which failed
  - **Artifact run ID**: run ID that produced the signed/notarized artifact
  - **Nightly version**: required only when restarting Nightly
5. Click **Run workflow**

The workflow downloads the artifact from the supplied run ID and continues.

**Common restart scenarios:**

| If This Failed | Restart From | Notes |
|---------------|--------------|-------|
| Notarization timed out (60 min) | `notarize` | Apple servers may be slow |
| DMG creation failed | `release` | Notarization already done |
| GitHub Release failed | `release` | Artifact still available |

### 5. Post-Release
The workflow updates the channel appcast only after the GitHub Release asset is
uploaded successfully.

## Local Testing

### Test Release Locally
```bash
# One-time setup
make fastlane-setup

# Configure credentials
export APPLE_ID="your@email.com"
export TEAM_ID="YOURTEAMID"
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "app-specific-password"

# Run release
DEVELOPER_ID="Developer ID Application: Name (TEAM)" make full-release
```

### Test Individual Steps
```bash
# Build only
make release

# Sign and notarize
DEVELOPER_ID="..." make notarize

# Create DMG
make dmg

# Sign for Sparkle
make sign-dmg

# Verify
make verify
```

## Certificate Management

### Export Developer ID Certificate

1. Open **Keychain Access**
2. Select **login** keychain
3. Find "Developer ID Application: Account Name"
4. Right-click → Export "Developer ID Application..."
5. Save as `DeveloperID.p12`
6. Set a strong password
7. Encode for GitHub:
   ```bash
   base64 -i DeveloperID.p12 | pbcopy
   ```
8. Paste into GitHub Secret

### Generate App-Specific Password

1. Visit [appleid.apple.com](https://appleid.apple.com)
2. Sign In → Security section
3. App-Specific Passwords → Generate
4. Label: "GitHub Actions Notarization"
5. Copy password to GitHub Secret

### Generate Sparkle Keys

```bash
cd macos
./Pods/Sparkle/bin/generate_keys

# Output includes:
# - Public key (for app)
# - Private key (for GitHub Secret)
```

## Troubleshooting

### Build Fails
- **Check**: All dependencies installed?
- **Verify**: `flutter doctor -v`
- **Action**: Review GitHub Actions logs

### Code Signing Fails
- **Check**: Certificate not expired?
- **Verify**: `security find-identity -v -p codesigning`
- **Action**: Re-export certificate

### Notarization Fails
- **Check**: App-specific password valid?
- **Verify**: Team ID matches account
- **Action**: Generate new app-specific password

### Notarization Times Out
Apple's notarization service can sometimes take 30-60+ minutes, especially during high-load periods.

- **Check**: Go to Actions → select failed run → check `notarize` job logs
- **Verify**: Run `xcrun notarytool history --keychain-profile "notarytool-profile"` locally
- **Action**: Use manual restart (see "Restart Failed Release" section above)

The workflow has a 60-minute timeout for notarization. If Apple takes longer:
1. The job will fail with timeout
2. Restart workflow from `notarize` job
3. If repeatedly failing, check [Apple System Status](https://developer.apple.com/system-status/)

### DMG Not Created
- **Check**: Build completed successfully?
- **Verify**: App exists in build directory
- **Action**: Check disk space, permissions

### Sparkle Signature Empty
- **Check**: Sparkle pods installed?
- **Verify**: `./Pods/Sparkle/bin/sign_update` exists
- **Action**: Run `pod install` in macos/

## File Structure

```
.github/
  workflows/
    test.yml          # Test workflow
    bump-version.yml  # Version bump workflow
    release-stable.yml
    release-beta.yml
    release-nightly.yml
scripts/
  import_certificates.sh  # CI certificate setup
  extract_version.sh      # Version extraction
macos/
  fastlane/
    Fastfile          # Release automation
docs/
  ci-cd-setup.md      # This file
```

## Security Notes

- All secrets are encrypted by GitHub
- Certificates are imported to temporary keychain
- Keychain is deleted after build
- App-specific passwords limit scope
- Private keys never exposed in logs

## Related Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Fastlane Documentation](https://docs.fastlane.tools)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Sparkle Framework](https://sparkle-project.org)

## Support

For issues with CI/CD:
1. Check GitHub Actions logs
2. Review this documentation
3. Test locally with `make full-release`
4. Check Apple Developer account status
