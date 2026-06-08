/// Centralized default values for the application.
enum AppDefaults {
    /// User-facing app name used by native integrations.
    static let appName = "Make It Sound Natural"

    /// Provider id for direct OpenAI requests.
    static let apiProvider = "openai"

    /// Provider id for OpenRouter requests.
    static let openRouterProvider = "openrouter"

    /// Default LLM model used when no model has been saved.
    static let model = "gpt-5.4-mini"

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
