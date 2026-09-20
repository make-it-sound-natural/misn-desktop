# Reasoning effort

Settings → AI Provider offers None, Low (default), Medium, and High next to
Model. The choice applies to all models and both rewrite entry points. It is
saved locally; missing or unknown saved values use Low. Lower levels favor
speed, while higher levels allow a larger reasoning budget. Providers decide
how to interpret the level, so this is not a latency or quality guarantee.

Requests use the top-level `reasoning_effort` field. The app does not send a
second, nested `reasoning.effort` field. OpenRouter documents the top-level
field in its [parameter reference](https://openrouter.ai/docs/api_reference/parameters).
TokenGuard's top-level contract and observations about rejected `none` values
come from [MT-1087](https://www.notion.so/3dc03d59105281629ca5caf4d3b0e725).

On HTTP 400 or 422, an explicit rejection of `reasoning_effort` or its value
allows a retry with that field omitted. The saved preference stays unchanged.
This uses the provider's default for that request. It does not turn reasoning
off: None is sent as the explicit value `none` until rejected.

The custom-provider `response_format` fallback shares the same retry budget:
each rejected parameter can be removed once, for at most three requests total.
Either rejection order works without restoring an already removed field.
Model, credentials, context, image attachment, and other options stay intact.
The response-format fallback adds the existing JSON-only output instruction.
Authentication, quota, server errors, unrelated validation failures, and
repeated rejection of an already removed field do not trigger another retry.

## Latency validation

Automated tests use an isolated HTTP transport, not real providers. They do
not measure latency. The benchmark numbers and p50 ≤ 5 seconds target in
MT-1087 are the card author's observations and target for its specific cases.
They are not measurements made during this implementation.

Keep strict `response_format` enabled by default. OpenRouter's
[structured-output documentation](https://openrouter.ai/docs/guides/features/structured-outputs)
requires a compatible model/provider. Whether strict output changes the
available DeepSeek route and latency needs a separate live comparison using
the same model, prompts, reasoning level, and recorded provider route.
### TokenGuard smoke comparison — 2026-09-20

Six requests used the configured TokenGuard endpoint and the saved
`deepseek-v4.1-flash` model. They alternated omitted `reasoning_effort` and
`low` on the same short synthetic English text and short rewrite instruction.
Strict `response_format` stayed enabled. Both conditions used `max_tokens: 1024`, a 30-second request deadline, and no retries. No private user text was
sent, and no credentials or response text were recorded.

| Pair | Parameter omitted | `low` |
| --- | ---: | ---: |
| 1 | 2.205 s | 1.674 s |
| 2 | 1.498 s | 2.184 s |
| 3 | 1.740 s | 1.595 s |

All six responses were HTTP 200, finished with `stop`, and contained the four
required nonempty string variants. The sample medians were 1.740 s and
1.674 s respectively. Three observations per condition do not establish a
stable latency improvement or an underlying reasoning budget. Response
semantics were not evaluated by a quality judge.

This smoke test used a different model and shorter prompt than the card's
benchmark, so it does not verify the Gemini p50 target. The separate
OpenRouter routing comparison remains unperformed.
