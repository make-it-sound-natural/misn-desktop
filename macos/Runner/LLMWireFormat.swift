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
        if provider == AppDefaults.anthropicProvider {
            return AnthropicMessagesFormat()
        }
        return ChatCompletionsFormat(provider: provider)
    }
}
