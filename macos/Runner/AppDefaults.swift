/// Centralized default values for the application.
enum AppDefaults {
    /// User-facing app name used by native integrations.
    static let appName = "Make It Sound Natural"

    /// Provider used when none has been saved.
    static let apiProvider = openAiProvider

    /// Provider id for direct OpenAI requests.
    static let openAiProvider = "openai"

    /// Provider id for OpenRouter requests.
    static let openRouterProvider = "openrouter"

    /// Provider id for Anthropic's native Messages API.
    static let anthropicProvider = "anthropic-messages"

    /// `anthropic-version` header sent with every Messages API request.
    static let anthropicApiVersion = "2026-10-21"

    /// Beta feature required for Anthropic fast mode.
    static let anthropicFastModeBeta = "fast-mode-2026-02-01"

    /// Output budget for one rewrite, thinking included.
    static let anthropicMaxTokens = 16000

    /// Default reasoning budget for rewrites.
    static let reasoningEffort = ReasoningEffort.low

    /// Default request processing speed.
    static let requestSpeed = RequestSpeed.standard

    /// Default correction variant used when no variant has been saved.
    static let variant = "Balanced"

    /// Default API key value used before the user saves a key.
    static let apiKey = ""

    /// Default user context value used when no context has been saved.
    static let context = ""

    /// Default keyboard shortcut for text correction
    static let correctionShortcut = "cmd+shift+k"

    /// Default keyboard shortcut for context replace
    static let replaceShortcut = "cmd+shift+j"

    /// Default keyboard shortcut for context append
    static let appendShortcut = "cmd+shift+l"
}

/// Reasoning levels shared with the Flutter settings picker.
enum ReasoningEffort: String, CaseIterable {
    case none, low, medium, high
}

/// Request processing levels resolved by the Flutter settings.
enum RequestSpeed: String, CaseIterable {
    case standard, fast, ultrafast
}
