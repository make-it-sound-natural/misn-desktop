# Make It Sound Natural

[![Test](https://github.com/make-it-sound-natural/misn-desktop/actions/workflows/test.yml/badge.svg)](https://github.com/make-it-sound-natural/misn-desktop/actions/workflows/test.yml)
[![Stable Release](https://github.com/make-it-sound-natural/misn-desktop/actions/workflows/release-stable.yml/badge.svg)](https://github.com/make-it-sound-natural/misn-desktop/actions/workflows/release-stable.yml)

Make It Sound Natural is a macOS desktop app for rewriting selected text in
other applications. Select text, press a global shortcut, and choose a more
natural version to paste back in place.

The app is for users who write across many macOS apps and want quick rewrite
variants without copying text into a separate chat window.

## Key concepts

- **Provider**: the AI service used for rewrites. The app supports OpenAI and
  OpenRouter-compatible chat completion APIs.
- **API key**: the provider credential. Keys are entered in Settings and stored
  locally in macOS Keychain.
- **Shortcut**: the global keyboard shortcut that captures selected text and
  starts a rewrite.
- **Variant**: a rewrite style. Built-in variants include Balanced, Casual,
  Formal, and Concise.
- **Context**: optional background text that helps the model choose tone,
  wording, and target language.
- **Target profile**: saved language or style guidance used across variants.

## Requirements

- macOS 10.15 Catalina or later
- OpenAI or OpenRouter API key
- Accessibility permission, granted in macOS System Settings when prompted
- Screen Recording permission only if screenshot context is enabled

## Installation

Download the latest DMG from
[GitHub Releases](https://github.com/make-it-sound-natural/misn-desktop/releases),
open it, and drag the app to Applications.

On first launch, macOS may ask for confirmation because the app uses native
automation APIs. Grant Accessibility permission when prompted; without it the
global shortcut cannot capture and replace selected text.

## First setup

1. Open Make It Sound Natural.
2. Open Settings.
3. Choose OpenAI or OpenRouter.
4. Enter the matching API key.
5. Choose a default model and rewrite variant.
6. Set or confirm the global shortcut.
7. Grant Accessibility permission in System Settings when macOS prompts.

## Usage

### Rewrite selected text

1. Select text in any editable macOS app.
2. Press the configured rewrite shortcut.
3. Wait for the status bubble to show generated variants.
4. Choose a variant.
5. The chosen text replaces the original selection.

### Use context

Add context when the selected text needs background the model cannot infer from
the selection alone. Examples:

- desired audience or formality
- target language or regional English
- product names, terminology, or constraints
- surrounding conversation or document context

### Use App context

App context gives a rewrite the surrounding conversation or document without
typing it. It reads text from the app where you press the shortcut, through the
Accessibility permission the shortcut already needs. Choose the level in
Settings:

- **Off**: nothing is read.
- **Field text**: the text around your selection in the field you edit, plus
  the app name, window title, and field label. New installs start here.
- **Field and nearby text**: also the text shown above the field, such as the
  messages in a chat thread. Installs that already used screenshot context
  start here.

When nearby text is found, the screenshot is skipped, even if screenshot context
is on. Some apps do not expose their text through Accessibility. There App
context adds nothing and the screenshot is used, if it is on.

Electron apps such as Slack, Discord, and Notion expose no text until asked.
When a rewrite finds no readable text there, the app turns on that app's
accessibility tree. It stays on until the app quits and can raise that app's CPU
and memory use. That rewrite uses the screenshot, if it is on; later ones can
use App context.

### Configure variants and profiles

Use Settings to change the default variant, provider, model, shortcuts,
appearance, App context, screenshot context behavior, and target profiles.
Settings are stored locally on the Mac.

### Window behavior

Closing the main window with the red close button keeps the app running so
global shortcuts continue to work. Reopen the window from the Dock or menu bar
icon. Use Quit from the app menu or menu bar icon to stop the app completely.

## Privacy

API keys are stored in macOS Keychain. Provider, model, shortcut, appearance,
context, and target profile settings are stored locally with app preferences.

Selected text and optional context are sent directly from the app to the chosen
provider. The app does not run a server and does not store user text in a remote
database.

App context is read from the app you rewrite in for each shortcut use. Depending
on the mode, it includes the app name, window title, field label, the text
around your selection and, in *Field and nearby text* mode, the text above the
field, which can be other people's messages. Each part has a length cap. It
goes only to the chosen provider, together with the selected text, and release
builds do not save it. Nothing is read from password fields or from any app
while a password field is focused.

See [Privacy Policy](PRIVACY_POLICY.md) for details.

## Documentation

- [Development](DEVELOPMENT.md)
- [Deployment and configuration](DEPLOYMENT.md)
- [LLM agent rules](AGENTS.md)
- [CI/CD setup](docs/ci-cd-setup.md)
- [Design system](docs/design-system.md)

## License

MIT. See [LICENSE](LICENSE).
