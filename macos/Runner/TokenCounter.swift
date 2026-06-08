import Foundation

/// Estimates and manages token counts for OpenAI API requests
struct TokenCounter {
    /// Model-specific token limits
    private static let modelLimits: [String: (contextWindow: Int, maxOutput: Int)] = [
        "gpt-5.4-nano": (400_000, 128_000),
        "gpt-5.4-mini": (400_000, 128_000),
        "gpt-5.4": (1_050_000, 128_000),
        "gpt-5.5": (1_050_000, 128_000),
        "google/gemini-3.1-flash-lite-preview": (1_048_576, 65_536),
        "google/gemini-3-flash-preview": (1_048_576, 65_536),
        "openai/gpt-5.4-nano": (400_000, 128_000),
        "qwen/qwen3.6-flash": (1_000_000, 65_536),
        "x-ai/grok-4.1-fast": (2_000_000, 30_000),
        "anthropic/claude-haiku-4.5": (200_000, 64_000)
    ]

    /// Estimates token count for a given text string
    /// Uses approximation: ~1 token per 4 characters for English text
    /// - Parameter text: The text to count tokens for
    /// - Returns: Estimated token count
    static func estimateTokenCount(_ text: String) -> Int {
        let baseCount = text.count / 4

        let specialChars = text.filter {
            !$0.isLetter && !$0.isWhitespace && !$0.isPunctuation
        }.count

        return Int(Double(baseCount) * 1.2) + (specialChars / 2)
    }

    /// Truncates context to fit within model's token limits
    /// - Parameters:
    ///   - systemInstructions: The system instructions text
    ///   - userText: The user input text
    ///   - context: The context to potentially truncate
    ///   - model: The model name to get limits for
    ///   - logger: Optional logging function
    /// - Returns: Truncated context that fits within limits
    static func truncateContextIfNeeded(
        systemInstructions: String,
        userText: String,
        context: String,
        model: String,
        logger: ((String) -> Void)? = nil
    ) -> String {
        let (contextWindow, maxOutput) = modelLimits[model] ?? (128_000, 16_384)
        let maxInputTokens = contextWindow - maxOutput - 1_000

        let systemTokens = estimateTokenCount(systemInstructions)
        let userTextTokens = estimateTokenCount(userText)
        let contextTokens = estimateTokenCount(context)

        let totalTokens = systemTokens + userTextTokens + contextTokens

        logger?(
            "Token estimation - System: \(systemTokens), User: \(userTextTokens), " +
            "Context: \(contextTokens), Total: \(totalTokens), Limit: \(maxInputTokens)"
        )

        if totalTokens <= maxInputTokens {
            return context
        }

        let excessTokens = totalTokens - maxInputTokens
        let allowedContextTokens = contextTokens - excessTokens

        if allowedContextTokens <= 0 {
            logger?("⚠️ Context too large, removing entirely")
            return ""
        }

        let allowedChars = allowedContextTokens * 4

        if context.count <= allowedChars {
            return context
        }

        let startIndex = context.index(context.endIndex, offsetBy: -allowedChars)
        let truncated = String(context[startIndex...])

        logger?(
            "📉 Context truncated from \(context.count) to \(truncated.count) chars " +
            "(~\(allowedContextTokens) tokens)"
        )

        return "...[context truncated]...\n" + truncated
    }
}
