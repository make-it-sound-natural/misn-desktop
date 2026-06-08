# TODO

## Manual Setup Steps (Do These First!)

### Step 1: Generate Sparkle EdDSA Keys
Run this command in the project root:
```bash
./macos/Pods/Sparkle/bin/generate_keys
```

This will output:
- **Public key** → copy this (looks like: `abcdef1234567890...`)
- **Private key** → stored in your macOS Keychain

### Step 2: Add Public Key to Info.plist
Edit `macos/Runner/Info.plist` and replace line 38:
```xml
<key>SUPublicEDKey</key>
<string>PASTE_YOUR_PUBLIC_KEY_HERE</string>
```

### Step 3: Export Private Key for CI
Run this command:
```bash
./macos/Pods/Sparkle/bin/generate_keys -x
```

This will output a long base64 string. Copy it.

### Step 4: Add GitHub Secret
1. Go to: https://github.com/make-it-sound-natural/misn-desktop/settings/secrets/actions
2. Click **"New repository secret"**
3. Name: `SPARKLE_PRIVATE_KEY`
4. Value: Paste the exported private key from Step 3
5. Click **"Add secret"**

---

## Pre-Release Testing Checklist

- [ ] **Create a test release**
  - Run **Bump Version** from GitHub Actions on a test branch
  - Run **Release Beta** or **Release Nightly** for that branch

- [ ] **Verify GitHub Actions workflow**
  - Check workflow runs successfully at: https://github.com/make-it-sound-natural/misn-desktop/actions
  - Verify the channel appcast is updated in the repo
  - Download the DMG from GitHub Releases

- [ ] **Test auto-update flow end-to-end**
  - Install an older version manually
  - Launch the app
  - Verify update notification appears
  - Verify update downloads correctly
  - Verify installation completes successfully
  - Verify signature validation works (no security warnings)

- [ ] **Verify settings migration**
  - Test that user settings persist after update
  - Verify no data loss occurs

---

## Future Improvements

- [x] Add screenshot context for shortcut rewrites
- [x] Add possibility to setup font size of the application
- [x] Dark theme support
- [ ] First-install AI Provider follow-ups:
  - Remove Test Connection from the primary setup UI.
  - Rely on rewrite-time errors for invalid keys.
  - Later surface auth failures near API key settings.
  - Put OpenRouter first in provider ordering.
  - Show only one built-in model: `google/gemini-3-flash-preview`.
- [ ] Add first-run onboarding for macOS permissions:
  - Explain why Accessibility is required before triggering the system prompt.
  - Guide the user to grant Accessibility during setup instead of after the
    first failed rewrite.
  - Introduce Screenshot context during onboarding so users know the feature
    exists and can enable it when useful.
  - Explain screenshot privacy before asking for Screen Recording permission.
  - Request optional permissions, such as Screen Recording, only when the
    related feature is enabled or first used.
  - Avoid showing both the macOS permission prompt and a custom permission
    window at the same time.
  - Let the macOS prompt's Open System Settings button handle the first
    permission request when possible.
  - Show the custom permission helper only after the user denies/dismisses the
    system prompt or returns with permission still missing.
  - Remove Reveal in Finder from the Screen Recording helper when the app is
    already listed in System Settings.
  - Do not tell users to drag the app into Screen Recording when macOS has
    already added the app entry after the permission request.
  - If macOS asks the user to quit and reopen after granting permission, persist
    the user's intended Screenshot context choice and enable it automatically
    after restart once permission is available.
- [ ] Add more comprehensive error handling for update failures
- [ ] Consider delta updates for faster downloads (Sparkle 2.x feature)
- [ ] Add analytics to track update adoption rates
- [ ] Add option for beta/alpha channel in settings
- [ ] Add history of conversions
- [ ] Add possibility to add your own custom variations
- [ ] Add possibility to pin application to the top
- [x] Add restore button for shortcuts settings
