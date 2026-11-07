import Foundation

/// One HTTP dialect for a rewrite request: how to build it, how to read
/// the variants from a successful response, and whether a rejected request
/// can be sent again in a reduced form.
protocol LLMWireFormat {
    /// `nil` when the URL or the JSON body cannot be built.
    func makeRequest(
        text: String,
        config: LLMService.Configuration,
        systemInstructions: String
    ) -> URLRequest?

    /// The marker text with the four variants, or the message to show.
    func variantsContent(
        from data: Data
    ) -> Result<String, LLMResponseFailure>

    /// The format to retry with after a non-200 response, or `nil` when
    /// the error should be reported as is.
    func retrying(
        afterErrorData data: Data?,
        statusCode: Int
    ) -> LLMWireFormat?
}

struct LLMResponseFailure: Error {
    let message: String
}

/// A caseless enum because Swift cannot call a static method declared in a
/// protocol extension on the protocol itself.
enum LLMWireFormatFactory {
    static func forProvider(_ provider: String) -> LLMWireFormat {
        if provider == AppDefaults.openAiProvider {
            return OpenAIResponsesFormat()
        }
        if provider == AppDefaults.anthropicProvider {
            return AnthropicMessagesFormat()
        }
        return ChatCompletionsFormat(provider: provider)
    }
}

/// Formats reduced after a model rejected a parameter, kept for the process
/// lifetime so later requests with the same settings skip the failed
/// attempt and a second screenshot upload.
///
/// Read when a request starts and written from the URLSession callback
/// queue, so access goes through a lock.
final class LLMReducedFormatCache {
    struct Key: Hashable {
        let provider: String
        let customProviderBaseUrl: String?
        let model: String
        /// A rejected `none` says nothing about `low`, so each effort is
        /// remembered separately.
        let reasoningEffort: ReasoningEffort

        init(config: LLMService.Configuration) {
            provider = config.provider
            customProviderBaseUrl = config.customProviderBaseUrl
            model = config.model
            reasoningEffort = config.reasoningEffort
        }
    }

    private let lock = NSLock()
    private var formats: [Key: LLMWireFormat] = [:]

    func format(for key: Key) -> LLMWireFormat? {
        lock.lock()
        defer { lock.unlock() }
        return formats[key]
    }

    func store(_ format: LLMWireFormat, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        formats[key] = format
    }
}
