# Privacy Policy

**Last updated:** January 2026

## Overview

Make It Sound Natural ("the App") is a macOS application that helps you rewrite text using AI. This privacy policy explains how the App handles your data.

## Data Collection and Processing

### Text Data

When you use the App to rewrite text:

1. **Selected Text**: The text you select and submit for rewriting is sent to your configured AI provider (OpenAI or OpenRouter) for processing.
2. **Processing**: The AI provider processes your text to generate rewritten variants.
3. **No Storage by App**: The App does not store your submitted text or the AI-generated responses on any server. All processing happens in real-time.

### API Keys

- Your API keys (OpenAI and/or OpenRouter) are stored locally on your device
	using macOS Keychain.
- API keys are only used to authenticate requests to their respective services and are never transmitted to any other service.

### Local Storage

The App stores the following data locally on your device:

- **Settings**: Your preferences (keyboard shortcuts, default variant selection, custom prompts)
- **API Keys**: Your OpenAI and/or OpenRouter API keys (stored in macOS Keychain)
- **Context**: Optional context text you provide for better corrections (stored only in memory during the session)

No personal data is transmitted to any servers other than your configured AI provider (OpenAI or OpenRouter) for text processing.

## Third-Party Services

The App supports multiple AI providers. Depending on your configuration, your text may be processed by one of the following services:

### OpenAI

When using OpenAI as your AI provider:

- Your text is sent to OpenAI's servers
- OpenAI processes the text according to their [Privacy Policy](https://openai.com/policies/privacy-policy)
- OpenAI's [API Data Usage Policy](https://openai.com/policies/api-data-usage-policies) applies

**Data Retention by OpenAI:**

- **Training**: OpenAI does **not** use API data for training models by default
- **Storage**: OpenAI **does store** your prompts and responses for abuse monitoring purposes
- **Retention period**: Data is typically retained for 30 days, however due to a U.S. court order (October 2025), OpenAI is currently required to preserve API data indefinitely for standard API users
- **Zero Data Retention**: Available only to approved enterprise/business accounts upon application to OpenAI

### OpenRouter

When using OpenRouter as your AI provider:

- Your text is sent to OpenRouter's servers
- OpenRouter may route your request to various underlying AI models
- OpenRouter processes data according to their [Privacy Policy](https://openrouter.ai/privacy)
- OpenRouter's [Terms of Service](https://openrouter.ai/terms) applies

**Data Retention by OpenRouter:**

- **Storage**: OpenRouter does **not** store prompts or responses by default — only metadata (token counts, latency)
- **Prompt logging**: Available as an opt-in feature in your OpenRouter account settings
- **Zero Data Retention**: Available to all users. When enabled, requests only route to providers that do not retain or train on your data
- **Training**: Depends on the underlying model provider; OpenRouter allows you to configure settings to avoid providers that train on user data

**Privacy Recommendation**: If data privacy is a priority, OpenRouter with Zero Data Retention enabled offers stronger privacy guarantees out of the box compared to standard OpenAI API access.

**Important**: By using this App, you agree to the terms of service and privacy policy of your configured AI provider.

## Accessibility Permissions

The App requests accessibility permissions to:

- Read selected text from any application
- Paste corrected text back into the original application
- Register global keyboard shortcuts

These permissions are used solely for the App's core functionality. No data is collected or transmitted through these features beyond the text processing described above.

## Auto-Updates

The App uses Sparkle for automatic updates. When checking for updates:

- The App contacts GitHub to check for new versions
- No personal data is transmitted during update checks
- Only anonymous version information is used to determine if an update is available

## Data Security

- All communication with AI providers (OpenAI, OpenRouter) uses HTTPS encryption
- Your API keys are stored in macOS Keychain and never shared
- No analytics or tracking services are used

## Children's Privacy

This App is not intended for use by children under the age of 13. We do not knowingly collect personal information from children.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted in the App's repository and reflected in the "Last updated" date above.

## Contact

If you have questions about this privacy policy, please open an issue on the [GitHub repository](https://github.com/make-it-sound-natural/misn-desktop).

## Your Rights

Depending on your jurisdiction, you may have rights regarding your personal data including:

- The right to access your data
- The right to delete your data
- The right to data portability

Since the App does not store your text data on any server, most data rights can be exercised by simply:

1. Removing your API key from the App settings
2. Uninstalling the App
3. Deleting any local preferences (stored in ~/Library/Preferences/)
