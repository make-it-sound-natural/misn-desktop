# Request Speed

Speed is a global setting in Settings → AI Provider. It applies to rewrites
from both the main window and global shortcuts.

## Levels and prices

| Level | Price relative to Standard |
| --- | --- |
| Standard | 1× |
| Fast | 2× |
| Ultrafast | 6× |

Faster tiers answer sooner and cost more. Standard is the default, including
when a saved speed value is missing or unknown. Installs that had OpenAI
selected before this setting existed start at Fast once, because their
requests always used that tier (then called `priority`).

## Built-in model support

| Provider | Model | Supported levels |
| --- | --- | --- |
| OpenAI | `gpt-6-luna` | Standard, Fast |
| OpenAI | `gpt-6.1-terra` | Standard, Fast |
| OpenAI | `gpt-6.1-sol` | Standard, Fast, Ultrafast |
| OpenAI | `gpt-6-astra` | Standard, Fast, Ultrafast |
| OpenRouter | `google/gemini-3-flash-preview` | Standard |
| Anthropic | `claude-haiku-5-5` | Standard |
| Anthropic | `claude-sonnet-5-5` | Standard |
| Anthropic | `claude-opus-5-5` | Standard, Fast |

A built-in model uses its highest supported level at or below the selected
level. For example, choosing Ultrafast with `gpt-6-luna` sends Fast. The row
shows `gpt-6-luna runs at Fast`. The saved choice remains Ultrafast, so
switching to `gpt-6.1-sol` uses Ultrafast.

Fast mode on `claude-opus-5-5` is generally available. On Claude Opus 5 and
Opus 4.8, which can be added as manual models, it is a research preview.

## Manually added models and providers

- Models added to the built-in OpenAI provider receive the chosen level
  unchanged. If a model rejects that tier, its provider error is shown.
- Models added to the built-in Anthropic provider receive the chosen level,
  with Ultrafast sent as Fast.
- OpenRouter and custom providers always use Standard. Their Speed control
  is disabled and shows “Available for OpenAI and Anthropic”.

## Request fields and errors

Built-in OpenAI requests use the Responses API at `/v1/responses`. Fast and
Ultrafast set `service_tier` to `fast` and `ultrafast`, respectively. Requests
use strict structured output and `store: false`.

Anthropic Fast requests set the body field `speed` to `fast` and the
`anthropic-beta` header to `fast-mode-2026-02-01`. Only Opus 5 and Opus 4.8
require the header; `claude-opus-5-5` accepts it.

Standard requests omit both `service_tier` and `speed`. OpenRouter and custom
providers use Chat Completions without either field.

A rejected tier or rate limit shows the provider error without a retry.
OpenAI retries once without the `reasoning` object only when HTTP 400 or 422
explicitly rejects `reasoning`, `reasoning.effort`, or its value. The retry
preserves the request's speed tier. See [Reasoning effort](reasoning-effort.md)
for compatibility fallback details.

## Saved GPT model migration

Startup migrates saved built-in OpenAI model selections to their successors.

| Previous model | Successor |
| --- | --- |
| `gpt-5.4-nano` | `gpt-6-luna` |
| `gpt-5.4-mini` | `gpt-6.1-terra` |
| `gpt-5.4` | `gpt-6.1-sol` |
| `gpt-5.5` | `gpt-6.1-sol` |

Hidden models transfer their hidden state to the successor. A shared
successor is hidden only when all eligible previous models were hidden, and
it stays visible if hiding it would leave no visible model. Custom entries
that duplicate current built-in slugs are removed while their hidden state
is preserved, and hidden previous models do not hide them. Manually added
models carrying previous GPT slugs stay as they are. Each change is logged.
Running the migration again makes no further changes.
